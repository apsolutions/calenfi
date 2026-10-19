import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// The Android UI and WorkManager run separate Dart isolates in one process.
/// An in-isolate Future alone cannot serialize their writes to the same cloud.
class PlatformAccountLock {
  final _token = const Uuid().v4();
  static const _channel = MethodChannel('ru.apsolutions.calenfi/background');

  Future<void> acquire(String account) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('acquireAccount', {
      'account': account,
      'token': _token,
    });
  }

  Future<void> release(String account) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('releaseAccount', {
      'account': account,
      'token': _token,
    });
  }
}
