import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../domain/models/account.dart';
import '../../../domain/models/calendar_event.dart';
import '../../../domain/models/conference.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/providers/yandex_caldav.dart';
import '../../repositories/event_repository.dart';
import '../../secure/credential_source.dart';
import '../calendar/google/google_token.dart';
import '../calendar/graph/graph_token.dart';

/// Конференцию нужного типа завести негде (нет УЗ / кредов / прав). Сообщение —
/// человекочитаемое, показывается пользователю/агенту.
class ConferenceUnavailableException implements Exception {
  ConferenceUnavailableException(this.message);
  final String message;
  @override
  String toString() => 'ConferenceUnavailableException: $message';
}

/// Развязка провижининга видеовстреч от календаря (FR-M1/M3).
///
/// Пользователь выбирает тип (Teams/Meet/Zoom/Telemost) для события в ЛЮБОМ
/// календаре — система идёт в соответствующую УЗ и заводит реальную встречу.
///
/// Гибрид:
///  • тот же аккаунт умеет нативно (Teams↔O365 Graph, Meet↔Google) — отдаём
///    «нативный» маркер (пустой joinUrl), встречу создаёт сам провайдер
///    календаря при createEvent, без отдельных прав;
///  • иначе (кросс-аккаунт) — заводим отдельным API нужной УЗ.
class ConferenceProvisioner {
  ConferenceProvisioner(
      {Dio? dio, CredentialSource? credentials, String? telemostBaseUrl})
      : _dio = dio ?? Dio(),
        _creds = credentials ?? CredentialSource.load(),
        _telemostBaseUrl = telemostBaseUrl ??
            'https://cloud-api.yandex.net/v1/telemost-api/conferences';

  final Dio _dio;
  final CredentialSource _creds;

  /// База Telemost API (переопределяется в тестах).
  final String _telemostBaseUrl;

  /// Умеет ли провайдер календаря [target] завести конференцию [type] нативно
  /// в самом событии (без отдельного API/прав): Graph→Teams, Google→Meet,
  /// Yandex CalDAV→Telemost (`X-TELEMOST-REQUIRED`).
  static bool nativeCapable(ConferenceType type, Account? target) {
    if (target == null) return false;
    return (type == ConferenceType.teams &&
            target.provider == ProviderType.graph) ||
        (type == ConferenceType.meet && target.provider == ProviderType.google) ||
        (type == ConferenceType.telemost && isYandexCalDavAccount(target));
  }

  /// Если у [e] «ожидающая» конференция (пустой joinUrl) — заводит её и, для
  /// кросс-аккаунтного случая, возвращает событие с реальной ссылкой (и
  /// сохраняет его локально). Нативный случай возвращает [e] как есть (встречу
  /// заведёт провайдер календаря). Бросает [ConferenceUnavailableException].
  Future<CalendarEvent> ensure(
    CalendarEvent e, {
    required Account target,
    required List<Account> allAccounts,
    required EventRepository events,
  }) async {
    final conf = e.conference;
    if (conf == null || conf.isReady) return e; // нечего заводить / уже готова
    final resolved = await resolve(
      conf.type,
      accountId: conf.accountId,
      target: target,
      allAccounts: allAccounts,
      start: e.startUtc,
      end: e.endUtc,
      subject: e.title,
    );
    if (!resolved.isReady) {
      // Keep the canonical target account on the pending marker. This matters
      // for CLI-created events, whose initial Conference.pending has no
      // accountId, and lets provider serializers distinguish an explicit
      // native request from an arbitrary meeting URL found in DESCRIPTION.
      return e.copyWith(conference: resolved);
    }
    final updated = e.copyWith(conference: resolved);
    await events.putLocalDirty(updated);
    return updated;
  }

  /// Готовит конференцию [type] для события в календаре [target].
  /// [accountId] — УЗ-хост встречи, выбранная пользователем (Teams/Meet). Если
  /// совпадает с УЗ календаря — заводим нативно; иначе кросс-аккаунт по её токену.
  Future<Conference> resolve(
    ConferenceType type, {
    String? accountId,
    required Account? target,
    required List<Account> allAccounts,
    required DateTime start,
    required DateTime end,
    required String subject,
  }) async {
    // Хост встречи: выбранная УЗ; если не выбрана — УЗ календаря или первая.
    final host = _accountById(allAccounts, accountId);
    // Нативно только если хост = УЗ календаря (её провайдер создаст встречу сам).
    final hostIsTarget = (accountId == null || accountId == target?.id);
    if (hostIsTarget && nativeCapable(type, target)) {
      return Conference.pending(type, accountId: target!.id);
    }
    switch (type) {
      case ConferenceType.teams:
        return _teams(host ?? _firstOf(allAccounts, ProviderType.graph),
            start, end, subject);
      case ConferenceType.meet:
        return _meet(host ?? _firstOf(allAccounts, ProviderType.google));
      case ConferenceType.zoom:
        return _zoom(start, end, subject);
      case ConferenceType.telemost:
        return _telemost();
      case ConferenceType.unknown:
        throw ConferenceUnavailableException('Неизвестный тип конференции');
    }
  }

