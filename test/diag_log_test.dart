// Жалоба: «вот бы были более подробные логи ошибки». Журнал диагностики
// хранит полный текст сбоев и при этом не должен выдавать секреты.

import 'dart:io';

import 'package:calenfi/data/secure/oauth_flow.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final log = DiagLog.instance;

  setUp(() {
    log.echo = false;
    log.clear();
  });

  group('секреты в журнал не попадают', () {
    test('параметры запроса с кодом и токенами', () {
      final s = DiagLog.scrub(
          'GET http://localhost:4567/?code=0.AXkA-secret-code&state=abc '
          'refresh_token=1//0gSecretRefresh&client_secret=S3cretValue-abcdef');
      expect(s, isNot(contains('0.AXkA-secret-code')));
      expect(s, isNot(contains('1//0gSecretRefresh')));
      expect(s, isNot(contains('S3cretValue-abcdef')));
      expect(s, contains('code=<скрыто>'));
    });

    test('поля JSON, JWT и заголовок авторизации', () {
      final s = DiagLog.scrub(
          '{"access_token": "tok.a0AfSecret", "id_token":"x"} '
          'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJl '
          'Authorization: Bearer abcdef0123456789');
      expect(s, isNot(contains('tok.a0AfSecret')));
      expect(s, isNot(contains('eyJhbGciOiJSUzI1NiJ9')));
      expect(s, isNot(contains('abcdef0123456789')));
    });

    test('длинная непрозрачная строка скрыта, путь к файлу — нет', () {
      final opaque = 'A1b2' * 16;
      final s = DiagLog.scrub('ответ: $opaque, кадр: '
          'package:calenfi/data/providers/calendar/graph/graph_provider.dart:154');
      expect(s, isNot(contains(opaque)));
      expect(s, contains('graph_provider.dart:154'));
    });

    test('обычный текст ошибки остаётся читаемым', () {
      const text = 'HTTP 400, invalid_grant: AADSTS70008: The refresh token '
          'has expired due to inactivity. Error code: 500';
      expect(DiagLog.scrub(text), text);
    });
  });

  test('ошибка пишется с типом, текстом и началом стека', () {
    try {
      throw const SocketException('Failed host lookup: graph.microsoft.com');
    } on Object catch (e, st) {
      log.error('sync', 'acc-o365: статус offline', e, st);
    }
    final entry = log.lines.single;
    expect(entry, contains('[sync] acc-o365: статус offline'));
    expect(entry, contains('SocketException'));
    expect(entry, contains('Failed host lookup: graph.microsoft.com'));
    expect(entry, contains('diag_log_test.dart'), reason: 'есть кадр стека');
  });

  test('в памяти остаются только последние строки', () {
    for (var i = 0; i < DiagLog.maxLines + 25; i++) {
      log.add('t', 'строка $i');
    }
    expect(log.lines, hasLength(DiagLog.maxLines));
    expect(log.lines.first, contains('строка 25'));
    expect(log.lines.last, contains('строка ${DiagLog.maxLines + 24}'));
  });

  test('журнал переживает перезапуск и не растёт без конца', () {
    final dir = Directory.systemTemp.createTempSync('calenfi-diag');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/calenfi.log';

    log.attachFile(path);
    log.add('app', 'первая запись');
    expect(File(path).readAsStringSync(), contains('первая запись'));

    // Новый запуск: строки прошлого запуска видны на экране журнала.
    log.clear();
    File(path).writeAsStringSync('2026-10-01 03:00:00.000 [app] из прошлого запуска\n');
    log.attachFile(path);
    expect(log.lines.single, contains('из прошлого запуска'));

    // Переполненный файл уезжает в .1, новый начинается с нуля.
    File(path).writeAsStringSync('x' * (DiagLog.maxFileBytes + 1));
    log.attachFile(path);
    log.add('app', 'после ротации');
    expect(File('$path.1').existsSync(), isTrue);
    expect(File(path).lengthSync(), lessThan(1024));
    log.attachFile('${dir.path}/unused.log');
  });

  group('страница после входа', () {
    test('на телефоне есть кнопка возврата в приложение', () {
      final page = OAuthFlow.resultPage('Готово!',
          returnUrl: 'ru.apsolutions.calenfi://login-done');
      expect(page, contains('href="ru.apsolutions.calenfi://login-done"'));
      expect(page, contains('Вернуться в Calenfi'));
    });

    test('на десктопе кнопки нет', () {
      final page = OAuthFlow.resultPage('Готово!');
      expect(page, isNot(contains('Вернуться в Calenfi')));
      expect(page, isNot(contains('<script>')));
    });
  });
}
