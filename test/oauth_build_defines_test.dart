// Жалобы: (1) APK с GitHub не подключал Google/Microsoft, потому что релиз
// собирался без OAuth-клиентов; (2) раньше в сборку чуть не уехали личные
// токены. Здесь проверяется, что релиз собирается с клиентами из окружения, не
// публикуется без них и не тянет в сборку ничего, кроме идентификаторов
// OAuth-приложений.

import 'dart:io';

import 'package:calenfi/data/secure/build_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

const _script = 'tools/oauth_dart_defines.sh';

Future<ProcessResult> _runDefines(Map<String, String> env,
        {bool require = false}) =>
    Process.run(
      'bash',
      [_script, if (require) '--require'],
      environment: {
        'PATH': Platform.environment['PATH'] ?? '/usr/bin:/bin',
        ...env,
      },
      includeParentEnvironment: false,
    );

void main() {
  final noBash = Platform.isWindows ? 'скрипт сборки проверяется на bash' : null;

  test('скрипт и приложение знают один и тот же список ключей', () {
    final source = File(_script).readAsStringSync();
    final match = RegExp(r'^keys=\((.*)\)$', multiLine: true).firstMatch(source);
    expect(match, isNotNull);
    expect(match!.group(1)!.trim().split(RegExp(r'\s+')), BuildCredentials.keys);
  });

  test('печатает --dart-define только для заданных OAuth-клиентов', () async {
    final res = await _runDefines({
      'GOOGLE_OAUTH_CLIENT_ID': 'g.apps.googleusercontent.com',
      'GOOGLE_OAUTH_CLIENT_SECRET': 'g-secret',
      'GRAPH_CLIENT_ID': 'graph-id',
      'ZOOM_CLIENT_SECRET': 'zoom-secret',
      'ME_EXAMPLE_COM_CALDAV_PASSWORD': 'password',
    });

    expect(res.exitCode, 0, reason: '${res.stderr}');
    expect((res.stdout as String).trim().split('\n'), [
      '--dart-define=GOOGLE_OAUTH_CLIENT_ID=g.apps.googleusercontent.com',
      '--dart-define=GOOGLE_OAUTH_CLIENT_SECRET=g-secret',
      '--dart-define=GRAPH_CLIENT_ID=graph-id',
    ]);
  }, skip: noBash);

  test('--require не даёт собрать релиз без клиентов Google и Microsoft',
      () async {
    final missing = await _runDefines(
        {'GOOGLE_OAUTH_CLIENT_ID': 'g.apps.googleusercontent.com'},
        require: true);
    expect(missing.exitCode, isNot(0));
    expect(missing.stderr, contains('GOOGLE_OAUTH_CLIENT_SECRET'));
    expect(missing.stderr, contains('GRAPH_CLIENT_ID'));

    final ok = await _runDefines({
      'GOOGLE_OAUTH_CLIENT_ID': 'g.apps.googleusercontent.com',
      'GOOGLE_OAUTH_CLIENT_SECRET': 'g-secret',
      'GRAPH_CLIENT_ID': 'graph-id',
    }, require: true);
    expect(ok.exitCode, 0, reason: '${ok.stderr}');
  }, skip: noBash);

  group('release.yml', () {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();

    test('каждая платформа собирается с зашитыми OAuth-клиентами', () {
      final builds = workflow
          .split('\n')
          .where((l) =>
              l.contains('flutter build ') && !l.trimLeft().startsWith('#'))
          .toList();
      expect(builds, hasLength(4));
      for (final line in builds) {
        expect(line, contains(r'"${defines[@]}"'), reason: line.trim());
      }
    });

    test('OAuth-клиенты приходят из секретов репозитория', () {
      for (final key in BuildCredentials.keys) {
        expect(workflow, contains('$key: \${{ secrets.$key }}'));
      }
    });

    test('релиз падает до сборок, если клиенты не заданы', () {
      final identity = workflow.substring(
          workflow.indexOf('  identity:'), workflow.indexOf('  linux:'));
      expect(identity, contains('oauth_dart_defines.sh --require'));
    });

    test('APK проверяется на зашитые клиенты', () {
      final android = workflow.substring(workflow.indexOf('  android:'));
      expect(android, contains('libapp.so'));
      expect(android, contains(r'grep -aFq "$GOOGLE_OAUTH_CLIENT_ID"'));
      expect(android, contains(r'grep -aFq "$GRAPH_CLIENT_ID"'));
    });
  });

  test('секреты и токены пользователя не попадают в сборку и в git', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(matches(RegExp(r'secrets|\.tokens|\.env|client_secret'))));

    final gitignore = File('.gitignore').readAsStringSync().split('\n');
    for (final entry in [
      'secrets.env',
      'secrets.json',
      '.tokens/',
      'client_secret*.json',
    ]) {
      expect(gitignore, contains(entry));
    }
  });
}