  Account? _firstOf(List<Account> accounts, ProviderType p) {
    for (final a in accounts) {
      if (a.provider == p) return a;
    }
    return null;
  }

  Account? _accountById(List<Account> accounts, String? id) {
    if (id == null) return null;
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Teams standalone: POST /me/onlineMeetings (scope OnlineMeetings.ReadWrite).
  Future<Conference> _teams(
      Account? acc, DateTime start, DateTime end, String subject) async {
    if (acc == null) {
      throw ConferenceUnavailableException(
          'Нет подключённого O365-аккаунта для встречи Teams');
    }
    final token = GraphToken.loadFor(acc.email);
    if (token == null) {
      throw ConferenceUnavailableException(
          'Нет токена Teams для ${acc.email} — переподключи аккаунт');
    }
    final at = await token.accessTokenValid(_dio);
    try {
      final resp = await _dio.post(
        'https://graph.microsoft.com/v1.0/me/onlineMeetings',
        data: {
          'startDateTime': start.toUtc().toIso8601String(),
          'endDateTime': end.toUtc().toIso8601String(),
          'subject': subject,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $at'},
          contentType: Headers.jsonContentType,
        ),
      );
      final m = resp.data as Map<String, dynamic>;
      final url = m['joinWebUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw ConferenceUnavailableException('Teams не вернул ссылку встречи');
      }
      return Conference(
          type: ConferenceType.teams, joinUrl: url, meetingId: m['id'] as String?);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw ConferenceUnavailableException(
            'Teams: нет прав OnlineMeetings.ReadWrite — переавторизуй O365 (${acc.email})');
      }
      rethrow;
    }
  }

