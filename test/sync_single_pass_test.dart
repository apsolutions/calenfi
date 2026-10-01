// Медленный аккаунт. Лимит в 150 секунд раньше снимал защиту от повторного
// запуска, хотя проход продолжал работать: минутный тик добавлял к нему новые
// проходы, они тормозили друг друга, а аккаунт показывал «превышен лимит».

import 'dart:async';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Провайдер, который отвечает, только когда тест откроет [gate].
class _SlowProvider implements CalendarProvider {
  final gate = Completer<void>();
  int passes = 0;

  @override
  ProviderType get type => ProviderType.caldav;

  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    passes++;
    await gate.future;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late EventRepository events;

  const acc = Account(
    id: 'a',
    provider: ProviderType.caldav,
    displayName: 'Test',
    email: 'a@example.test',
  );

  setUp(() async {
    DiagLog.instance.clear();
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
    events = EventRepository(db);
    await accounts.upsertAccount(acc);
  });
  tearDown(() => db.close());

  SyncEngine engineWith(CalendarProvider p,
          {Duration soft = const Duration(milliseconds: 40),
          Duration hard = const Duration(seconds: 30)}) =>
      SyncEngine(
        registry: ProviderRegistry(overrideFactory: (_) => p),
        accounts: accounts,
        events: events,
        softLimit: soft,
        hardLimit: hard,
      );

  test('долгий проход не считается сбоем и не запускается второй раз',
      () async {
    final provider = _SlowProvider();
    final engine = engineWith(provider);

    final first = await engine.syncAccount(acc);
    expect(first.ok, isFalse);
    expect(first.error, 'still running');
    expect((await accounts.allAccounts()).single.status, AccountStatus.ok,
        reason: 'проход ещё идёт — это не ошибка аккаунта');
    expect(engine.activeCount, 1, reason: 'индикатор синка продолжает гореть');

    // Минутный тик и ручной refresh, пока проход идёт.
    await engine.syncAccount(acc);
    await engine.syncAccount(acc);
    expect(provider.passes, 1, reason: 'новые проходы не наслаиваются');

    provider.gate.complete();
    final done = await engine.syncAccount(acc);
    expect(done.ok, isTrue);
    final account = (await accounts.allAccounts()).single;
    expect(account.status, AccountStatus.ok);
    expect(account.lastSyncUtc, isNotNull);
    expect(engine.activeCount, 0);
    expect(DiagLog.instance.dump(), contains('продолжается в фоне'));
  });

  test('зависший проход получает статус ошибки, следующий вызов начинает новый',
      () async {
    final provider = _SlowProvider();
    final engine = engineWith(provider,
        soft: const Duration(milliseconds: 20),
        hard: const Duration(milliseconds: 60));

    await engine.syncAccount(acc);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final account = (await accounts.allAccounts()).single;
    expect(account.status, AccountStatus.syncError);
    expect(account.lastError, contains('лимит времени'));
    expect(engine.activeCount, 0);

    await engine.syncAccount(acc);
    expect(provider.passes, 2);
    provider.gate.complete();
  });
}
