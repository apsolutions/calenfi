// Жалоба: «скачанный с GitHub APK не даёт зарегистрировать новую учётную запись:
// написано, что авторизация через браузер, но ничего не происходит». Экран
// показывал «завершите вход в открывшемся браузере…», хотя OAuth-клиента не было
// и браузер не открывался, а ошибка стояла в очереди за этой подсказкой.

import 'dart:async';
import 'dart:io';

import 'package:calenfi/data/secure/build_credentials.dart';
import 'package:calenfi/data/secure/credential_source.dart';
import 'package:calenfi/data/secure/data_dir.dart';
import 'package:calenfi/data/secure/secret_store.dart';
import 'package:calenfi/features/accounts/add_account_sheet.dart';
import 'package:calenfi/features/accounts/connect_account.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late List<Uri> launched;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('calenfi-add-account-');
    calenfiDataDir = tmp.path;
    SecretStore.backend = _MemoryBackend();
    SecretStore.fallbackBackend = _MemoryBackend();
    CredentialSource.buildDefaults = const {};
    launched = [];
  });

  tearDown(() {
    CredentialSource.buildDefaults = BuildCredentials.values;
    calenfiDataDir = null;
    tmp.deleteSync(recursive: true);
  });

  Future<void> pumpScreen(
      WidgetTester tester, Future<bool> Function(Uri url) launcher) async {
    await tester.runAsync(() => SecretStore.instance.warmUp(force: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        connectAccountServiceProvider.overrideWith(
            (ref) => ConnectAccountService(ref, launcher: launcher)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: AddAccountScreen(),
      ),
    ));
  }

  /// Даёт настоящему вводу-выводу (loopback-сервер OAuth) продвинуться.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
  }

  /// Хватает на анимацию смены снекбара, но намного меньше 10 секунд подсказки.
  Future<void> snackBarSwap(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
  }

  final hint = find.textContaining('complete sign-in in the browser');

  testWidgets('без OAuth-клиента сразу объясняет причину и не ждёт браузер',
      (tester) async {
    await pumpScreen(tester, (url) async {
      launched.add(url);
      return true;
    });

    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    expect(find.text('Google sign-in is not set up'), findsOneWidget);
    expect(hint, findsNothing);
    expect(launched, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(hint, findsNothing);
    expect(launched, isEmpty);
    expect(SecretStore.instance.value('GOOGLE_OAUTH_CLIENT_ID'), isNull);
  });

  testWidgets(
      'введённый клиент сохраняется, вход стартует, ошибка браузера видна сразу',
      (tester) async {
    await pumpScreen(tester, (url) async {
      launched.add(url);
      return false; // браузер не открылся
    });

    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save and sign in');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('oauth-client-id')),
        ' mine.apps.googleusercontent.com ');
    await tester.enterText(
        find.byKey(const ValueKey('oauth-client-secret')), 'mine-secret');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.tap(save);
    await settle(tester);

    expect(SecretStore.instance.value('GOOGLE_OAUTH_CLIENT_ID'),
        'mine.apps.googleusercontent.com');
    expect(SecretStore.instance.value('GOOGLE_OAUTH_CLIENT_SECRET'),
        'mine-secret');
    expect(launched, hasLength(1));
    final url = launched.single;
    expect(url.host, 'accounts.google.com');
    expect(url.queryParameters['client_id'], 'mine.apps.googleusercontent.com');
    expect(url.queryParameters['redirect_uri'], startsWith('http://localhost:'));
    expect(url.queryParameters['code_challenge_method'], 'S256');

    await snackBarSwap(tester);
    expect(find.textContaining('не удалось открыть браузер'), findsOneWidget);
    expect(hint, findsNothing);
    expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Google')).enabled,
        isTrue);
  });

  testWidgets(
      'клиент из сборки: браузер открывается без вопросов, второй вход не стартует',
      (tester) async {
    CredentialSource.buildDefaults = const {'GRAPH_CLIENT_ID': 'built-graph'};
    final browser = Completer<bool>();
    await pumpScreen(tester, (url) {
      launched.add(url);
      return browser.future;
    });

    await tester.tap(find.text('Microsoft 365 / Outlook'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(hint, findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(launched, hasLength(1));
    expect(launched.single.host, 'login.microsoftonline.com');
    expect(launched.single.path, startsWith('/common/'));
    expect(launched.single.queryParameters['client_id'], 'built-graph');

    // Пока ждём браузер, повторные нажатия не поднимают второй вход и диалог.
    await tester.tap(find.text('Microsoft 365 / Outlook'));
    await tester.tap(find.text('Google'));
    await settle(tester);
    expect(launched, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);

    browser.complete(false);
    await settle(tester);
    await snackBarSwap(tester);
    expect(find.textContaining('не удалось открыть браузер'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Telemost без клиента тоже спрашивает клиент, а не молчит',
      (tester) async {
    await pumpScreen(tester, (url) async {
      launched.add(url);
      return true;
    });

    await tester.scrollUntilVisible(find.text('Yandex Telemost'), 100);
    await tester.tap(find.text('Yandex Telemost'));
    await tester.pumpAndSettle();

    expect(find.text('Telemost sign-in is not set up'), findsOneWidget);
    expect(find.byKey(const ValueKey('oauth-client-secret')), findsOneWidget);
    expect(launched, isEmpty);
  });
}
