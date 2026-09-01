import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app/app.dart';
import 'data/local/db/database_location.dart';
import 'data/secure/data_dir.dart';
import 'data/secure/secret_store.dart';
import 'data/secure/secret_store_mobile.dart';

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
  await SecretStore.instance.warmUp();
  tzdata.initializeTimeZones(); // FR-V7
  // Уведомления инициализируются лениво при первом планировании
  // (`notificationSyncProvider` → `NotificationService.sync` → `init`), уже
  // после старта UI — иначе запрос разрешения завис бы до первого кадра.
  runApp(const ProviderScope(child: CalenfiApp()));
}
