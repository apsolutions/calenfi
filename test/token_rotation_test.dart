// Office 365 отваливался с invalid_grant примерно через сутки после входа, и
// так дважды подряд. Причина: Entra выдаёт новый refresh-токен при каждом
// обновлении и через сутки гасит прежний, а Calenfi продолжал ходить со
// стартовым. Контракт: новый токен принимается и сохраняется в keyring.

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/google/google_token.dart';
import 'package:calenfi/data/providers/calendar/graph/graph_token.dart';
import 'package:calenfi/data/secure/secret_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend extends KeyringBackend {
  String? blob;

  @override
  Future<String?> read() async => blob;

  @override
  Future<void> write(String value) async => blob = value;
}

class _TokenAdapter implements HttpClientAdapter {
  _TokenAdapter(this.body);
  final Map<String, dynamic> body;
  var calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _stored(_FakeBackend backend, String key) =>
    (jsonDecode(jsonDecode(backend.blob!)[key] as String) as Map)
        .cast<String, dynamic>();

void main() {
  late _FakeBackend backend;

  setUp(() async {
    backend = _FakeBackend();
    SecretStore.backend = backend;
    SecretStore.fallbackBackend = _FakeBackend();
    await SecretStore.instance.warmUp(force: true);
  });

  test('O365: новый refresh-токен сохраняется в keyring', () async {
    final token = GraphToken(
      clientId: 'client',
      tenant: 'tenant',
      refreshToken: 'старый',
      email: 'ikarpov@click2.money',
    );
    final dio = Dio()
      ..httpClientAdapter = _TokenAdapter({
        'access_token': 'a1',
        'refresh_token': 'новый',
        'expires_in': 3600,
      });

    expect(await token.accessTokenValid(dio), 'a1');
    expect(token.refreshToken, 'новый');

    final key = GraphToken.secretKey('ikarpov@click2.money');
    expect(SecretStore.instance.value(key), isNotNull);
    expect(_stored(backend, key)['refresh_token'], 'новый');
    // Перечитанный токен уже новый — следующий запуск не возьмёт погашенный.
    expect(GraphToken.loadFor('ikarpov@click2.money')!.refreshToken, 'новый');
  });

  test('без нового токена в ответе keyring не трогаем', () async {
    final token = GraphToken(
      clientId: 'client',
      tenant: 'tenant',
      refreshToken: 'старый',
      email: 'ikarpov@click2.money',
    );
    final dio = Dio()
      ..httpClientAdapter =
          _TokenAdapter({'access_token': 'a1', 'expires_in': 3600});

    await token.accessTokenValid(dio);

    expect(token.refreshToken, 'старый');
    // Записи токена в хранилище не появилось (warmUp кладёт туда только
    // служебную метку, самого ключа быть не должно).
    expect(
      SecretStore.instance.value(GraphToken.secretKey('ikarpov@click2.money')),
      isNull,
    );
  });

  test('Google: ротация тоже сохраняется', () async {
    final token = GoogleToken(
      clientId: 'client',
      clientSecret: 'secret',
      refreshToken: 'старый',
      tokenUri: 'https://oauth2.googleapis.com/token',
      email: 'karpovilia@gmail.com',
    );
    final dio = Dio()
      ..httpClientAdapter = _TokenAdapter({
        'access_token': 'a1',
        'refresh_token': 'новый',
        'expires_in': 3600,
      });

    await token.accessTokenValid(dio);

    final key = GoogleToken.secretKey('karpovilia@gmail.com');
    expect(_stored(backend, key)['refresh_token'], 'новый');
  });
}
