import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../services/diag_log.dart';

/// Результат OAuth-обмена: токены + сырой ответ token-endpoint'а.
class OAuthResult {
  OAuthResult(this.accessToken, this.refreshToken, this.expiresIn, this.raw);
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final Map<String, dynamic> raw;
}

class OAuthException implements Exception {
  OAuthException(this.message);
  final String message;
  @override
  String toString() => 'OAuthException: $message';
}

/// Кросс-платформенный OAuth 2.0 **authorization code + PKCE** через loopback:
/// поднимаем локальный HTTP-сервер на `127.0.0.1:<случайный порт>`, открываем
/// системный браузер (колбэк [launch]), ловим редирект с `code`, меняем его на
/// токены. Работает и на десктопе, и на Android/iOS (loopback-редирект). Не
/// требует нативной регистрации схемы — только чтобы `http://localhost` (Google:
/// любой loopback-порт; Microsoft: зарегистрировать `http://localhost` в Azure).
class OAuthFlow {
  OAuthFlow({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  static final _rand = Random.secure();

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static String _randomToken([int bytes = 48]) =>
      _b64url(List<int>.generate(bytes, (_) => _rand.nextInt(256)));

  /// Запускает флоу. [launch] должен открыть переданный URL в браузере
  /// (в приложении — через url_launcher). Возвращает токены; бросает
  /// [OAuthException] при ошибке/отмене/таймауте.
  Future<OAuthResult> run({
    required String authorizationEndpoint,
    required String tokenEndpoint,
    required String clientId,
    String? clientSecret,
    required List<String> scopes,
    Map<String, String> extraAuthParams = const {},
    required Future<void> Function(Uri url) launch,
    Duration timeout = const Duration(minutes: 5),
    int? fixedPort,
    bool basicAuth = false,
    String? returnUrl,
  }) async {
    final host = Uri.parse(authorizationEndpoint).host;
    final verifier = _randomToken();
    final challenge =
        _b64url(sha256.convert(ascii.encode(verifier)).bytes);
    final state = _randomToken(16);

    // Zoom требует ЗАРАНЕЕ зарегистрированный redirect с фикс-портом — тогда
    // [fixedPort] задаёт его. Google/MS/Yandex допускают любой loopback-порт (0).
    final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4, fixedPort ?? 0,
        shared: false);
    try {
      final redirectUri = 'http://localhost:${server.port}';
      final authUri = Uri.parse(authorizationEndpoint).replace(
        queryParameters: {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          // Пусто → не шлём scope (Zoom берёт из настроек OAuth-приложения).
          if (scopes.isNotEmpty) 'scope': scopes.join(' '),
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
          'state': state,
          ...extraAuthParams,
        },
      );

      DiagLog.instance.add('login',
          '$host: жду ответ браузера на 127.0.0.1:${server.port}, открываю страницу входа');
      await launch(authUri);

      final code =
          await _awaitRedirect(server, state, returnUrl: returnUrl).timeout(
        timeout,
        onTimeout: () {
          DiagLog.instance.add('login',
              '$host: за ${timeout.inMinutes} мин браузер так и не вернул ответ');
          throw OAuthException('время ожидания входа истекло');
        },
      );
      DiagLog.instance.add('login', '$host: браузер вернул код, меняю на токены');

      // Обмен кода. Zoom (basicAuth) хочет client_id:secret в заголовке Basic и
      // не в теле; Google/MS — client_secret/PKCE в теле.
      final resp = await _dio.post(
        tokenEndpoint,
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'code_verifier': verifier,
          if (!basicAuth) 'client_id': clientId,
          if (!basicAuth) 'client_secret': ?clientSecret,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (s) => s != null && s < 500,
          headers: basicAuth
              ? {
                  'Authorization':
                      'Basic ${base64Encode(utf8.encode('$clientId:${clientSecret ?? ''}'))}'
                }
              : null,
        ),
      );
      final data = (resp.data is Map)
          ? (resp.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final at = data['access_token'];
      if (at is! String) {
        DiagLog.instance.add(
            'login',
            '$host: обмен кода отклонён, HTTP ${resp.statusCode}, '
                '${data['error']}: ${data['error_description']}');
        throw OAuthException(
            'обмен кода не удался: ${data['error_description'] ?? data['error'] ?? resp.statusCode}');
      }
      return OAuthResult(
        at,
        data['refresh_token'] as String?,
        (data['expires_in'] as num?)?.toInt() ?? 3600,
        data,
      );
    } finally {
      await server.close(force: true);
    }
  }

  /// Ждёт запрос на loopback с параметром `code`, отвечает страницей «можно
  /// закрыть вкладку» и возвращает код. Игнорирует посторонние запросы
  /// (favicon и т.п.).
  Future<String> _awaitRedirect(HttpServer server, String state,
      {String? returnUrl}) async {
    await for (final req in server) {
      final q = req.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        req.response
          ..statusCode = 404
          ..close();
        continue;
      }
      final err = q['error'];
      final code = q['code'];
      final ok = err == null && code != null && q['state'] == state;
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(resultPage(
            ok
                ? 'Готово! Вернитесь в Calenfi — вкладку можно закрыть.'
                : 'Не удалось войти: ${err ?? 'неверный state'}. Вернитесь в Calenfi.',
            returnUrl: returnUrl));
      try {
        await req.response.close();
      } on Object {
        // Вкладку закрыли раньше, чем дошёл ответ: код уже у нас, вход это
        // не отменяет.
      }

      if (err != null) {
        DiagLog.instance.add('login',
            'провайдер вернул ошибку: $err: ${q['error_description'] ?? ''}');
        throw OAuthException('провайдер вернул ошибку: $err');
      }
      if (q['state'] != state) throw OAuthException('несовпадение state (CSRF)');
      if (code == null) throw OAuthException('нет кода авторизации');
      return code;
    }
    throw OAuthException('сервер закрыт до получения кода');
  }

  /// Страница, которую браузер показывает после входа.
  ///
  /// [returnUrl] — ссылка, открывающая само приложение (на телефоне). С ней на
  /// странице есть кнопка «Вернуться в Calenfi», и страница пробует перейти
  /// по ней сама: человеку не нужно догадываться, что делать с вкладкой.
  static String resultPage(String message, {String? returnUrl}) {
    final back = returnUrl == null
        ? ''
        : '''
<p><a id="back" href="$returnUrl" style="display:inline-block; margin-top:16px; padding:14px 28px; border-radius:24px; background:#E53935; color:#fff; font-size:17px; text-decoration:none">Вернуться в Calenfi</a></p>
<script>setTimeout(function () { window.location.href = "$returnUrl"; }, 600);</script>''';
    return '''
<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Calenfi</title></head>
<body style="font-family: -apple-system, system-ui, sans-serif; text-align:center; padding:48px; color:#222">
<h2>Calenfi</h2><p style="font-size:16px">$message</p>$back</body></html>''';
  }
}
