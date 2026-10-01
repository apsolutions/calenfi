import 'dart:io';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app/app.dart';
import 'app/version.dart';
import 'background_sync.dart';
import 'data/local/db/database_location.dart';
import 'data/secure/data_dir.dart';
import 'data/secure/secret_store.dart';
import 'data/secure/secret_store_mobile.dart';
import 'services/diag_log.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // На мобиле и Windows конфиг лежит в каталоге данных приложения (рядом с БД),
  // а на Linux/macOS — в пользовательском config-каталоге. Резолвим до старта UI.
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    final supportDirectory = await getApplicationSupportDirectory();
    if (Platform.isWindows) {
      // accounts.json и DPAPI ciphertext должны переехать до SecretStore.warmUp,
      // иначе первый запуск под новым CompanyName выглядит как потеря аккаунтов.
      await prepareWindowsAncillaryState(targetDirectory: supportDirectory);
    }
    calenfiDataDir = supportDirectory.path;
  }
  // Секреты (пароли приложений, OAuth-токены) — в системном keyring. На мобиле
  // штатных утилит нет, поэтому там бэкенд на flutter_secure_storage.
  if (Platform.isAndroid || Platform.isIOS) {
    SecretStore.backend = const MobileSecureStorageBackend();
  }
  // Журнал диагностики — до всего, что может упасть: хранилище секретов,
  // база, синхронизация пишут в него причины сбоев.
  DiagLog.instance.echo = true;
  DiagLog.instance.attachFile('${configDir()}/calenfi.log');
  DiagLog.instance.add(
      'app',
      'запуск $kAppVersion, ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}');
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    DiagLog.instance.error(
        'app', 'ошибка интерфейса', details.exception, details.stack);
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    DiagLog.instance.error('app', 'необработанная ошибка', error, stack);
    return false;
  };
  await SecretStore.instance.warmUp();
  tzdata.initializeTimeZones(); // FR-V7
  // Уведомления инициализируются лениво при первом планировании
  // (`notificationSyncProvider` → `NotificationService.sync` → `init`), уже
  // после старта UI — иначе запрос разрешения завис бы до первого кадра.
  runApp(const ProviderScope(child: CalenfiApp()));
}

/// Фоновая синхронизация: эту функцию по имени запускает Android
/// (BackgroundSyncWorker.kt). Должна жить в главной библиотеке приложения.
@pragma('vm:entry-point')
Future<void> calenfiBackgroundSync() => runBackgroundSyncEntrypoint();
