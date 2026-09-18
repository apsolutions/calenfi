// Жалоба: «Готово! Вернитесь в Calenfi», а Office 365 так и остаётся с
// invalid_grant. После входа адрес ящика брался из Graph `/me`, а тот требует
// User.Read, которого Calenfi не запрашивает: 403, и токен не записывался.
// Адрес есть в id_token — его и берём.

import 'dart:convert';

import 'package:calenfi/features/accounts/connect_account.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, Object?> claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  test('адрес из claim email', () {
    expect(
      ConnectAccountService.graphEmailFromIdToken(_jwt({
        'email': 'ikarpov@click2.money',
        'preferred_username': 'other@click2.money',
      })),
      'ikarpov@click2.money',
    );
  });

  test('без email берётся preferred_username', () {
    expect(
      ConnectAccountService.graphEmailFromIdToken(
          _jwt({'preferred_username': 'ikarpov@click2.money'})),
      'ikarpov@click2.money',
    );
  });

  test('нет токена или адреса — null, дальше запасной путь через /me', () {
    expect(ConnectAccountService.graphEmailFromIdToken(null), isNull);
    expect(ConnectAccountService.graphEmailFromIdToken('мусор'), isNull);
    expect(ConnectAccountService.graphEmailFromIdToken('a.!!!.c'), isNull);
    expect(
      ConnectAccountService.graphEmailFromIdToken(_jwt({'name': 'Илья'})),
      isNull,
    );
  });
}
