// Жалоба: «fold опять отвалился от синхронизации» — «он просто ничего не мог
// обновить в фоне». Android замораживает приложение вне экрана и режет ему
// сеть, поэтому синхронизацию в фоне ведёт системная задача (WorkManager).

import 'dart:io';

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/background_sync.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/local/db/database_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/data/secure/data_dir.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/refresh_policy.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Провайдер: отвечает пустым списком календарей или падает «хост не найден».
class _Provider implements CalendarProvider {
  _Provider({this.offline = false});
  final bool offline;
  final asked = <String>[];

  @override
  ProviderType get type => ProviderType.caldav;

  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    asked.add(acc.id);
    if (offline) {
      throw const SocketException('Failed host lookup: example.test');
    }
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late AccountRepository accounts;
  late Directory configDirectory;

  Account account(String id,
          {RefreshPolicy refresh = const RefreshPolicy()}) =>
      Account(
        id: id,
        provider: ProviderType.caldav,
        displayName: id,
        email: '$id@example.test',
        refresh: refresh,
      );

  setUp(() {
    DiagLog.instance.clear();
    // Свой пустой каталог конфигурации: тест не должен читать accounts.json
    // с машины, на которой он запущен.
    configDirectory = Directory.systemTemp.createTempSync('calenfi-bg');
    calenfiDataDir = configDirectory.path;
    db = AppDatabase(NativeDatabase.memory());
    accounts = AccountRepository(db);
  });
  tearDown(() async {
    calenfiDataDir = null;
    await db.close();
    configDirectory.deleteSync(recursive: true);
  });

  test('фоновая задача синхронизирует просроченные аккаунты и ждёт их конца',
      () async {
    await accounts.upsertAccount(account('due'));
    await accounts.upsertAccount(account('fresh'));
    await accounts.recordSyncSuccess('fresh', DateTime.now().toUtc());
    await accounts.upsertAccount(account('manual',
        refresh: const RefreshPolicy(mode: RefreshMode.manual)));
    await accounts.setRefresh(
        'manual', const RefreshPolicy(mode: RefreshMode.manual));

    final provider = _Provider();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      providerRegistryProvider.overrideWithValue(
          ProviderRegistry(overrideFactory: (_) => provider)),
    ]);
    addTearDown(container.dispose);

    final started = await syncDueAccounts(container);

    expect(started, 1);
    expect(provider.asked, ['due']);
    final due =
        (await accounts.allAccounts()).firstWhere((a) => a.id == 'due');
    expect(due.lastSyncUtc, isNotNull,
        reason: 'задача вернулась только после конца прохода');
    expect(due.status, AccountStatus.ok);
  });

  group('отказ сети в фоне', () {
    SyncEngine engine(_Provider p, {required bool networkExpected}) =>
        SyncEngine(
          registry: ProviderRegistry(overrideFactory: (_) => p),
          accounts: accounts,
          events: EventRepository(db),
          networkExpected: () => networkExpected,
        );

    test('приложение в фоне: «хост не найден» не делает аккаунт сбойным',
        () async {
      await accounts.upsertAccount(account('a'));
      final report = await engine(_Provider(offline: true),
              networkExpected: false)
          .syncAccount(account('a'));

      expect(report.ok, isFalse);
      final a = (await accounts.allAccounts()).single;
      expect(a.status, AccountStatus.ok);
      expect(a.lastError, isNull);
      expect(DiagLog.instance.dump(), contains('приложение в фоне, сети нет'));
    });

    test('приложение на экране: тот же отказ показывается как «нет сети»',
        () async {
      await accounts.upsertAccount(account('a'));
      await engine(_Provider(offline: true), networkExpected: true)
          .syncAccount(account('a'));

      final a = (await accounts.allAccounts()).single;
      expect(a.status, AccountStatus.offline);
    });
  });

  test('нативная задача и Dart-точка входа называются одинаково', () {
    final worker = File(
            'android/app/src/main/kotlin/ru/apsolutions/calenfi/BackgroundSyncWorker.kt')
        .readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(worker, contains('ENTRYPOINT = "calenfiBackgroundSync"'));
    expect(
        RegExp(r"@pragma\('vm:entry-point'\)\s+Future<void> calenfiBackgroundSync\(\)")
            .hasMatch(main),
        isTrue,
        reason: 'без пометки функцию выбросит компилятор релизной сборки');
    expect(worker, contains('NetworkType.CONNECTED'));
    // Задача ставится при запуске, после обновления пакета и после загрузки.
    expect(
        File('android/app/src/main/kotlin/ru/apsolutions/calenfi/MainActivity.kt')
            .readAsStringSync(),
        contains('BackgroundSyncWorker.schedule'));
    final widget = File(
            'android/app/src/main/kotlin/ru/apsolutions/calenfi/AgendaWidgetProvider.kt')
        .readAsStringSync();
    expect(widget, contains('BackgroundSyncWorker.schedule'));
    expect(File('android/app/build.gradle.kts').readAsStringSync(),
        contains('androidx.work:work-runtime-ktx'));
  });
}
