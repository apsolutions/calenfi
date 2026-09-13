// Жалоба: APK, скачанный с GitHub, не подключал Google — «вход через браузер»,
// но ничего не происходит. OAuth-клиентов не было ни в сборке, ни в keyring
// нового устройства. Теперь клиенты зашиваются при сборке (--dart-define), а
// свой клиент пользователя в keyring по-прежнему важнее зашитого.

import 'dart:convert';
import 'dart:io';

import 'package:calenfi/data/secure/build_credentials.dart';
import 'package:calenfi/data/secure/credential_source.dart';
import 'package:calenfi/data/secure/data_dir.dart';
import 'package:calenfi/data/secure/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBackend extends KeyringBackend {
  String? blob;

  @override
  Future<String?> read() async => blob;

  @override
  Future<void> write(String value) async => blob = value;
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('calenfi-build-creds-');
    calenfiDataDir = tmp.path;
    SecretStore.fallbackBackend = _MemoryBackend();
    CredentialSource.buildDefaults = const {
      'GOOGLE_OAUTH_CLIENT_ID': 'built.apps.googleusercontent.com',
      'GOOGLE_OAUTH_CLIENT_SECRET': 'built-secret',
      'GRAPH_CLIENT_ID': 'built-graph',
    };
  });

  tearDown(() {
    CredentialSource.buildDefaults = BuildCredentials.values;
    calenfiDataDir = null;
    tmp.deleteSync(recursive: true);
  });

  Future<void> keyring(Map<String, String> values) async {
    SecretStore.backend = _MemoryBackend()..blob = jsonEncode(values);
    await SecretStore.instance.warmUp(force: true);
  }

  test('на чистом устройстве OAuth-клиенты берутся из сборки', () async {
    await keyring({});

    final creds = CredentialSource.load();
    expect(creds.googleClientId, 'built.apps.googleusercontent.com');
    expect(creds.googleClientSecret, 'built-secret');
    expect(creds.graphClientId, 'built-graph');
    expect(creds.graphTenant, 'common');
  });

  test('свой клиент из keyring важнее зашитого в сборку', () async {
    await keyring({'GOOGLE_OAUTH_CLIENT_ID': 'mine.apps.googleusercontent.com'});

    final creds = CredentialSource.load();
    expect(creds.googleClientId, 'mine.apps.googleusercontent.com');
    expect(creds.graphClientId, 'built-graph');
  });

  test('пустое значение в keyring не прячет клиент сборки', () async {
    await keyring({'GRAPH_CLIENT_ID': ''});

    expect(CredentialSource.load().graphClientId, 'built-graph');
  });

  test('в сборку зашиваются только идентификаторы OAuth-приложений', () {
    for (final key in BuildCredentials.keys) {
      expect(key, matches(RegExp(r'_(CLIENT_ID|CLIENT_SECRET|TENANT)$')),
          reason: '$key не похож на идентификатор OAuth-приложения');
      expect(key, isNot(matches(RegExp(r'PASSWORD|TOKEN|ZOOM'))),
          reason: 'пароли, токены и ключи Zoom в сборку не зашиваются');
    }
  });
}
