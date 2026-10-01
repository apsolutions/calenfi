import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/db/database_provider.dart';
import '../data/providers/calendar/provider_registry.dart';
import '../data/local/db/database.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/event_repository.dart';
import '../domain/models/account.dart';
import '../domain/models/calendar.dart';
import '../services/diag_log.dart';
import '../sync/sync_engine.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(databaseProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final providerRegistryProvider = Provider<ProviderRegistry>((ref) {
  return ProviderRegistry();
});

/// Имя порта, под которым живое приложение принимает просьбу фоновой задачи
/// Android «синхронизируй просроченное» (см. `lib/background_sync.dart`).
const kUiSyncPortName = 'ru.apsolutions.calenfi.ui-sync';

/// Идёт фоновая задача Android: на её время система выдала приложению сеть,
/// хотя оно не на экране.
bool backgroundJobActive = false;

/// Можно ли сейчас рассчитывать на сеть. На телефоне приложению в фоне её
/// режут, и отказ «хост не найден» там ничего не говорит об аккаунте.
bool _networkExpected() {
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!mobile || backgroundJobActive) return true;
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    registry: ref.watch(providerRegistryProvider),
    accounts: ref.watch(accountRepositoryProvider),
    events: ref.watch(eventRepositoryProvider),
    contacts: ref.watch(contactRepositoryProvider),
    networkExpected: _networkExpected,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

final calendarsStreamProvider = StreamProvider<List<Calendar>>((ref) {
  return ref.watch(accountRepositoryProvider).watchCalendars();
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(databaseProvider));
});

/// Справочник контактов (FR-K) для автодополнения участников.
final contactsStreamProvider = StreamProvider<List<ContactRow>>((ref) {
  return ref.watch(contactRepositoryProvider).watchAll();
});

/// Колбэк ручной синхронизации (FR-S3). Ручной синк СБРАСЫВАЕТ счётчики попыток
/// Outbox — задания, «сгоревшие» из-за временной проблемы (протухший пароль),
/// получают новый шанс после её починки. Фоновый синк ретраи не сбрасывает.
final syncTriggerProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(eventRepositoryProvider).resetOutboxRetries();
    await ref.read(syncEngineProvider).syncAll();
  };
});

/// Регулярная автосинхронизация по индивидуальному расписанию каждого аккаунта
/// (FR-A10/FR-S2). Тикаем раз в минуту и синкаем те аккаунты, у которых истёк
/// их интервал (`RefreshPolicy.effectiveInterval`; `manual` → не автосинкается).
/// Watch'ить в корне App. Без неё календарь обновлялся только при старте/кнопке.
final periodicSyncProvider = Provider<void>((ref) {
  Future<void> syncDue() async {
    // Движок и репозиторий читаем на каждом тике, а не один раз при создании.
    // Переподключение аккаунта пересоздаёт реестр провайдеров и движок; если
    // держать здесь прежний движок, фоновый синк продолжит ходить со старыми
    // учётными данными (пустыми или отозванными) и через несколько минут
    // после успешного входа снова пометит аккаунт «нужно переподключение» —
    // и так до перезапуска приложения.
    final engine = ref.read(syncEngineProvider);
    final all = await ref.read(accountRepositoryProvider).allAccounts();
    final now = DateTime.now().toUtc();
    for (final a in all) {
      final interval = a.refresh.effectiveInterval;
      if (interval == Duration.zero) continue; // ручной режим
      final last = a.lastSyncUtc;
      if (last == null || now.difference(last) >= interval) {
        engine.syncAccount(a); // fire-and-forget, ошибки изолированы
      }
    }
  }

  final timer = Timer.periodic(const Duration(minutes: 1), (_) => syncDue());
  // Android в энергосбережении отрезает сеть фоновым приложениям: фоновые
  // попытки падают, и аккаунт висит «нет сети» со старыми встречами. При
  // возврате на экран досинкиваем просроченное сразу, не ждём минутного тика.
  // Короткая пауза — система снимает сетевой запрет чуть позже onResume.
  Timer? resumeDelay;
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) => DiagLog.instance.add('app', 'состояние: ${state.name}'),
    onResume: () {
      resumeDelay?.cancel();
      resumeDelay = Timer(const Duration(seconds: 2), syncDue);
    },
  );
  // Фоновая задача Android будит процесс раз в 15 минут и просит живое
  // приложение синхронизироваться: у него уже открыта база и собран движок.
  final jobs = ReceivePort();
  IsolateNameServer.removePortNameMapping(kUiSyncPortName);
  IsolateNameServer.registerPortWithName(jobs.sendPort, kUiSyncPortName);
  jobs.listen((message) async {
    if (message is! SendPort) return;
    message.send('ack');
    backgroundJobActive = true;
    DiagLog.instance.add('bg', 'фоновая задача: синхронизирую просроченное');
    try {
      await syncDue();
      await ref.read(syncEngineProvider).whenIdle();
      DiagLog.instance.add('bg', 'фоновая задача: готово');
    } on Object catch (e, st) {
      DiagLog.instance.error('bg', 'фоновая задача не удалась', e, st);
    } finally {
      backgroundJobActive = false;
      message.send('done');
    }
  });

  ref.onDispose(() {
    timer.cancel();
    resumeDelay?.cancel();
    lifecycle.dispose();
    IsolateNameServer.removePortNameMapping(kUiSyncPortName);
    jobs.close();
  });
});
