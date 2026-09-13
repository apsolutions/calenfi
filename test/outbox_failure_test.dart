// Регресс критичной заглушки: раньше упавшее outbox-задание молча ретраилось
// вечно (retryCount писался, но нигде не читался) — правка на EWS «терялась»
// без ошибки. Контракт после фикса: постоянная ошибка (Unsupported/Unimplemented)
// сразу «сжигает» попытки и ставит аккаунту статус syncError; после лимита
// задание больше не долбит сервер.

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

/// Провайдер, у которого запись НЕ поддержана (как EWS-заглушка была).
class _WriteFailsProvider extends MockProvider {
  _WriteFailsProvider(super.accountId);
  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async =>
      throw UnsupportedError('запись не поддержана');
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;
  late SyncEngine engine;

  const acc = Account(
      id: 'a', provider: ProviderType.ews, displayName: 'A', email: 'a@x.com');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    engine = SyncEngine(
      registry:
          ProviderRegistry(overrideFactory: (a) => _WriteFailsProvider(a.id)),
      accounts: accounts,
      events: events,
    );
    await accounts.upsertAccount(acc);
    await engine.syncAccount(acc); // заведёт календари
  });
  tearDown(() => db.close());

  test('постоянная ошибка записи → статус syncError, а не тихий вечный ретрай',
      () async {
    final cal = (await accounts.calendarsOf('a')).first;
    final e = CalendarEvent(
      id: 'a:evt-1',
      calendarId: cal.id,
      title: 'Правка',
      startUtc: DateTime.utc(2030, 1, 1, 10),
      endUtc: DateTime.utc(2030, 1, 1, 11),
      source: EventSource(
          accountId: 'a', calendarId: cal.id, providerEventId: 'srv-1'),
    );
    await events.putLocalDirty(e);
    await events.enqueue('update', e.id);

    await engine.syncAccount(acc);

    // Аккаунт помечен ошибкой (видно пользователю), а не «ok».
    final a = (await accounts.allAccounts()).first;
    expect(a.status, AccountStatus.syncError);
    expect(a.lastError, contains('не поддержана'));

    // Попытки «сожжены» — повторный синк уже не трогает задание.
    final outbox = await events.pendingOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.first.retryCount, greaterThanOrEqualTo(5));
  });
}
