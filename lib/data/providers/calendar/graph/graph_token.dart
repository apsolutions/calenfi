import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../secure/secret_store.dart';
import '../token_exception.dart';

/// OAuth-токен Microsoft Graph (public client, device code flow), созданный
/// `tools/graph_calendar_auth.py`. Calenfi переиспользует refresh-токен.
///
/// Хранится в системном keyring под ключом `token:graph_<EMAIL>`
/// (см. [SecretStore]); старые файлы `.tokens/graph_*.json` импортируются
/// автоматически при первом запуске.
class GraphToken {
  GraphToken({
    required this.clientId,
    required this.tenant,
    required this.refreshToken,
    this.email,
    this.accessToken,
    this.expiry,
  });

  final String clientId;
  final String tenant;

  /// Refresh-токен. Не final: Entra выдаёт новый при каждом обновлении и
  /// через сутки гасит прежний, поэтому ротацию надо принимать и сохранять.
  String refreshToken;

  /// Ящик, под ключом которого токен лежит в keyring. null — токен собран в
  /// тесте или вручную, сохранять ротацию некуда.
  final String? email;
  String? accessToken;
  DateTime? expiry;

  static String _key(String email) =>
      email.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');

  /// Ключ секрета в keyring для данного адреса.
  static String secretKey(String email) =>
      SecretStore.tokenKey('graph_${_key(email)}');

  static GraphToken? loadFor(String email) {
    final raw = SecretStore.instance.value(secretKey(email));
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    if (m['refresh_token'] == null) return null;
    return GraphToken(
      clientId: m['client_id'] as String,
      tenant: (m['tenant'] as String?) ?? 'organizations',
      refreshToken: m['refresh_token'] as String,
      email: email,
      accessToken: m['access_token'] as String?,
    );
  }

  /// Сохраняет новый refresh-токен, выданный вместе с access-токеном.
  ///
  /// Без этого Calenfi ходил со стартовым токеном вечно: Entra держит прежний
  /// ещё сутки после ротации, а потом отвечает `invalid_grant`, и аккаунт
  /// «сам собой» отваливался примерно через день после входа.
  Future<void> _keepRotatedRefreshToken(Object? fresh) async {
    if (fresh is! String || fresh.isEmpty || fresh == refreshToken) return;
    refreshToken = fresh;
    final key = email;
    if (key == null) return;
    await SecretStore.instance.write(
      secretKey(key),
      jsonEncode({
        'client_id': clientId,
        'tenant': tenant,
        'access_token': accessToken,
        'refresh_token': refreshToken,
      }),
    );
  }

  bool get _expired =>
      accessToken == null ||
      expiry == null ||
      DateTime.now().isAfter(expiry!.subtract(const Duration(seconds: 60)));

  Future<String> accessTokenValid(Dio dio) async {
    if (!_expired) return accessToken!;
    final resp = await dio.post(
      'https://login.microsoftonline.com/$tenant/oauth2/v2.0/token',
      data: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope':
            'https://graph.microsoft.com/Calendars.ReadWrite https://graph.microsoft.com/OnlineMeetings.ReadWrite offline_access',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = resp.data as Map<String, dynamic>;
    final at = data['access_token'];
    if (at is! String) {
      throw TokenExpiredException(
          'O365: ${data['error'] ?? 'refresh failed'} — переподключи аккаунт');
    }
    accessToken = at;
    final ttl = (data['expires_in'] as num?)?.toInt() ?? 3600;
    expiry = DateTime.now().add(Duration(seconds: ttl));
    await _keepRotatedRefreshToken(data['refresh_token']);
    return accessToken!;
  }
}
