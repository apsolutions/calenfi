// Задание delete без поля `scope` (так их ставил агентский CLI) удаляло одно
// вхождение: разбор payload подставлял 0 = thisOnly, и ветка «по умолчанию —
// вся серия» была недостижима. Старые серии оставались в календаре.

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/mock/mock_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingProvider extends MockProvider {
  _RecordingProvider(super.accountId);
  final deleteScopes = <RecurrenceScope>[];

  @override
  Future<void> deleteEvent(
      Account acc, CalendarEvent e, RecurrenceScope scope) async {
    deleteScopes.add(scope);
    await super.deleteEvent(acc, e, scope);
  }
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;
  late SyncEngine engine;
  late _RecordingProvider provider;

  const acc = Account(
      id: 'a', provider: ProviderType.google, displayName: 'A', email: 'a@x.com');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    provider = _RecordingProvider('a');
    engine = SyncEngine(
      registry: ProviderRegistry(overrideFactory: (_) => provider),
      accounts: accounts,
      events: events,
    );
    await accounts.upsertAccount(acc);
    await engine.syncAccount(acc); // заведёт календари
  });
  tearDown(() => db.close());

  Future<CalendarEvent> occurrence() async {
    final cal = (await accounts.calendarsOf('a')).first;
    final e = CalendarEvent(
      id: 'a:series_20300106T100000Z',
      calendarId: cal.id,
      title: 'Кружок',
      startUtc: DateTime.utc(2030, 1, 6, 10),
      endUtc: DateTime.utc(2030, 1, 6, 11),
      recurrenceId: 'series',
      source: EventSource(
          accountId: 'a',
          calendarId: cal.id,
          providerEventId: 'series_20300106T100000Z'),
    );
    await events.putLocalDirty(e.copyWith(deletedRemotely: true));
    return e;
  }

  test('delete без scope удаляет всю серию', () async {
    final e = await occurrence();
    await events.enqueue('delete', e.id);

    await engine.syncAccount(acc);

    expect(provider.deleteScopes, [RecurrenceScope.all]);
    expect(await events.pendingOutbox(), isEmpty);
  });

  test('delete со scope передаёт область провайдеру', () async {
    final e = await occurrence();
    await events.enqueue(
        'delete', e.id, {'scope': RecurrenceScope.thisAndFollowing.index});

    await engine.syncAccount(acc);

    expect(provider.deleteScopes, [RecurrenceScope.thisAndFollowing]);
  });

  test('enqueue возвращает id задания', () async {
    final e = await occurrence();
    final id = await events.enqueue('delete', e.id, {'scope': 0});
    expect((await events.pendingOutbox()).single.id, id);
  });
}
