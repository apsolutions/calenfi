import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app/accounts_config.dart';
import 'app/providers.dart';
import 'app/version.dart';
import 'data/secure/data_dir.dart';
import 'data/secure/secret_store.dart';
import 'data/secure/secret_store_mobile.dart';
import 'domain/models/account.dart';
import 'features/notifications/notification_sync.dart';
import 'features/widget/agenda_widget_service.dart';
import 'services/diag_log.dart';

/// Сколько фоновая задача ждёт: Android даёт ей 10 минут.
const _budget = Duration(minutes: 8);

/// Точка входа фоновой задачи Android (см. BackgroundSyncWorker.kt).
///
/// Запускается в отдельном движке без интерфейса. Если приложение в этом же
/// процессе живо, синхронизацию делает оно: у него открыта база и собран
/// движок синка. Если процесс подняли с нуля — синхронизируем сами.
Future<void> runBackgroundSyncEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  const channel = MethodChannel('ru.apsolutions.calenfi/background');
  try {
    if (!await _askLiveApp()) await _syncHeadless();
  } on Object catch (e, st) {
    DiagLog.instance.error('bg', 'фоновая синхронизация не удалась', e, st);
  } finally {
    await channel.invokeMethod<void>('done');
  }
}

/// Просит живое приложение синхронизироваться. false — приложения нет.
Future<bool> _askLiveApp() async {
  final ui = IsolateNameServer.lookupPortByName(kUiSyncPortName);
  if (ui == null) return false;
  final reply = ReceivePort();
  final answers = StreamIterator<dynamic>(reply);
  try {
    ui.send(reply.sendPort);
    // Порт мог остаться от уже закрытого приложения: живое отвечает сразу.
    final acked = await answers
        .moveNext()
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    if (!acked || answers.current != 'ack') {
      IsolateNameServer.removePortNameMapping(kUiSyncPortName);
      return false;
    }
    await answers.moveNext().timeout(_budget, onTimeout: () => false);
    return true;
  } finally {
    reply.close();
  }
}

Future<void> _syncHeadless() async {
  calenfiDataDir = (await getApplicationSupportDirectory()).path;
  DiagLog.instance.echo = true;
  DiagLog.instance.attachFile('${configDir()}/calenfi.log');
  DiagLog.instance.add('bg', 'фоновая синхронизация $kAppVersion: старт');
  backgroundJobActive = true;
  SecretStore.backend = const MobileSecureStorageBackend();
  await SecretStore.instance.warmUp();
  tzdata.initializeTimeZones();

  final container = ProviderContainer();
  try {
    final synced = await syncDueAccounts(container).timeout(_budget,
        onTimeout: () {
      DiagLog.instance.add('bg', 'время вышло, часть аккаунтов не успела');
      return -1;
    });
    await pushAgendaWidgetOnce(container);
    await rescheduleNotificationsOnce(container);
    DiagLog.instance.add('bg', 'готово, аккаунтов синхронизировано: $synced');
  } finally {
    container.dispose();
  }
}

/// Синхронизирует аккаунты, у которых истёк их интервал, и ждёт, пока все
/// проходы действительно закончатся. Возвращает число запущенных проходов.
Future<int> syncDueAccounts(ProviderContainer container) async {
  final repo = container.read(accountRepositoryProvider);
  final known = (await repo.allAccounts()).map((a) => a.id).toSet();
  for (final a in loadConfiguredAccounts()) {
    if (!known.contains(a.id)) await repo.upsertAccount(a);
  }
  final engine = container.read(syncEngineProvider);
  final now = DateTime.now().toUtc();
  var started = 0;
  for (final Account a in await repo.allAccounts()) {
    final interval = a.refresh.effectiveInterval;
    if (interval == Duration.zero) continue; // ручной режим
    final last = a.lastSyncUtc;
    if (last == null || now.difference(last) >= interval) {
      started++;
      unawaited(engine.syncAccount(a));
    }
  }
  await engine.whenIdle();
  return started;
}
