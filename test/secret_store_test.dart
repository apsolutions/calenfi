import 'dart:convert';

import 'package:calenfi/data/secure/credential_source.dart';
import 'package:calenfi/data/secure/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Бэкенд в памяти: имитирует системный keyring без обращения к ОС.
class _FakeBackend extends KeyringBackend {
  _FakeBackend({this.broken = false, this.writeFails = false});

  /// «Сломанный» keyring: запись проходит, но прочитать нечего — так ведёт себя
  /// демон, который не умеет искать по атрибутам (например KeePassXC).
  final bool broken;
  final bool writeFails;
  String? blob;

  @override
  Future<String?> read() async => broken ? null : blob;

  @override
  Future<void> write(String value) async {
    if (writeFails) throw StateError('read-only backend');
    blob = value;
  }
}

void main() {
  group('SecretStore', () {
    // Фолбэк тоже в памяти: тесты не должны читать/писать реальный
    // ~/.config/calenfi/secrets.json пользователя.
    late _FakeBackend fallback;
    setUp(() {
      fallback = _FakeBackend();
      SecretStore.fallbackBackend = fallback;
    });

    test('читает секреты из бэкенда в синхронный кеш', () async {
      final b = _FakeBackend()
        ..blob = jsonEncode({'ME_EXAMPLE_COM_CALDAV_PASSWORD': 'p@ss'});
      SecretStore.backend = b;
      await SecretStore.instance.warmUp(force: true);

      expect(
        SecretStore.instance.value('ME_EXAMPLE_COM_CALDAV_PASSWORD'),
        'p@ss',
      );
      expect(CredentialSource.load().caldavPassword('me@example.com'), 'p@ss');
    });

    test(
      'неполный keyring дополняется fallback без перезаписи конфликтов',
      () async {
        fallback.blob = jsonEncode({
          'ME_EXAMPLE_COM_EWS_URL':
              'https://mail.example.com/EWS/Exchange.asmx',
          'SHARED': 'fallback',
        });
        final b = _FakeBackend()
          ..blob = jsonEncode({
            'ME_EXAMPLE_COM_EWS_PASSWORD': 'password',
            'SHARED': 'keyring',
          });
        SecretStore.backend = b;

        await SecretStore.instance.warmUp(force: true);

        expect(
          SecretStore.instance.value('ME_EXAMPLE_COM_EWS_URL'),
          'https://mail.example.com/EWS/Exchange.asmx',
        );
        expect(
          SecretStore.instance.value('ME_EXAMPLE_COM_EWS_PASSWORD'),
          'password',
        );
        expect(SecretStore.instance.value('SHARED'), 'keyring');
        expect(
          jsonDecode(b.blob!)['ME_EXAMPLE_COM_EWS_URL'],
          'https://mail.example.com/EWS/Exchange.asmx',
        );
        expect(SecretStore.instance.usesKeyring, isTrue);
      },
    );

    test('удалённый секрет не воскресает из fallback', () async {
      fallback.blob = jsonEncode({'OLD_TOKEN': 'fallback value'});
      final b = _FakeBackend()
        ..blob = jsonEncode({'OLD_TOKEN': 'keyring value'});
      SecretStore.backend = b;
      await SecretStore.instance.warmUp(force: true);

      await SecretStore.instance.delete('OLD_TOKEN');
      await SecretStore.instance.warmUp(force: true);

      expect(SecretStore.instance.value('OLD_TOKEN'), isNull);
      expect(jsonDecode(b.blob!)['OLD_TOKEN'], isNull);
      final fallbackJson = jsonDecode(fallback.blob!) as Map<String, dynamic>;
      expect(fallbackJson['OLD_TOKEN'], isNull);
      expect(fallbackJson['_calenfi_deleted_keys_v1'], contains('OLD_TOKEN'));
    });

    test(
      'keyring-only secrets are never mirrored to plaintext fallback',
      () async {
        fallback.blob = jsonEncode({'FALLBACK_ONLY': 'old'});
        final b = _FakeBackend()
          ..blob = jsonEncode({
            '_calenfi_fallback_imported_v1': true,
            'KEYRING_ONLY': 'secret',
          });
        SecretStore.backend = b;
        await SecretStore.instance.warmUp(force: true);

        await SecretStore.instance.write('NEW_KEYRING_ONLY', 'new secret');

        final fallbackJson = jsonDecode(fallback.blob!) as Map<String, dynamic>;
        expect(fallbackJson['KEYRING_ONLY'], isNull);
        expect(fallbackJson['NEW_KEYRING_ONLY'], isNull);
        expect(fallbackJson['FALLBACK_ONLY'], 'old');
      },
    );

    test(
      'self-heal write failure does not discard the restored cache',
      () async {
        fallback.blob = jsonEncode({
          'EWS_URL': 'https://mail.example.test/EWS',
        });
        final b = _FakeBackend(writeFails: true)
          ..blob = jsonEncode({'EWS_PASSWORD': 'password'});
        SecretStore.backend = b;

        await SecretStore.instance.warmUp(force: true);

        expect(SecretStore.instance.isLoaded, isTrue);
        expect(SecretStore.instance.usesKeyring, isTrue);
        expect(SecretStore.instance.value('EWS_PASSWORD'), 'password');
        expect(
          SecretStore.instance.value('EWS_URL'),
          'https://mail.example.test/EWS',
        );
      },
    );

    test('write пишет и в кеш, и в бэкенд', () async {
      final b = _FakeBackend()..blob = '{}';
      SecretStore.backend = b;
      await SecretStore.instance.warmUp(force: true);

      await SecretStore.instance.write('ZOOM_CLIENT_ID', 'abc');
      expect(SecretStore.instance.value('ZOOM_CLIENT_ID'), 'abc');
      expect(jsonDecode(b.blob!)['ZOOM_CLIENT_ID'], 'abc');
    });

    test('пустое значение читается как null', () async {
      SecretStore.backend = _FakeBackend()..blob = jsonEncode({'K': ''});
      await SecretStore.instance.warmUp(force: true);
      expect(SecretStore.instance.value('K'), isNull);
    });

    test('битый JSON не роняет старт', () async {
      SecretStore.backend = _FakeBackend()..blob = 'not json';
      await SecretStore.instance.warmUp(force: true);
      expect(SecretStore.instance.all, isEmpty);
    });

    test('валидный JSON не-object не роняет старт', () async {
      fallback.blob = '[]';
      SecretStore.backend = _FakeBackend()
        ..blob = jsonEncode({'KEYRING_VALUE': 'ok'});

      await SecretStore.instance.warmUp(force: true);

      expect(SecretStore.instance.value('KEYRING_VALUE'), 'ok');
    });

    test('нерабочий keyring → переключение на файловый фолбэк', () async {
      SecretStore.backend = _FakeBackend(broken: true);
      await SecretStore.instance.warmUp(force: true);
      expect(SecretStore.instance.usesKeyring, isFalse);
    });

    test('ключи токенов совпадают с именами legacy-файлов', () {
      expect(
        SecretStore.tokenKey('gcal_ME_GMAIL_COM'),
        'token:gcal_ME_GMAIL_COM',
      );
    });
  });
}