  /// Google Meet standalone: POST meet/v2/spaces (scope meetings.space.created).
  Future<Conference> _meet(Account? acc) async {
    if (acc == null) {
      throw ConferenceUnavailableException(
          'Нет подключённого Google-аккаунта для Meet');
    }
    final token = GoogleToken.loadFor(acc.email);
    if (token == null) {
      throw ConferenceUnavailableException(
          'Нет токена Google для ${acc.email} — переподключи аккаунт');
    }
    final at = await token.accessTokenValid(_dio);
    try {
      final resp = await _dio.post(
        'https://meet.googleapis.com/v2/spaces',
        data: const <String, dynamic>{},
        options: Options(
          headers: {'Authorization': 'Bearer $at'},
          contentType: Headers.jsonContentType,
        ),
      );
      final m = resp.data as Map<String, dynamic>;
      final url = m['meetingUri'] as String?;
      if (url == null || url.isEmpty) {
        throw ConferenceUnavailableException('Meet не вернул ссылку');
      }
      return Conference(
          type: ConferenceType.meet,
          joinUrl: url,
          meetingId: m['meetingCode'] as String?);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw ConferenceUnavailableException(
            'Meet: нет scope meetings.space.created — переавторизуй Google (${acc.email})');
      }
      rethrow;
    }
  }

  /// Best-effort удаление внешне заведённой видеовстречи при удалении события.
  /// Для Zoom (standalone) вызывает DELETE /v2/meetings/{id}. Для Teams/Meet
  /// встреча живёт в самом событии и уходит вместе с ним; Telemost API удаления
  /// не имеет. Ошибки глотаем — удаление события уже произошло.
  Future<void> deleteConference(Conference? conf) async {
    if (conf == null ||
        conf.type != ConferenceType.zoom ||
        conf.meetingId == null) {
      return;
    }
    try {
      final at = await _zoomToken();
      if (at == null) return;
      await _dio.delete(
        'https://api.zoom.us/v2/meetings/${conf.meetingId}',
        options: Options(headers: {'Authorization': 'Bearer $at'}),
      );
    } on Object {/* best-effort: событие уже удалено */}
  }

  /// Zoom Server-to-Server access-токен (grant account_credentials). null, если
  /// ключи не заданы или обмен не удался.
  Future<String?> _zoomToken() async {
    final accountId = _creds.zoomAccountId;
    final clientId = _creds.zoomClientId;
    final clientSecret = _creds.zoomClientSecret;
    if (accountId == null || clientId == null || clientSecret == null) {
      return null;
    }
    try {
      final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final tok = await _dio.post(
        'https://zoom.us/oauth/token',
        queryParameters: {
          'grant_type': 'account_credentials',
          'account_id': accountId,
        },
        options: Options(
          headers: {'Authorization': 'Basic $basic'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      return (tok.data as Map)['access_token'] as String?;
    } on Object {
      return null;
    }
  }

  /// Zoom через Server-to-Server OAuth: получаем access-токен по
  /// account_credentials, затем создаём запланированную встречу.
  Future<Conference> _zoom(
      DateTime start, DateTime end, String subject) async {
    final accountId = _creds.zoomAccountId;
    final clientId = _creds.zoomClientId;
    final clientSecret = _creds.zoomClientSecret;
    if (accountId == null || clientId == null || clientSecret == null) {
      throw ConferenceUnavailableException(
          'Zoom не настроен: добавь ZOOM_ACCOUNT_ID / ZOOM_CLIENT_ID / '
          'ZOOM_CLIENT_SECRET (Server-to-Server OAuth) в tools/secrets.env');
    }
    // 1) access-токен (grant account_credentials, Basic client_id:secret).
    final String at;
    try {
      final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final tok = await _dio.post(
        'https://zoom.us/oauth/token',
        queryParameters: {
          'grant_type': 'account_credentials',
          'account_id': accountId,
        },
        options: Options(
          headers: {'Authorization': 'Basic $basic'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      final token = (tok.data as Map)['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw ConferenceUnavailableException(
            'Zoom не выдал токен — проверь Account ID / Client ID / Secret');
      }
      at = token;
    } on DioException catch (e) {
      throw ConferenceUnavailableException(
          'Zoom OAuth не прошёл (${e.response?.statusCode}) — проверь '
          'ZOOM_ACCOUNT_ID / ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET');
    }
    // 2) создаём встречу (type 2 — scheduled).
    try {
      final duration = end.difference(start).inMinutes.clamp(1, 1440);
      final resp = await _dio.post(
        'https://api.zoom.us/v2/users/me/meetings',
        data: {
          'topic': subject,
          'type': 2,
          'start_time': start.toUtc().toIso8601String(),
          'duration': duration,
          'timezone': 'UTC',
        },
        options: Options(
          headers: {'Authorization': 'Bearer $at'},
          contentType: Headers.jsonContentType,
        ),
      );
      final m = resp.data as Map<String, dynamic>;
      final url = m['join_url'] as String?;
      if (url == null || url.isEmpty) {
        throw ConferenceUnavailableException('Zoom не вернул join_url');
      }
      return Conference(
        type: ConferenceType.zoom,
        joinUrl: url,
        meetingId: m['id']?.toString(),
        password: m['password'] as String?,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw ConferenceUnavailableException(
            'Zoom: нет прав на создание встреч — добавь scope meeting:write в '
            'Server-to-Server OAuth app');
      }
      rethrow;
    }
  }

  /// Yandex Telemost: POST /v1/conferences с OAuth-токеном (scope
  /// `telemost-api:conferences.create`). Токен кладётся в keyring под
  /// `TELEMOST_OAUTH_TOKEN` (через подключение Telemost в приложении или
  /// `tools/calenfi secret-set`).
  Future<Conference> _telemost() async {
    final token = _creds.telemostToken;
    if (token == null) {
      throw ConferenceUnavailableException(
          'Telemost не подключён: нужен Yandex OAuth-токен (Учётные записи → '
          'Добавить → Telemost, либо secret-set TELEMOST_OAUTH_TOKEN).');
    }
    try {
      final resp = await _dio.post(
        _telemostBaseUrl,
        data: {'waiting_room_level': 'PUBLIC'},
        options: Options(
          headers: {'Authorization': 'OAuth $token'},
          contentType: Headers.jsonContentType,
        ),
      );
      final m = resp.data as Map<String, dynamic>;
      final url = m['join_url'] as String?;
      if (url == null || url.isEmpty) {
        throw ConferenceUnavailableException('Telemost не вернул join_url');
      }
      return Conference(
        type: ConferenceType.telemost,
        joinUrl: url,
        meetingId: m['id']?.toString(),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        throw ConferenceUnavailableException(
            'Telemost: токен недействителен или нет scope '
            'telemost-api:conferences.create — переподключи Telemost');
      }
      throw ConferenceUnavailableException('Telemost: ошибка $code');
    }
  }
}
