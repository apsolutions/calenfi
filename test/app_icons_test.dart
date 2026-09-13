// Жалоба: «на винде старая убогая иконка» — Windows-сборка выходила со
// стандартной иконкой шаблона Flutter.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows-сборка не использует стандартную иконку Flutter', () {
    // SHA-256 app_icon.ico из шаблона Flutter (flutter_template_images 5.0.0).
    const flutterDefault =
        'c098d3fc85cacff98b8e69811b48e9f0d852fcee278132d794411d978869cbf8';
    final ico = File('windows/runner/resources/app_icon.ico');

    expect(ico.existsSync(), isTrue);
    expect(sha256.convert(ico.readAsBytesSync()).toString(),
        isNot(flutterDefault));
  });
}
