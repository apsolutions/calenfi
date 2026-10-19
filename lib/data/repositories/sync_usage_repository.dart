import '../../sync/usage_sync_plan.dart';
import '../../domain/models/account.dart';
import '../local/db/database.dart';

/// Device-local usage only; no titles, attendees, tokens or remote telemetry.
class SyncUsageRepository {
  SyncUsageRepository(this.db);
  final AppDatabase db;

  Future<void> recordRun(
    String accountId,
    DateTime start,
    DateTime end,
    bool ok,
  ) async {
    await db.customStatement(
      'INSERT INTO sync_runs(account_id, started, finished, ok) VALUES (?, ?, ?, ?)',
      [
        accountId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        ok ? 1 : 0,
      ],
    );
    await _prune(end);
  }

  Future<List<SyncTiming>> timings() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM (SELECT * FROM sync_runs ORDER BY id DESC LIMIT 2048) ORDER BY id',
        )
        .get();
    return [
      for (final r in rows)
        SyncTiming(
          r.read<String>('account_id'),
          DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('started'),
            isUtc: true,
          ),
          DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('finished'),
            isUtc: true,
          ),
          r.read<int>('ok') == 1,
        ),
    ];
  }

  Future<Map<String, SyncTiming>> latestSuccessful() async {
    final rows = await db
        .customSelect(
          'SELECT * FROM sync_runs WHERE id IN '
          '(SELECT MAX(id) FROM sync_runs WHERE ok = 1 GROUP BY account_id)',
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('account_id'): SyncTiming(
          r.read<String>('account_id'),
          DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('started'),
            isUtc: true,
          ),
          DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('finished'),
            isUtc: true,
          ),
          true,
        ),
    };
  }

  Future<void> recordOpening(
    DateTime local,
    List<Account> accounts,
  ) => db.transaction(() async {
    final now = local.toUtc();
    final latest = await latestSuccessful();
    final automatic = accounts
        .where((a) => a.refresh.effectiveInterval != Duration.zero)
        .toList();
    if (automatic.isEmpty) return;
    final fresh = automatic.every((a) {
      final run = latest[a.id];
      return a.isHealthy &&
          run != null &&
          !run.finished.isAfter(now) &&
          !run.started.isAfter(now) &&
          now.difference(run.started) <= UsageSyncPlan.freshness;
    });
    // Window focus churn (dialogs / notifications) is not a new opening.
    final previous = await db
        .customSelect('SELECT MAX(opened) AS last FROM sync_openings')
        .getSingle();
    final last = previous.readNullable<int>('last');
    if (last != null &&
        now.millisecondsSinceEpoch >= last &&
        now.millisecondsSinceEpoch - last < 60000) {
      return;
    }
    await db.customStatement(
      'INSERT INTO sync_openings(opened, week_minute, fresh) VALUES (?, ?, ?)',
      [
        now.millisecondsSinceEpoch,
        CalendarOpening.minuteOfWeek(local),
        fresh ? 1 : 0,
      ],
    );
    await _prune(now);
  });

  Future<UsageSyncPlan> plan(DateTime now) async {
    final rows = await db
        .customSelect('SELECT * FROM sync_openings ORDER BY opened')
        .get();
    return UsageSyncPlan.learn(
      [
        for (final r in rows)
          CalendarOpening(
            DateTime.fromMillisecondsSinceEpoch(
              r.read<int>('opened'),
              isUtc: true,
            ),
            r.read<int>('week_minute'),
            r.read<int>('fresh') == 1,
          ),
      ],
      await timings(),
      now,
    );
  }

  Future<void> _prune(DateTime now) async {
    final cutoff = now
        .subtract(const Duration(days: 56))
        .millisecondsSinceEpoch;
    // Retain 56 observed days, not 56 elapsed days: background syncs and
    // holidays must not erase the only evidence of the user's habits.
    await db.customStatement(
      'DELETE FROM sync_openings WHERE opened <= ? AND '
      '(opened / 86400000) NOT IN '
      '(SELECT DISTINCT opened / 86400000 FROM sync_openings '
      'WHERE opened <= ? ORDER BY opened / 86400000 DESC LIMIT ?)',
      [
        now.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
        UsageSyncPlan.historyDays,
      ],
    );
    await db.customStatement('DELETE FROM sync_runs WHERE finished < ?', [
      cutoff,
    ]);
  }
}
