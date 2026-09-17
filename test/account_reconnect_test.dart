// Жалоба: «я не хочу заново добавлять УЗ, я хочу её обновить». У записи с
// отозванным провайдером токеном (`invalid_grant`) в меню были только «Сменить
// пароль» и «Удалить», а повторный вход шёл через «Добавить учётную запись» —
// то есть выглядел как заведение второй записи.

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/features/accounts/accounts_screen.dart';
import 'package:calenfi/features/accounts/connect_account.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnect extends ConnectAccountService {
  _FakeConnect(super.ref);

  Account? asked;

  @override
  Future<String> reconnect(Account acc) async {
    asked = acc;
    return acc.email;
  }
}

void main() {
  const graph = Account(
    id: 'acc-o365',
    provider: ProviderType.graph,
    displayName: 'Office 365',
    email: 'ikarpov@click2.money',
    status: AccountStatus.needsReconnect,
    lastError: 'O365: invalid_grant — переподключи аккаунт',
  );
  const ews = Account(
    id: 'acc-hse',
    provider: ProviderType.ews,
    displayName: 'HSE Exchange',
    email: 'iakarpov@hse.ru',
  );

  Future<void> pump(
    WidgetTester tester,
    List<Account> accounts,
    void Function(_FakeConnect) onCreate,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountsStreamProvider
            .overrideWith((ref) => Stream<List<Account>>.value(accounts)),
        calendarsStreamProvider
            .overrideWith((ref) => Stream<List<Calendar>>.value(const [])),
        connectAccountServiceProvider.overrideWith((ref) {
          final fake = _FakeConnect(ref);
          onCreate(fake);
          return fake;
        }),
      ],
      child: const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: AccountsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('меню OAuth-записи переподключает ЭТУ запись', (tester) async {
    _FakeConnect? fake;
    await pump(tester, [graph], (f) => fake = f);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переподключить'));
    await tester.pumpAndSettle();

    expect(fake?.asked?.id, 'acc-o365');
    expect(fake?.asked?.email, 'ikarpov@click2.money');
  });

  testWidgets('кнопка переподключения стоит прямо на ошибке', (tester) async {
    _FakeConnect? fake;
    await pump(tester, [graph], (f) => fake = f);

    await tester.tap(find.text('Office 365'));
    await tester.pumpAndSettle();
    expect(find.textContaining('invalid_grant'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Переподключить'));
    await tester.pumpAndSettle();

    expect(fake?.asked?.id, 'acc-o365');
  });

  testWidgets('у парольной записи переподключения нет', (tester) async {
    await pump(tester, [ews], (_) {});

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Переподключить'), findsNothing);
    expect(find.text('Изменить пароль'), findsOneWidget);
  });
}
