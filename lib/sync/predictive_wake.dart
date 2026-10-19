import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/diag_log.dart';

/// WorkManager survives process death. Desktop uses the live app timer;
/// iOS has no native background scheduler in this application yet.
Future<void> schedulePredictiveWake(DateTime? when) async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'ru.apsolutions.calenfi/background',
    ).invokeMethod<void>('schedulePredictive', {
      'at': when?.millisecondsSinceEpoch,
    });
  } on MissingPluginException {
    // Tests and older native hosts may not expose this optional channel.
  } on PlatformException catch (e) {
    DiagLog.instance.add(
      'sync-plan',
      'Не удалось запланировать фоновый запуск: ${e.code}',
    );
  }
}
