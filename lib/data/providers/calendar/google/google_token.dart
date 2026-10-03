import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../services/diag_log.dart';
import '../../../secure/secret_store.dart';
import '../token_exception.dart';

/// OAuth-токен Google (формат google.oauth2 Credentials.to_json()),
/// созданный `tools/google_calendar_auth.py`. Calenfi переиспользует его
/// refresh-токен.
///
/// Хранится в системном keyring под ключом `token:gcal_<EMAIL>`
/// (см. [SecretStore]); старые файлы `.tokens/gcal_*.json` импортируются
/// автоматически при первом запуске.
class GoogleToken {
  GoogleToken({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.tokenUri,
    this.email,
    this.accessToken,
    this.expiry,
    this.storeKey,
    this.scopes = const [],
  });

  /// Ключ в хранилище секретов, куда писать обновлённый токен. null — ключ
  /// токена календаря для [email].
  final String? storeKey;

  /// Области доступа, выданные при входе (если записаны в токене).
  final List<String> scopes;

  /// Область доступа Google Tasks: через неё синхронизируются заметки.
  static const tasksScope = 'https://www.googleapis.com/auth/tasks';

  /// Ключ токена с доступом к Google Tasks (формат приложения tt).
  static String tasksSecretKey(String email) =>
      SecretStore.tokenKey('gtasks_${_key(email)}');

  /// Токен с доступом к Google Tasks для [email]: отдельный токен задач, а
  /// если его нет — токен календаря, если при входе выдали и задачи.
  static GoogleToken? loadForTasks(String email) {
    for (final key in [tasksSecretKey(email), secretKey(email)]) {
      final raw = SecretStore.instance.value(key);
      if (raw == null) continue;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final scopes = [
        for (final s in (m['scopes'] as List? ?? const [])) s.toString(),
      ];
      if (m['refresh_token'] == null || !scopes.contains(tasksScope)) continue;
      return GoogleToken(
        clientId: m['client_id'] as String,
        clientSecret: m['client_secret'] as String,
        refreshToken: m['refresh_token'] as String,
        tokenUri: (m['token_uri'] as String?) ??
            'https://oauth2.googleapis.com/token',
        email: email,
        storeKey: key,
        scopes: scopes,
      );
    }
    return null;
  }

  final String clientId;
  final String clientSecret;

  /// Не final: провайдер вправе выдать новый refresh-токен при обновлении,
  /// и тогда прежний перестаёт работать (у Google это редкость, у Entra —
  /// каждый раз, см. GraphToken).
  String refreshToken;
  final String tokenUri;

  /// Ящик, под ключом которого токен лежит в keyring; null — сохранять некуда.
  final String? email;
  String? accessToken;
  DateTime? expiry;

  static String _key(String email) =>
      email.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');

  /// Ключ секрета в keyring для данного адреса.
  static String secretKey(String email) =>
      SecretStore.tokenKey('gcal_${_key(email)}');

  /// Грузит токен календаря для email, либо null если его нет в keyring.
  static GoogleToken? loadFor(String email) {
    final raw = SecretStore.instance.value(secretKey(email));
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    if (m['refresh_token'] == null) return null;
    return GoogleToken(
      clientId: m['client_id'] as String,
      clientSecret: m['client_secret'] as String,
      refreshToken: m['refresh_token'] as String,
      tokenUri: (m['token_uri'] as String?) ?? 'https://oauth2.googleapis.com/token',
      email: email,
      accessToken: m['token'] as String?,
      scopes: [
        for (final s in (m['scopes'] as List? ?? const [])) s.toString(),
      ],
    );
  }

  bool get _expired =>
      accessToken == null ||
      expiry == null ||
      DateTime.now().isAfter(expiry!.subtract(const Duration(seconds: 60)));

  /// Возвращает действующий access-токен, обновляя по refresh при необходимости.
  Future<String> accessTokenValid(Dio dio) async {
    if (!_expired) return accessToken!;
    final resp = await dio.post(
      tokenUri,
      data: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final data = resp.data as Map<String, dynamic>;
    final at = data['access_token'];
    if (at is! String) {
      // refresh не удался: invalid_grant (протух/отозван) и т.п.
      DiagLog.instance.add(
          'token',
          'Google ${email ?? ''}: обновление токена отклонено, HTTP '
              '${resp.statusCode}, ${data['error']}: '
              '${data['error_description']}');
      throw TokenExpiredException(
          'Google: ${data['error'] ?? 'refresh failed'} — переподключи аккаунт');
    }
    accessToken = at;
    final ttl = (data['expires_in'] as num?)?.toInt() ?? 3600;
    expiry = DateTime.now().add(Duration(seconds: ttl));
    await _keepRotatedRefreshToken(data['refresh_token']);
    return accessToken!;
  }

  /// Принимает и сохраняет новый refresh-токен, если он пришёл в ответе.
  Future<void> _keepRotatedRefreshToken(Object? fresh) async {
    if (fresh is! String || fresh.isEmpty || fresh == refreshToken) return;
    refreshToken = fresh;
    final key = storeKey ?? (email == null ? null : secretKey(email!));
    if (key == null) return;
    await SecretStore.instance.write(
      key,
      jsonEncode({
        'token': accessToken,
        'refresh_token': refreshToken,
        'token_uri': tokenUri,
        'client_id': clientId,
        'client_secret': clientSecret,
        if (scopes.isNotEmpty) 'scopes': scopes,
      }),
    );
  }
}
