import 'package:dio/dio.dart';

import '../../../../domain/models/account.dart';
import '../../../../domain/models/attendee.dart';
import '../../../../domain/models/calendar.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/conference.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/providers/calendar_provider.dart';
import '../../../../domain/providers/provider_capabilities.dart';
import 'google_token.dart';

/// Реальный адаптер Google Calendar (REST API v3). Переиспользует refresh-токен
/// из tools/.tokens/ (dev). `singleEvents=true` разворачивает повторы на сервере.
class GoogleProvider implements CalendarProvider {
  GoogleProvider({required this.account, required this.token, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options
      ..validateStatus = ((s) => s != null && s < 500)
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30);
  }

  static const _base = 'https://www.googleapis.com/calendar/v3';
  final Account account;
  final GoogleToken token;
  final Dio _dio;

  @override
  ProviderType get type => ProviderType.google;
  @override
  ProviderCapabilities get caps => ProviderCapabilities.google;

  Future<Options> _opts({String? contentType}) async {
    final at = await token.accessTokenValid(_dio);
    return Options(headers: {'Authorization': 'Bearer $at'}, contentType: contentType);
  }

  String _calId(Calendar cal) => cal.id.split('|').last;

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async {
    try {
      await token.accessTokenValid(_dio);
      return AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, error: '$e');
    }
  }

  @override
  Future<void> refreshAuth(Account acc) async {
    await token.accessTokenValid(_dio);
  }

  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    final resp = await _dio.get('$_base/users/me/calendarList',
        options: await _opts());
    final items = (resp.data['items'] as List? ?? []);
    return [
      for (final c in items)
        Calendar(
          id: '${acc.id}|${c['id']}',
          accountId: acc.id,
          name: (c['summaryOverride'] ?? c['summary'] ?? c['id']).toString(),
          color: _hex(c['backgroundColor'] as String?),
          isPrimary: c['primary'] == true,
          readOnly: c['accessRole'] == 'reader' || c['accessRole'] == 'freeBusyReader',
        ),
    ];
  }

  @override
  Future<List<CalendarEvent>> fetchEvents(
      Account acc, Calendar cal, DateRange range) async {
    final calId = _calId(cal);
    final out = <CalendarEvent>[];
    String? pageToken;
    do {
      final qp = <String, String>{
        'timeMin': range.startUtc.toUtc().toIso8601String(),
        'timeMax': range.endUtc.toUtc().toIso8601String(),
        'singleEvents': 'true',
        'orderBy': 'startTime',
        'maxResults': '2500',
      };
      if (pageToken != null) qp['pageToken'] = pageToken;
      final resp = await _dio.get(
        '$_base/calendars/${Uri.encodeComponent(calId)}/events',
        queryParameters: qp,
        options: await _opts(),
      );
      for (final e in (resp.data['items'] as List? ?? [])) {
        final ev = _toEvent(acc, cal, e as Map<String, dynamic>);
        if (ev != null) out.add(ev);
      }
      pageToken = resp.data['nextPageToken'] as String?;
    } while (pageToken != null);
    return out;
  }

  @override
  Future<SyncResult> incrementalSync(
      Account acc, Calendar cal, String? syncState) async {
    // MVP: оконный полный fetch (singleEvents разворачивает повторы на сервере).
    final now = DateTime.now().toUtc();
    final range = DateRange(
        now.subtract(const Duration(days: 90)), now.add(const Duration(days: 365)));
    final events = await fetchEvents(acc, cal, range);
    return SyncResult(
        upserts: events, deletedIds: const [], newSyncState: null, fullWindow: range);
  }

  @override
  Future<CalendarEvent> createEvent(
      Account acc, Calendar cal, CalendarEvent e) async {
    // Нативный Meet — только для «ожидающей» конференции; готовая (кросс-аккаунт)
    // уже встроена в описание, второй раз не заводим.
    final wantsMeet =
        e.conference?.type == ConferenceType.meet && !e.conference!.isReady;
    final resp = await _dio.post(
      '$_base/calendars/${Uri.encodeComponent(_calId(cal))}/events',
      queryParameters: {if (wantsMeet) 'conferenceDataVersion': '1'},
      data: _toGoogle(e, withMeet: wantsMeet),
      options: await _opts(contentType: Headers.jsonContentType),
    );
    final created = _toEvent(acc, cal, resp.data as Map<String, dynamic>);
    return created ?? e;
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    final calId = Uri.encodeComponent(e.calendarId.split('|').last);
    final instanceId = e.source.providerEventId;
    final masterId = e.recurrenceId;
    // Вся серия: правку надо адресовать мастеру. PATCH по instance-id Google
    // всегда трактует как исключение одного вхождения.
    if (scope != RecurrenceScope.thisOnly &&
        masterId != null &&
        masterId != instanceId) {
      return _updateSeries(
        acc,
        e,
        calId: calId,
        masterId: masterId,
        instanceId: instanceId,
        originalStartUtc: originalStartUtc,
      );
    }
    await _dio.patch(
      '$_base/calendars/$calId/events/$instanceId',
      data: _toGoogle(e),
      options: await _opts(contentType: Headers.jsonContentType),
    );
    return e;
  }

  /// Переносит правку экземпляра на мастер серии: время сдвигаем на ту же
  /// дельту, что и у вхождения, остальные поля копируем как есть. RRULE шлём
  /// только когда пользователь сам сменил периодичность (у вхождения Google
  /// правила нет, поэтому непустое поле здесь — это и есть новое правило).
  Future<CalendarEvent> _updateSeries(
    Account acc,
    CalendarEvent e, {
    required String calId,
    required String masterId,
    required String? instanceId,
    required DateTime? originalStartUtc,
  }) async {
    final resp = await _dio.get(
      '$_base/calendars/$calId/events/$masterId',
      options: await _opts(),
    );
    final master = (resp.data as Map).cast<String, dynamic>();
    final masterStart = _parseGTime(master['start']);
    final masterEnd = _parseGTime(master['end']);
    if (masterStart == null || masterEnd == null) {
      throw StateError('Google update: у серии $masterId нет времени начала');
    }

    final origStart =
        originalStartUtc?.toUtc() ?? _instanceStartFromId(instanceId);
    final shift = origStart == null
        ? Duration.zero
        : e.startUtc.toUtc().difference(origStart);
    final duration = e.endUtc.difference(e.startUtc);
    final newStart = masterStart.add(shift);

    // Поля берём из правки, время — сдвинутое от мастера.
    final payload = _toGoogle(e)
      ..remove('recurrence')
      ..['start'] = _gTime(newStart, allDay: e.allDay)
      ..['end'] = _gTime(newStart.add(duration), allDay: e.allDay);
    // Новая периодичность (FR-E6): без этого правило серии оставалось
    // серверным и сменить его было нечем.
    if (e.recurrenceRule != null) {
      payload['recurrence'] = ['RRULE:${e.recurrenceRule}'];
    }

    // Список участников у вхождения и у серии может расходиться (исключение
    // серии умеет иметь свой). Одинаковый состав не отправляем: Google
    // рассылает приглашения по факту записи поля, а переносу времени такая
    // рассылка не нужна.
    if (_sameAttendees(master['attendees'], e)) payload.remove('attendees');

    await _dio.patch(
      '$_base/calendars/$calId/events/$masterId',
      data: payload,
      options: await _opts(contentType: Headers.jsonContentType),
    );
    return e;
  }

  /// Совпадает ли состав участников правки с тем, что уже стоит у серии.
  static bool _sameAttendees(dynamic remote, CalendarEvent e) {
    final remoteEmails = <String>{
      for (final a in (remote as List? ?? const []))
        ((a as Map)['email'] ?? '').toString().toLowerCase(),
    }..remove('');
    final localEmails = <String>{
      for (final a in e.attendees) a.email.toLowerCase(),
    }..remove('');
    return remoteEmails.length == localEmails.length &&
        remoteEmails.containsAll(localEmails);
  }

  /// Начало вхождения, зашитое в id экземпляра (`<master>_20260913T110000Z`
  /// у обычных событий, `<master>_20260913` у событий на весь день). Это
  /// исходное время вхождения, поэтому дельту сдвига можно вычислить без сети.
  static DateTime? _instanceStartFromId(String? instanceId) {
    if (instanceId == null) return null;
    final underscore = instanceId.lastIndexOf('_');
    if (underscore < 0) return null;
    final stamp = instanceId.substring(underscore + 1);
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z)?$')
        .firstMatch(stamp);
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    return DateTime.utc(
      g(1),
      g(2),
      g(3),
      m.group(4) == null ? 0 : g(4),
      m.group(5) == null ? 0 : g(5),
      m.group(6) == null ? 0 : g(6),
    );
  }

  @override
  Future<void> deleteEvent(
      Account acc, CalendarEvent e, RecurrenceScope scope) async {
    final calId = Uri.encodeComponent(e.calendarId.split('|').last);
    final instId = e.source.providerEventId;
    if (instId == null) return;
    final masterId = e.recurrenceId; // id мастера серии (recurringEventId)

    switch (scope) {
      case RecurrenceScope.all:
        await _dio.delete('$_base/calendars/$calId/events/${masterId ?? instId}',
            options: await _opts());
      case RecurrenceScope.thisOnly:
        // Google удаляет один экземпляр по его instance-id.
        await _dio.delete('$_base/calendars/$calId/events/$instId',
            options: await _opts());
      case RecurrenceScope.thisAndFollowing:
        if (masterId == null) {
          await _dio.delete('$_base/calendars/$calId/events/$instId',
              options: await _opts());
          return;
        }
        // Обрезаем серию: в RRULE мастера ставим UNTIL = за секунду до экземпляра.
        final master =
            await _dio.get('$_base/calendars/$calId/events/$masterId',
                options: await _opts());
        final rec = (master.data['recurrence'] as List?)?.cast<String>() ??
            const <String>[];
        final until = _untilStamp(
            e.startUtc.toUtc().subtract(const Duration(seconds: 1)));
        final newRec = [
          for (final r in rec)
            r.toUpperCase().startsWith('RRULE') ? _rruleWithUntil(r, until) : r
        ];
        await _dio.patch('$_base/calendars/$calId/events/$masterId',
            data: {'recurrence': newRec},
            options: await _opts(contentType: Headers.jsonContentType));
    }
  }

  /// UTC-штамп для RRULE UNTIL: `20260705T235959Z`.
  static String _untilStamp(DateTime d) {
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${p(d.year, 4)}${p(d.month)}${p(d.day)}T${p(d.hour)}${p(d.minute)}${p(d.second)}Z';
  }

  /// Заменяет/добавляет UNTIL в RRULE, убирая конфликтующий COUNT.
  static String _rruleWithUntil(String rrule, String until) {
    final parts = rrule
        .replaceFirst(RegExp(r'^RRULE:', caseSensitive: false), '')
        .split(';')
        .where((p) => p.isNotEmpty &&
            !p.toUpperCase().startsWith('UNTIL') &&
            !p.toUpperCase().startsWith('COUNT'))
        .toList()
      ..add('UNTIL=$until');
    return 'RRULE:${parts.join(';')}';
  }

  @override
  Future<void> respondToInvite(
      Account acc, CalendarEvent e, ResponseStatus r) async {
    final id = e.source.providerEventId;
    if (id == null) return;
    final status = switch (r) {
      ResponseStatus.accepted => 'accepted',
      ResponseStatus.declined => 'declined',
      ResponseStatus.tentative => 'tentative',
      _ => 'needsAction',
    };
    // обновляем свой responseStatus в списке участников
    final attendees = [
      for (final a in e.attendees)
        {
          'email': a.email,
          if (a.email.toLowerCase() == acc.email.toLowerCase())
            'responseStatus': status
          else
            'responseStatus': a.response.name,
          if (a.email.toLowerCase() == acc.email.toLowerCase()) 'self': true,
        }
    ];
    await _dio.patch(
      '$_base/calendars/${Uri.encodeComponent(e.calendarId.split('|').last)}/events/$id',
      data: {'attendees': attendees},
      options: await _opts(contentType: Headers.jsonContentType),
    );
  }

  // ───────── mapping ─────────

  CalendarEvent? _toEvent(Account acc, Calendar cal, Map<String, dynamic> e) {
    if (e['status'] == 'cancelled' && e['start'] == null) return null;
    final start = _parseGTime(e['start']);
    final end = _parseGTime(e['end']) ?? start?.add(const Duration(hours: 1));
    if (start == null || end == null) return null;
    final allDay = (e['start']?['date']) != null;

    final attendees = <Attendee>[];
    ResponseStatus myResp = ResponseStatus.organizer;
    for (final a in (e['attendees'] as List? ?? [])) {
      final m = a as Map<String, dynamic>;
      final resp = _resp(m['responseStatus'] as String?);
      attendees.add(Attendee(
        email: (m['email'] ?? '').toString(),
        displayName: m['displayName'] as String?,
        response: resp,
        isOrganizer: m['organizer'] == true,
        isResource: m['resource'] == true,
      ));
      if (m['self'] == true) myResp = resp;
    }
    if (e['organizer']?['self'] == true && attendees.isEmpty) {
      myResp = ResponseStatus.organizer;
    }

    Conference? conf;
    final hangout = e['hangoutLink'] as String?;
    if (hangout != null) {
      conf = Conference(type: ConferenceType.meet, joinUrl: hangout);
    }

    final status = switch (e['status']) {
      'cancelled' => EventStatus.cancelled,
      'tentative' => EventStatus.tentative,
      _ => EventStatus.confirmed,
    };

    return CalendarEvent(
      id: '${acc.id}:${e['id']}',
      calendarId: cal.id,
      title: (e['summary'] ?? '(без названия)').toString(),
      startUtc: start,
      endUtc: end,
      allDay: allDay,
      location: e['location'] as String?,
      description: e['description'] as String?,
      attendees: attendees,
      myResponse: myResp,
      conference: conf,
      status: status,
      webUrl: e['htmlLink'] as String?,
      // У экземпляров (singleEvents=true) стоит recurringEventId — id мастера.
      // Кладём его в recurrenceId: событие распознаётся как повторяющееся.
      recurrenceId: e['recurringEventId'] as String?,
      source: EventSource(
          accountId: acc.id, calendarId: cal.id, providerEventId: e['id'] as String?),
    );
  }

  /// Время в формате Google: у событий на весь день — календарная дата.
  static Map<String, dynamic> _gTime(DateTime d, {required bool allDay}) =>
      allDay
      ? {'date': d.toUtc().toIso8601String().substring(0, 10)}
      : {'dateTime': d.toUtc().toIso8601String(), 'timeZone': 'UTC'};

  Map<String, dynamic> _toGoogle(CalendarEvent e, {bool withMeet = false}) {
    Map<String, dynamic> time(DateTime d) => _gTime(d, allDay: e.allDay);
    // Кросс-аккаунтная конференция (готовая ссылка) встраивается в описание,
    // чтобы была видна и переразбиралась; нативный Meet — только через withMeet.
    final description = descriptionWithConference(e.description, e.conference);
    return {
      'summary': e.title,
      'start': time(e.startUtc),
      'end': time(e.endUtc),
      // Повторяющаяся серия (FR-E6): RRULE как есть. Времена шлём в UTC,
      // поэтому BYDAY трактуется по UTC-дню — для дневных встреч это тот же
      // день недели, что и локально.
      if (e.recurrenceRule != null && e.recurrenceId == null)
        'recurrence': ['RRULE:${e.recurrenceRule}'],
      if (e.location != null) 'location': e.location,
      'description': ? description,
      if (e.attendees.isNotEmpty)
        'attendees': [
          for (final a in e.attendees)
            {'email': a.email, if (a.isResource) 'resource': true}
        ],
      if (withMeet)
        'conferenceData': {
          'createRequest': {
            'requestId': e.id,
            'conferenceSolutionKey': {'type': 'hangoutsMeet'},
          }
        },
    };
  }

  static DateTime? _parseGTime(dynamic t) {
    if (t == null) return null;
    final m = t as Map<String, dynamic>;
    if (m['dateTime'] != null) return DateTime.parse(m['dateTime'] as String).toUtc();
    if (m['date'] != null) {
      final p = (m['date'] as String).split('-').map(int.parse).toList();
      return DateTime.utc(p[0], p[1], p[2]);
    }
    return null;
  }

  static ResponseStatus _resp(String? s) => switch (s) {
        'accepted' => ResponseStatus.accepted,
        'declined' => ResponseStatus.declined,
        'tentative' => ResponseStatus.tentative,
        _ => ResponseStatus.needsAction,
      };

  static int _hex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length < 7) return 0xFF4F86F7;
    final rgb = int.tryParse(hex.substring(1, 7), radix: 16);
    return rgb == null ? 0xFF4F86F7 : 0xFF000000 | rgb;
  }
}
