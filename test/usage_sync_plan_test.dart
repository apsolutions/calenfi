import 'package:calenfi/sync/usage_sync_plan.dart';
import 'package:calenfi/data/repositories/sync_usage_repository.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = DateTime(2026, 10, 19, 10);
  CalendarOpening opening(DateTime at, {bool fresh = true}) =>
      CalendarOpening(at.toUtc(), CalendarOpening.minuteOfWeek(at), fresh);
  UsageSyncPlan learn(
    List<CalendarOpening> samples, {
    List<SyncTiming> runs = const [],
  }) => UsageSyncPlan.learn(samples, runs, monday.toUtc());

  test('cold start has no invented 95% guarantee and uses 120-second lead', () {
    final plan = learn([]);
    expect(plan.slots, isEmpty);
    expect(plan.modelCoverage, 0);
    expect(plan.observedFreshFraction, isNull);
    expect(plan.lead, const Duration(minutes: 2));
    expect(plan.nextWake(monday), isNull);
  });
  test('weekday/time windows cover 95% of smoothed observations', () {
    final plan = learn([
      for (var week = 1; week <= 7; week++)
        opening(monday.subtract(Duration(days: week * 7))),
    ]);
    expect(plan.modelCoverage, greaterThanOrEqualTo(.95));
    expect(plan.activeAt(monday.subtract(const Duration(minutes: 6))), isTrue);
    expect(plan.activeAt(monday.add(const Duration(days: 1))), isFalse);
    expect(plan.activeAt(monday.add(const Duration(hours: 5))), isFalse);
    expect(
      plan
          .nextWake(monday.subtract(const Duration(hours: 1)))!
          .isBefore(monday),
      isTrue,
    );
  });
  test('duration p95 is measured, including values above 120 seconds', () {
    final runs = [
      for (var i = 1; i <= 20; i++)
        SyncTiming(
          'a',
          monday.subtract(const Duration(hours: 1)),
          monday
              .subtract(const Duration(hours: 1))
              .add(Duration(seconds: i * 10)),
          true,
        ),
    ];
    final plan = learn([], runs: runs);
    expect(plan.lead, const Duration(seconds: 190));
  });
  test('fast accounts cannot hide the latency of a slower account', () {
    final plan = learn(
      [],
      runs: [
        for (var i = 0; i < 100; i++)
          SyncTiming(
            'fast',
            monday.subtract(const Duration(minutes: 1)),
            monday,
            true,
          ),
        SyncTiming(
          'slow',
          monday.subtract(const Duration(minutes: 2)),
          monday,
          true,
        ),
      ],
    );
    expect(plan.lead.inSeconds, 120);
  });
  test(
    'failed and invalid durations do not train successful completion latency',
    () {
      final plan = learn(
        [],
        runs: [
          SyncTiming(
            'a',
            monday.subtract(const Duration(hours: 1)),
            monday,
            false,
          ),
        ],
      );
      expect(plan.lead.inSeconds, 120);
    },
  );
  test(
    'Sunday smoothing wraps into Monday, and next wake crosses midnight',
    () {
      final sunday = DateTime(2026, 10, 18, 23, 59);
      final plan = learn([opening(sunday)]);
      expect(plan.activeAt(DateTime(2026, 10, 19, 0, 1)), isTrue);
      expect(
        plan.nextWake(DateTime(2026, 10, 18, 23, 59)),
        DateTime(2026, 10, 19),
      );
    },
  );
  test(
    'inactivity does not discard observations or conceal freshness misses',
    () {
      final plan = learn([
        opening(monday.subtract(const Duration(days: 70))),
        opening(monday.subtract(const Duration(days: 7)), fresh: false),
      ]);
      expect(plan.sampleCount, 2);
      expect(plan.modelCoverage, greaterThanOrEqualTo(.95));
      expect(plan.observedFreshFraction, .5);
    },
  );
  test('opening refreshes at two minutes even with a 15-minute interval', () {
    final plan = learn([]);
    bool due(int age) => plan.needsRefresh(
      now: monday,
      lastStarted: monday.subtract(Duration(seconds: age)),
      lastFinished: monday.subtract(const Duration(seconds: 10)),
      normalInterval: const Duration(minutes: 15),
      opening: true,
    );
    expect(due(119), isFalse);
    expect(due(120), isTrue);
    expect(due(121), isTrue);
  });
  test('a two-minute sync does not become fresh merely by completing now', () {
    expect(
      learn([]).needsRefresh(
        now: monday,
        lastStarted: monday.subtract(const Duration(minutes: 3)),
        lastFinished: monday,
        normalInterval: const Duration(minutes: 15),
        opening: true,
      ),
      isTrue,
    );
  });
  test('manual policy is respected even on opening', () {
    expect(
      learn([]).needsRefresh(
        now: monday,
        lastStarted: null,
        lastFinished: null,
        normalInterval: Duration.zero,
        opening: true,
      ),
      isFalse,
    );
  });
  test(
    'outside prediction windows the configured interval remains in effect',
    () {
      expect(
        learn([]).needsRefresh(
          now: monday,
          lastStarted: null,
          lastFinished: monday.subtract(const Duration(minutes: 5)),
          normalInterval: const Duration(minutes: 15),
        ),
        isFalse,
      );
    },
  );
  test(
    'predicted windows start refresh early enough for measured duration',
    () {
      final plan = learn(
        [opening(monday.subtract(const Duration(days: 7)))],
        runs: [
          SyncTiming(
            'a',
            monday.subtract(const Duration(minutes: 30)),
            monday.subtract(const Duration(minutes: 29)),
            true,
          ),
        ],
      );
      expect(
        plan.needsRefresh(
          now: monday,
          lastStarted: monday.subtract(const Duration(seconds: 61)),
          lastFinished: monday.subtract(const Duration(seconds: 1)),
          normalInterval: const Duration(minutes: 15),
        ),
        isTrue,
      );
    },
  );

  test('a single new opening after a long pause preserves the old habit', () {
    final old = opening(monday.subtract(const Duration(days: 210)));
    final lone = UsageSyncPlan.learn([old], [], monday);
    expect(lone.sampleCount, 1);
    expect(lone.activeAt(monday), isTrue);
    final changed = learn([
      old,
      opening(
        monday.subtract(const Duration(days: 7)).add(const Duration(hours: 3)),
      ),
    ]);
    expect(changed.sampleCount, 2);
    expect(changed.activeAt(monday), isTrue);
    expect(changed.activeAt(monday.add(const Duration(hours: 3))), isTrue);
  });
  test('a pause alone leaves the learned schedule unchanged', () {
    final samples = [
      opening(monday),
      opening(monday.subtract(const Duration(days: 7))),
    ];
    final before = UsageSyncPlan.learn(samples, [], monday);
    final after = UsageSyncPlan.learn(
      samples,
      [],
      monday.add(const Duration(days: 365)),
    );
    expect(after.slots, before.slots);
    expect(after.modelCoverage, before.modelCoverage);
    expect(after.sampleCount, before.sampleCount);
  });
  test('repeated new usage gradually displaces the old pattern', () {
    final plan = learn([
      CalendarOpening(monday.subtract(const Duration(days: 210)), 600, true),
      for (var day = 1; day <= 28; day++)
        CalendarOpening(monday.subtract(Duration(days: day)), 780, true),
    ]);
    expect(plan.activeAt(monday), isFalse);
    expect(plan.activeAt(monday.add(const Duration(hours: 3))), isTrue);
  });
  test('many openings on one day cannot overwhelm an established habit', () {
    final old = [
      for (var day = 1; day <= 7; day++)
        CalendarOpening(monday.subtract(Duration(days: day + 200)), 600, true),
    ];
    final baseline = learn([...old, CalendarOpening(monday, 780, true)]);
    final burst = learn([
      ...old,
      for (var i = 0; i < 200; i++) CalendarOpening(monday, 780, true),
    ]);
    expect(burst.slots, baseline.slots);
    expect(burst.modelCoverage, closeTo(baseline.modelCoverage, 1e-12));
    expect(burst.activeAt(monday), isTrue);
  });
  test('retention is bounded by observed days and ignores future records', () {
    final samples = [
      for (var day = 0; day < 57; day++)
        opening(monday.subtract(Duration(days: day * 7))),
      opening(monday.add(const Duration(days: 1))),
    ];
    expect(learn(samples).sampleCount, 56);
  });
  test(
    'next wake advances monotonically and retains timezone representation',
    () {
      final now = DateTime.utc(2026, 10, 19, 10, 0, 59);
      final plan = UsageSyncPlan.learn(
        [CalendarOpening(now.subtract(const Duration(days: 7)), 600, true)],
        [],
        now,
      );
      final next = plan.nextWake(now)!;
      expect(next.isAfter(now), isTrue);
      expect(next.isUtc, isTrue);
      expect(next, DateTime.utc(2026, 10, 19, 10, 1));
    },
  );

  group('durable local observations', () {
    late AppDatabase db;
    late SyncUsageRepository repo;
    const account = Account(
      id: 'a',
      provider: ProviderType.google,
      displayName: 'A',
      email: 'a@example.test',
    );
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = SyncUsageRepository(db);
    });
    tearDown(() => db.close());
    test(
      'reloading repository retains openings and measured durations',
      () async {
        await repo.recordRun(
          'a',
          monday.subtract(const Duration(seconds: 60)),
          monday.subtract(const Duration(seconds: 10)),
          true,
        );
        await repo.recordOpening(monday, [account]);
        final loaded = SyncUsageRepository(db);
        final plan = await loaded.plan(monday);
        expect(plan.sampleCount, 1);
        expect(plan.lead.inSeconds, 50);
        expect(plan.observedFreshFraction, 1);
      },
    );
    test('background runs during inactivity retain opening history', () async {
      await repo.recordOpening(monday, [account]);
      final later = monday.add(const Duration(days: 210));
      await repo.recordRun(
        'a',
        later.subtract(const Duration(minutes: 1)),
        later,
        true,
      );
      expect((await repo.plan(later)).sampleCount, 1);
      await repo.recordOpening(later.add(const Duration(hours: 3)), [account]);
      final plan = await repo.plan(later.add(const Duration(hours: 3)));
      expect(plan.sampleCount, 2);
      expect(plan.activeAt(later), isTrue);
      expect(plan.activeAt(later.add(const Duration(hours: 3))), isTrue);
    });
    test(
      'SQLite retains the last 56 observed days even across long gaps',
      () async {
        for (var day = 56; day >= 0; day--) {
          await repo.recordOpening(monday.subtract(Duration(days: day * 7)), [
            account,
          ]);
        }
        final rows = await db
            .customSelect('SELECT opened FROM sync_openings ORDER BY opened')
            .get();
        expect(rows.length, 56);
        expect(
          rows.first.read<int>('opened'),
          monday.subtract(const Duration(days: 55 * 7)).millisecondsSinceEpoch,
        );
        expect((await repo.plan(monday)).sampleCount, 56);
      },
    );
    test('recent completion with old start is recorded as a miss', () async {
      await repo.recordRun(
        'a',
        monday.subtract(const Duration(minutes: 3)),
        monday,
        true,
      );
      await repo.recordOpening(monday, [account]);
      expect((await repo.plan(monday)).observedFreshFraction, 0);
    });
    test('failure never replaces the last successful timestamp', () async {
      await repo.recordRun(
        'a',
        monday.subtract(const Duration(minutes: 10)),
        monday.subtract(const Duration(minutes: 9)),
        true,
      );
      await repo.recordRun(
        'a',
        monday.subtract(const Duration(minutes: 1)),
        monday,
        false,
      );
      expect(
        (await repo.latestSuccessful())['a']!.started,
        monday.subtract(const Duration(minutes: 10)).toUtc(),
      );
    });
    test('simultaneous opening notifications are recorded once', () async {
      await Future.wait([
        repo.recordOpening(monday, [account]),
        repo.recordOpening(monday, [account]),
      ]);
      expect((await repo.plan(monday)).sampleCount, 1);
    });
    test('focus bounce is not a second opening', () async {
      await repo.recordOpening(monday, [account]);
      await repo.recordOpening(monday.add(const Duration(seconds: 20)), [
        account,
      ]);
      expect(
        (await repo.plan(monday.add(const Duration(seconds: 20)))).sampleCount,
        1,
      );
    });
    test('all automatic accounts must be fresh', () async {
      await repo.recordRun(
        'a',
        monday.subtract(const Duration(seconds: 45)),
        monday,
        true,
      );
      await repo.recordOpening(monday, [
        account,
        const Account(
          id: 'b',
          provider: ProviderType.graph,
          displayName: 'B',
          email: 'b@example.test',
        ),
      ]);
      expect((await repo.plan(monday)).observedFreshFraction, 0);
    });
  });
}
