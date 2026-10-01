// Вход через браузер зависал на последней странице провайдера: Android
// замораживал приложение, пока человек вводил пароль, а ответ браузера ждал
// локальный сервер внутри приложения. На время входа процесс держит служба
// переднего плана — и её обязательно надо снять, чем бы вход ни кончился.

import 'dart:io';

import 'package:calenfi/data/secure/oauth_flow.dart';
import 'package:calenfi/features/accounts/connect_account.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    DiagLog.instance.echo = false;
    DiagLog.instance.clear();
  });

  ConnectAccountService service(List<String> calls) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(Provider((ref) => ConnectAccountService(
          ref,
          keepAliveStart: () async => calls.add('start'),
          keepAliveStop: () async => calls.add('stop'),
        )));
  }

  test('служба поднята до входа и снята после него', () async {
    final calls = <String>[];
    final result = await service(calls).guardedLogin('Office 365', (_) async {
      calls.add('flow');
      return OAuthResult('at', 'rt', 3600, const {});
    });
    expect(result.accessToken, 'at');
    expect(calls, ['start', 'flow', 'stop']);
  });

  test('неудачный вход тоже снимает службу и попадает в журнал', () async {
    final calls = <String>[];
    await expectLater(
      service(calls).guardedLogin('Office 365',
          (_) async => throw OAuthException('время ожидания входа истекло')),
      throwsA(isA<OAuthException>()),
    );
    expect(calls, ['start', 'stop']);
    expect(DiagLog.instance.dump(), contains('Office 365: вход не удался'));
    expect(DiagLog.instance.dump(), contains('время ожидания входа истекло'));
  });

  test('манифест: служба, разрешения и ссылка возврата объявлены', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest,
        contains('com.dexterous.flutterlocalnotifications.ForegroundService'));
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE"'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'));

    final uri = Uri.parse(ConnectAccountService.loginReturnUrl);
    expect(manifest,
        contains('android:scheme="${uri.scheme}" android:host="${uri.host}"'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    // Ссылка возврата — не маршрут приложения.
    expect(
        RegExp(r'flutter_deeplinking_enabled"\s+android:value="false"')
            .hasMatch(manifest),
        isTrue);
  });
}
