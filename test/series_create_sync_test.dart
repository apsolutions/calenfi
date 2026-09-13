// Создание повторяющейся серии не должно оставлять в базе ЛИШНЕЕ событие.
// Провайдер на create отдаёт мастер серии, а при чтении — только развёрнутые
// вхождения; раньше мастер застревал локально dirty и висел в сетке рядом с
// первым вхождением как отдельная встреча.

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/domain/providers/provider_capabilities.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _calendarId = 'a|primary';
final _seriesStart = DateTime.utc(2026, 9, 13, 11);

/// Ведёт себя как Google: create возвращает мастер, чтение отдаёт вхождения.
class _SeriesProvider implements CalendarProvider {
  final created = <CalendarEvent>[];

  @override
  ProviderType get type => ProviderType.google;
  @override
  ProviderCapabilities get caps => ProviderCapabilities.google;

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async =>
      AuthResult(success: true);
  @override
  Future<void> refreshAuth(Account acc) async {}

  @override
  Future<List<Calendar>> listCalendars(Account acc) async => const [
    Calendar(
      id: _calendarId,
      accountId: 'a',
      name: 'Основной',
      color: 0xFF4F86F7,
      isPrimary: true,
    ),
  ];

  @override
  Future<List<CalendarEvent>> fetchEvents(
          Account acc, Calendar cal, DateRange range) async =>
      _occurrences();

  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  ) async => SyncResult(
    upserts: created.isEmpty ? const [] : _occurrences(),
    deletedIds: const [],
    newSyncState: null,
    fullWindow: DateRange(
      DateTime.utc(2026, 9, 1),
      DateTime.utc(2026, 10, 1),
    ),
  );

  List<CalendarEvent> _occurrences() => [
    for (var week = 0; week < 2; week++)
      _occurrence(_seriesStart.add(Duration(days: 7 * week))),
  ];

  CalendarEvent _occurrence(DateTime start) {
    final stamp = '${start.year}${start.month.toString().padLeft(2, '0')}'
        '${start.day.toString().padLeft(2, '0')}T110000Z';
    return CalendarEvent(
      id: 'a:series_$stamp',
      calendarId: _calendarId,
      title: 'Тренировка',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      recurrenceId: 'series',
      source: EventSource(
        accountId: 'a',
        calendarId: _calendarId,
        providerEventId: 'series_$stamp',
      ),
    );
  }

  @override
  Future<CalendarEvent> createEvent(
    Account acc,
    Calendar cal,
    CalendarEvent e,
  ) async {
    // Как Google: ответ на POST — МАСТЕР серии, id без суффикса вхождения.
    final master = CalendarEvent(
      id: 'a:series',
      calendarId: cal.id,
      title: e.title,
      startUtc: e.startUtc,
      endUtc: e.endUtc,
      recurrenceRule: e.recurrenceRule,
      source: const EventSource(
        accountId: 'a',
        calendarId: _calendarId,
        providerEventId: 'series',
      ),
    );
    created.add(master);
    return master;
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async => e;

  @override
  Future<void> deleteEvent(
      Account acc, CalendarEvent e, RecurrenceScope scope) async {}

  @override
  Future<void> respondToInvite(
      Account acc, CalendarEvent e, ResponseStatus r) async {}
}

void main() {
  late AppDatabase db;
  late EventRepository events;
  late AccountRepository accounts;
  late SyncEngine engine;
  late _SeriesProvider provider;

  const account = Account(
    id: 'a',
    provider: ProviderType.google,
    displayName: 'Google',
    email: 'a@example.com',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    provider = _SeriesProvider();
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

  test('после создания серии в базе остаются только её вхождения', () async {
    final draft = CalendarEvent(
      id: 'local-uuid',
      calendarId: _calendarId,
      title: 'Тренировка',
      startUtc: _seriesStart,
      endUtc: _seriesStart.add(const Duration(hours: 1)),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=SU',
      source: const EventSource(accountId: 'a', calendarId: _calendarId),
    );
    await events.putLocalDirty(draft);
    await events.enqueue('create', draft.id);

    await engine.syncAccount(account);

    final rows = await db.select(db.events).get();
    expect(
      rows.map((e) => e.id).toList()..sort(),
      ['a:series_20260913T110000Z', 'a:series_20260920T110000Z'],
      reason: 'мастер серии не должен оставаться отдельной встречей',
    );
  });
}
