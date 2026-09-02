import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release manifest grants Internet access', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);

    final source = manifest.readAsStringSync();
    expect(
      source,
      contains('android:name="android.permission.INTERNET"'),
      reason:
          'INTERNET must live in src/main; debug/profile permissions are not '
          'included in GitHub release APKs.',
    );
  });
}
