import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/mock/mock_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConflictProvider extends MockProvider {
  _ConflictProvider(super.accountId) {
    remote = CalendarEvent(
      id: eventId,
      calendarId: '$accountId:work',
      title: 'Remote old',
      startUtc: DateTime.utc(2026, 8, 28, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16),
      source: EventSource(
        accountId: accountId,
        calendarId: '$accountId:work',
        providerEventId: resourceId,
        etag: 'etag-0',
      ),
    );
  }

  static const eventId = 'a:work:uid-1';
  static const resourceId = '/calendars/a/work/uid-1.ics';
  static const updatedResourceId = '/calendars/a/work/server-renamed.ics';

  late CalendarEvent remote;
  var failNextUpdate = true;
  var reportTombstoneOnce = false;
  final receivedEtags = <String?>[];

  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  ) async {
    final isWork = cal.id == remote.calendarId;
    final tombstones = isWork && reportTombstoneOnce
        ? [remote.source.providerEventId!]
        : const <String>[];
    if (isWork) reportTombstoneOnce = false;
    return SyncResult(
      upserts: isWork ? [remote] : const [],
      deletedIds: tombstones,
      newSyncState: 'state',
      fullWindow: DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 9, 1)),
    );
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent event, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    receivedEtags.add(event.source.etag);
    if (failNextUpdate) {
      failNextUpdate = false;
      reportTombstoneOnce = true;
      remote = remote.copyWith(
        title: 'Remote changed concurrently',
        source: remote.source.copyWith(
          providerEventId: updatedResourceId,
          etag: 'etag-remote',
        ),
      );
      final request = RequestOptions(path: 'https://calendar.test/uid-1.ics');
      throw DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 412),
        type: DioExceptionType.badResponse,
      );
    }
    if (event.source.etag != 'etag-remote') {
      throw StateError('retry получил stale ETag ${event.source.etag}');
    }
    remote = event.copyWith(source: event.source.copyWith(etag: 'etag-1'));
    return remote;
  }
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;
  late SyncEngine engine;
  late _ConflictProvider provider;

  const account = Account(
    id: 'a',
    provider: ProviderType.caldav,
    displayName: 'Yandex',
    email: 'a@example.org',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    provider = _ConflictProvider(account.id);
    engine = SyncEngine(
      registry: ProviderRegistry(overrideFactory: (_) => provider),
      accounts: accounts,
      events: events,
    );
    await accounts.upsertAccount(account);
    final initial = await engine.syncAccount(account);
    expect(initial.ok, isTrue);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  test(
    '412 → pull сохраняет local dirty/outbox; retry очищает после успеха',
    () async {
      final initial = await events.getById(_ConflictProvider.eventId);
      expect(initial, isNotNull);
      final local = initial!.copyWith(title: 'Local edit');
      await events.putLocalDirty(local);
      await events.enqueue('update', local.id);

      await engine.syncAccount(account);

      final afterConflict = await (db.select(
        db.events,
      )..where((e) => e.id.equals(local.id))).getSingle();
      expect(afterConflict.title, 'Local edit');
      expect(afterConflict.dirty, isTrue);
      expect(afterConflict.etag, 'etag-remote');
      expect(
        afterConflict.providerEventId,
        _ConflictProvider.updatedResourceId,
      );
      expect(
        afterConflict.deletedRemotely,
        isFalse,
        reason: 'remote tombstone тоже не должен менять pending edit',
      );
      final pending = await events.pendingOutbox();
      expect(pending, hasLength(1));
      expect(pending.single.retryCount, 1);

      final retry = await engine.syncAccount(account);

      expect(retry.ok, isTrue);
      final afterSuccess = await (db.select(
        db.events,
      )..where((e) => e.id.equals(local.id))).getSingle();
      expect(afterSuccess.title, 'Local edit');
      expect(afterSuccess.dirty, isFalse);
      expect(afterSuccess.etag, 'etag-1');
      expect(await events.pendingOutbox(), isEmpty);
      expect(provider.receivedEtags, ['etag-0', 'etag-remote']);
    },
  );

  test(
    'protected IDs переживают upsert, tombstone и full-window reconcile',
    () async {
      final calendar = (await accounts.calendarsOf(
        account.id,
      )).firstWhere((cal) => cal.id == '${account.id}:work');
      CalendarEvent event(String id, String providerId, String title) =>
          CalendarEvent(
            id: id,
            calendarId: calendar.id,
            title: title,
            startUtc: DateTime.utc(2026, 8, 28, 10),
            endUtc: DateTime.utc(2026, 8, 28, 11),
            source: EventSource(
              accountId: account.id,
              calendarId: calendar.id,
              providerEventId: providerId,
            ),
          );

      final upsert = event(
        'a:work:protected-upsert',
        'p-upsert',
        'Local upsert',
      );
      final tombstone = event(
        'a:work:protected-delete',
        'p-delete',
        'Local delete',
      );
      final reconcile = event('a:work:protected-rsvp', 'p-rsvp', 'Local RSVP');
      await events.putLocalDirty(upsert);
      await events.putLocalDirty(tombstone);
      // Даже если dirty-флаг потерян/снят, pending Outbox остаётся главным guard.
      await events.putLocalClean(reconcile);

      await events.applyPull(
        calendarId: calendar.id,
        upserts: [
          event(upsert.id, 'p-upsert-remote', 'Remote overwrite').copyWith(
            source: EventSource(
              accountId: account.id,
              calendarId: calendar.id,
              providerEventId: 'p-upsert-remote',
              etag: 'etag-remote',
            ),
          ),
          event('a:work:remote-new', 'p-new', 'Remote new'),
        ],
        deletedProviderIds: const ['p-delete'],
        protectedIds: {
          upsert.id,
          tombstone.id,
          reconcile.id,
          'a:work:remote-new',
        },
        windowStart: DateTime.utc(2026, 8, 1),
        windowEnd: DateTime.utc(2026, 9, 1),
        keepIds: {upsert.id, 'a:work:remote-new'},
      );

      final preservedUpsert = (await events.getById(upsert.id))!;
      expect(preservedUpsert.title, 'Local upsert');
      expect(preservedUpsert.source.etag, 'etag-remote');
      expect(preservedUpsert.source.providerEventId, 'p-upsert-remote');
      expect((await events.getById(tombstone.id))!.deletedRemotely, isFalse);
      expect(await events.getById(reconcile.id), isNotNull);
      expect(
        await events.getById('a:work:remote-new'),
        isNotNull,
        reason: 'protected id без локальной строки всё равно вставляется',
      );
    },
  );
}
