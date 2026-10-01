// Жалоба: «календари опять отвалились». После входа аккаунт через несколько
// минут снова показывал «нужно переподключение» и держал это до перезапуска.
// Переподключение пересоздаёт движок синхронизации, а фоновый синк держал
// прежний — со старыми учётными данными.

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingEngine implements SyncEngine {
  final synced = <String>[];

  @override
  Future<AccountSyncReport> syncAccount(Account acc) async {
    synced.add(acc.id);
    return AccountSyncReport(acc.id);
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _OneOverdueAccount implements AccountRepository {
  @override
  Future<List<Account>> allAccounts() async => const [
        Account(
          id: 'acc-1',
          provider: ProviderType.graph,
          displayName: 'Work',
          email: 'user@example.test',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  setUp(() => DiagLog.instance.echo = false);

  testWidgets('фоновый синк после переподключения ходит через новый движок',
      (tester) async {
    final engines = <_CountingEngine>[];
    final generation = StateProvider<int>((_) => 0);
    final container = ProviderContainer(overrides: [
      accountRepositoryProvider.overrideWithValue(_OneOverdueAccount()),
      // Как настоящий провайдер: движок пересоздаётся, когда меняется то, от
      // чего он зависит (в приложении это реестр провайдеров календарей).
      syncEngineProvider.overrideWith((ref) {
        ref.watch(generation);
        final engine = _CountingEngine();
        engines.add(engine);
        return engine;
      }),
    ]);

    container.read(periodicSyncProvider);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(engines, hasLength(1));
    expect(engines[0].synced, ['acc-1']);

    // Переподключение аккаунта.
    container.read(generation.notifier).state++;

    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(engines, hasLength(2));
    expect(engines[1].synced, ['acc-1'],
        reason: 'фоновый синк обязан взять текущий движок');
    expect(engines[0].synced, ['acc-1'],
        reason: 'прежний движок со старыми учётными данными больше не зовём');

    // Минутный таймер фонового синка живёт в провайдере: снимаем его до
    // проверки «не осталось ли таймеров» в конце теста.
    container.dispose();
  });
}
