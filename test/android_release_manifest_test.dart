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

  test('Android release manifest can see a browser for OAuth sign-in', () {
    final source =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final queries = RegExp(r'<queries>([\s\S]*?)</queries>')
        .firstMatch(source)
        ?.group(1);

    expect(queries, isNotNull);
    expect(queries, contains('android.intent.action.VIEW'));
    expect(queries, contains('android:scheme="https"'),
        reason: 'Since Android 11 the sign-in page may not find a browser '
            'without a package-visibility query for https links.');
  });
}
