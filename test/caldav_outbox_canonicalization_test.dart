import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/mock/mock_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _CanonicalizingProvider extends MockProvider {
  _CanonicalizingProvider(super.accountId);

  static const canonicalId = 'a:work:uid-1';

  final createdIds = <String>[];
  final updatedIds = <String>[];
  final updatedEtags = <String?>[];
  final deletedIds = <String>[];
  final deletedEtags = <String?>[];
  var _etagRevision = 0;

  @override
  Future<CalendarEvent> createEvent(
    Account acc,
    Calendar calendar,
    CalendarEvent event,
  ) async {
    createdIds.add(event.id);
    return event.withLocalId(canonicalId);
  }

  @override
  Future<CalendarEvent> updateEvent(Account acc, CalendarEvent event) async {
    updatedIds.add(event.id);
    updatedEtags.add(event.source.etag);
    final etag = 'etag-${++_etagRevision}';
    return event
        .withLocalId(canonicalId)
        .copyWith(source: event.source.copyWith(etag: etag));
  }

  @override
  Future<void> deleteEvent(
    Account acc,
    CalendarEvent event,
    RecurrenceScope scope,
  ) async {
    deletedIds.add(event.id);
    deletedEtags.add(event.source.etag);
  }
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;
  late SyncEngine engine;
  late _CanonicalizingProvider provider;

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
    provider = _CanonicalizingProvider(account.id);
    engine = SyncEngine(
      registry: ProviderRegistry(overrideFactory: (_) => provider),
      accounts: accounts,
      events: events,
    );
    await accounts.upsertAccount(account);
    await engine.syncAccount(account);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  test('outbox переносит dirty-строку с legacy id на канонический', () async {
    final calendar = (await accounts.calendarsOf(account.id)).first;
    const legacyId = 'a:work:a:work:a:work:uid-1';
    final legacy = CalendarEvent(
      id: legacyId,
      calendarId: calendar.id,
      title: 'МЭС с Леной',
      startUtc: DateTime.utc(2026, 8, 28, 15, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16, 15),
      source: EventSource(
        accountId: account.id,
        calendarId: calendar.id,
        providerEventId: '/calendars/a/events/actual.ics',
      ),
    );
    await events.putLocalDirty(legacy);
    await events.enqueue('update', legacy.id);

    final report = await engine.syncAccount(account);

    expect(report.ok, isTrue);
    expect(await events.pendingOutbox(), isEmpty);
    expect(
      await events.getById(legacyId),
      isNull,
      reason: 'старый dirty-id иначе переживёт reconcile и останется дублем',
    );
    final canonical = await events.getById(_CanonicalizingProvider.canonicalId);
    expect(canonical, isNotNull);
    expect(canonical!.source.providerEventId, '/calendars/a/events/actual.ics');
  });

  test('rekey сохраняет update → update → delete цепочку snapshot', () async {
    final calendar = (await accounts.calendarsOf(account.id)).first;
    const legacyId = 'a:work:a:work:a:work:uid-1';
    final legacy = CalendarEvent(
      id: legacyId,
      calendarId: calendar.id,
      title: 'МЭС с Леной',
      startUtc: DateTime.utc(2026, 8, 28, 15, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16, 15),
      source: EventSource(
        accountId: account.id,
        calendarId: calendar.id,
        providerEventId: '/calendars/a/events/actual.ics',
      ),
    );
    await events.putLocalDirty(legacy);
    await events.enqueue('update', legacy.id);
    await events.enqueue('update', legacy.id);
    await events.enqueue('delete', legacy.id);

    final report = await engine.syncAccount(account);

    expect(report.ok, isTrue);
    expect(provider.updatedIds, [
      legacyId,
      _CanonicalizingProvider.canonicalId,
    ]);
    expect(provider.deletedIds, [_CanonicalizingProvider.canonicalId]);
    expect(await events.pendingOutbox(), isEmpty);
    expect(await events.getById(legacyId), isNull);
    expect(await events.getById(_CanonicalizingProvider.canonicalId), isNull);
  });

  test('rekey после create сохраняет следующий update snapshot', () async {
    final calendar = (await accounts.calendarsOf(account.id)).first;
    const localId = 'local-uuid-1';
    final local = CalendarEvent(
      id: localId,
      calendarId: calendar.id,
      title: 'Новая встреча',
      startUtc: DateTime.utc(2026, 8, 28, 15, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16, 15),
      source: EventSource(
        accountId: account.id,
        calendarId: calendar.id,
        providerEventId: localId,
      ),
    );
    await events.putLocalDirty(local);
    await events.enqueue('create', local.id);
    await events.enqueue('update', local.id);

    final report = await engine.syncAccount(account);

    expect(report.ok, isTrue);
    expect(provider.createdIds, [localId]);
    expect(provider.updatedIds, [_CanonicalizingProvider.canonicalId]);
    expect(await events.pendingOutbox(), isEmpty);
    expect(await events.getById(localId), isNull);
    expect(
      await events.getById(_CanonicalizingProvider.canonicalId),
      isNotNull,
    );
  });

  test('same-id update сохраняет новый ETag для update → delete', () async {
    final calendar = (await accounts.calendarsOf(account.id)).first;
    final event = CalendarEvent(
      id: _CanonicalizingProvider.canonicalId,
      calendarId: calendar.id,
      title: 'Цепочка ETag',
      startUtc: DateTime.utc(2026, 8, 28, 15, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16, 15),
      source: EventSource(
        accountId: account.id,
        calendarId: calendar.id,
        providerEventId: '/calendars/a/events/actual.ics',
        etag: 'etag-0',
      ),
    );
    await events.putLocalDirty(event);
    await events.enqueue('update', event.id);
    await events.enqueue('update', event.id);
    await events.enqueue('delete', event.id);

    final report = await engine.syncAccount(account);

    expect(report.ok, isTrue);
    expect(provider.updatedIds, [
      _CanonicalizingProvider.canonicalId,
      _CanonicalizingProvider.canonicalId,
    ]);
    expect(provider.updatedEtags, ['etag-0', 'etag-1']);
    expect(provider.deletedEtags, ['etag-2']);
    expect(await events.pendingOutbox(), isEmpty);
  });
}
