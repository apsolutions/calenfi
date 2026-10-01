import 'dart:io';

import 'package:calenfi/app/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('версия в журнале и настройках совпадает с pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)![1];
    expect(kAppVersion, version);
  });
}
