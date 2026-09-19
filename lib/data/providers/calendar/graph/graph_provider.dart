import 'package:dio/dio.dart';

import '../../../../domain/models/account.dart';
import '../../../../domain/models/attendee.dart';
import '../../../../domain/models/calendar.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/conference.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/providers/calendar_provider.dart';
import 'graph_recurrence.dart';
import '../../../../domain/providers/provider_capabilities.dart';
import '../../../../services/conference_parser.dart';
import 'graph_token.dart';

/// Реальный адаптер Office 365 / Outlook через Microsoft Graph (REST).
/// `calendarView` разворачивает повторы на сервере. Teams создаётся нативно.
class GraphProvider implements CalendarProvider {
  GraphProvider({required this.account, required this.token, Dio? dio})
      : _dio = dio ?? Dio() {
    _dio.options
      ..validateStatus = ((s) => s != null && s < 500)
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30);
  }

  static const _base = 'https://graph.microsoft.com/v1.0';
  final Account account;
  final GraphToken token;
  final Dio _dio;

  @override
  ProviderType get type => ProviderType.graph;
  @override
  ProviderCapabilities get caps => ProviderCapabilities.graph;

  Future<Options> _opts({String? contentType, bool utcTz = false}) async {
    final at = await token.accessTokenValid(_dio);
    return Options(headers: {
      'Authorization': 'Bearer $at',
      if (utcTz) 'Prefer': 'outlook.timezone="UTC"',
    }, contentType: contentType);
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
    final resp = await _dio.get('$_base/me/calendars',
        queryParameters: {r'$select': 'id,name,hexColor,isDefaultCalendar,canEdit'},
        options: await _opts());
    final items = (resp.data['value'] as List? ?? []);
    return [
      for (final c in items)
        Calendar(
          id: '${acc.id}|${c['id']}',
          accountId: acc.id,
          name: (c['name'] ?? 'Calendar').toString(),
          color: _hex(c['hexColor'] as String?),
          isPrimary: c['isDefaultCalendar'] == true,
          readOnly: c['canEdit'] == false,
        ),
    ];
  }

  @override
  Future<List<CalendarEvent>> fetchEvents(
      Account acc, Calendar cal, DateRange range) async {
    final out = <CalendarEvent>[];
    // $select с body: без него calendarView отдаёт только bodyPreview (255
    // символов) → длинные ссылки (Telemost и т.п.) режутся. body.content —
    // полный текст, из него берём конференцию.
    const select =
        'id,subject,start,end,isAllDay,location,bodyPreview,body,attendees,responseStatus,showAs,onlineMeeting,isCancelled,webLink,seriesMasterId,type';
    String? url =
        '$_base/me/calendars/${_calId(cal)}/calendarView?startDateTime=${range.startUtc.toUtc().toIso8601String()}&endDateTime=${range.endUtc.toUtc().toIso8601String()}&\$select=$select&\$top=200';
    while (url != null) {
      final resp = await _dio.get(url, options: await _opts(utcTz: true));
      for (final e in (resp.data['value'] as List? ?? [])) {
        final ev = _toEvent(acc, cal, e as Map<String, dynamic>);
        if (ev != null) out.add(ev);
      }
      url = resp.data['@odata.nextLink'] as String?;
    }
    return out;
  }

  @override
  Future<SyncResult> incrementalSync(
      Account acc, Calendar cal, String? syncState) async {
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
    final resp = await _dio.post(
      '$_base/me/calendars/${_calId(cal)}/events',
      data: _toGraph(e),
      options: await _opts(contentType: Headers.jsonContentType),
    );
    return _toEvent(acc, cal, resp.data as Map<String, dynamic>) ?? e;
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    final id = e.source.providerEventId;
    final seriesId = e.recurrenceId; // seriesMasterId у экземпляров серии
    // Вся серия: PATCH по id вхождения Graph превращает его в исключение,
    // поэтому правку адресуем мастеру и сдвигаем его время на ту же дельту.
    if (scope != RecurrenceScope.thisOnly &&
        seriesId != null &&
        seriesId != id) {
      return _updateSeries(e, seriesId: seriesId, originalStartUtc: originalStartUtc);
    }
    await _dio.patch('$_base/me/events/$id',
        data: _toGraph(e),
        options: await _opts(contentType: Headers.jsonContentType));
    return e;
  }

  /// Переносит правку вхождения на мастер серии: время — со сдвигом, остальные
  /// поля как есть. Правило шлём только когда пользователь сменил периодичность
  /// (у вхождения Graph своего правила нет, поэтому непустое поле — это новое).
  Future<CalendarEvent> _updateSeries(
    CalendarEvent e, {
    required String seriesId,
    required DateTime? originalStartUtc,
  }) async {
    final resp = await _dio.get('$_base/me/events/$seriesId',
        options: await _opts());
    final master = (resp.data as Map).cast<String, dynamic>();
    final masterStart = _parseGraphTime(master['start']);
    if (masterStart == null) {
      throw StateError('Graph update: у серии $seriesId нет времени начала');
    }
    final shift = originalStartUtc == null
        ? Duration.zero
        : e.startUtc.toUtc().difference(originalStartUtc.toUtc());
    final newStart = masterStart.add(shift);
    final newEnd = newStart.add(e.endUtc.difference(e.startUtc));
    Map<String, dynamic> t(DateTime d) =>
        {'dateTime': d.toUtc().toIso8601String(), 'timeZone': 'UTC'};
    final payload = _toGraph(e)
      ..remove('recurrence')
      ..['start'] = t(newStart)
      ..['end'] = t(newEnd);
    // Новая периодичность (FR-E6).
    if (e.recurrenceRule != null) {
      final pattern = rruleToGraphRecurrence(e.recurrenceRule!, newStart);
      if (pattern == null) {
        throw UnsupportedError(
            'O365: правило повторения «${e.recurrenceRule}» не поддерживается');
      }
      payload['recurrence'] = pattern;
    }
    // Тот же состав участников не переотправляем: Graph на запись поля шлёт
    // обновлённые приглашения, а переносу времени это ни к чему.
    final remoteEmails = <String>{
      for (final a in (master['attendees'] as List? ?? const []))
        (((a as Map)['emailAddress'] as Map?)?['address'] ?? '')
            .toString()
            .toLowerCase(),
    }..remove('');
    final localEmails = <String>{
      for (final a in e.attendees) a.email.toLowerCase(),
    }..remove('');
    if (remoteEmails.length == localEmails.length &&
        remoteEmails.containsAll(localEmails)) {
      payload.remove('attendees');
    }
    await _dio.patch('$_base/me/events/$seriesId',
        data: payload,
        options: await _opts(contentType: Headers.jsonContentType));
    return e;
  }

  @override
  Future<void> deleteEvent(
      Account acc, CalendarEvent e, RecurrenceScope scope) async {
    final occId = e.source.providerEventId;
    if (occId == null) return;
    final seriesId = e.recurrenceId; // seriesMasterId у экземпляров серии

    switch (scope) {
      case RecurrenceScope.all:
        // Вся серия — удаляем мастер (если известен), иначе сам элемент.
        await _dio.delete('$_base/me/events/${seriesId ?? occId}',
            options: await _opts());
      case RecurrenceScope.thisOnly:
        // Один экземпляр. У Graph нет прямого DELETE для occurrence — пробуем,
        // и если 4xx, отменяем экземпляр через /cancel (для организатора).
        final r = await _dio.delete('$_base/me/events/$occId',
            options: await _opts());
        if ((r.statusCode ?? 500) >= 400) {
          await _dio.post('$_base/me/events/$occId/cancel',
              data: const {'comment': ''},
              options: await _opts(contentType: Headers.jsonContentType));
        }
      case RecurrenceScope.thisAndFollowing:
        // Обрезаем серию: recurrence.range.endDate = день до этого экземпляра.
        if (seriesId == null) {
          await _dio.delete('$_base/me/events/$occId', options: await _opts());
          return;
        }
        final master = await _dio.get('$_base/me/events/$seriesId',
            options: await _opts());
        final rec = (master.data['recurrence'] as Map?)?.cast<String, dynamic>();
        if (rec == null || rec['range'] == null) {
          await _dio.delete('$_base/me/events/$occId', options: await _opts());
          return;
        }
        final end = e.startUtc.toUtc().subtract(const Duration(days: 1));
        final ds =
            '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
        (rec['range'] as Map)
          ..['type'] = 'endDate'
          ..['endDate'] = ds;
        await _dio.patch('$_base/me/events/$seriesId',
            data: {'recurrence': rec},
            options: await _opts(contentType: Headers.jsonContentType));
    }
  }

  @override
  Future<void> respondToInvite(
      Account acc, CalendarEvent e, ResponseStatus r) async {
    final id = e.source.providerEventId;
    if (id == null) return;
    final action = switch (r) {
      ResponseStatus.accepted => 'accept',
      ResponseStatus.declined => 'decline',
      ResponseStatus.tentative => 'tentativelyAccept',
      _ => null,
    };
    if (action == null) return;
    await _dio.post('$_base/me/events/$id/$action',
        data: {'sendResponse': true},
        options: await _opts(contentType: Headers.jsonContentType));
  }

  // ───────── mapping ─────────

  CalendarEvent? _toEvent(Account acc, Calendar cal, Map<String, dynamic> e) {
    final start = _parseGraphTime(e['start']);
    final end = _parseGraphTime(e['end']);
    if (start == null || end == null) return null;

    final attendees = <Attendee>[];
    for (final a in (e['attendees'] as List? ?? [])) {
      final m = a as Map<String, dynamic>;
      attendees.add(Attendee(
        email: (m['emailAddress']?['address'] ?? '').toString(),
        displayName: m['emailAddress']?['name'] as String?,
        response: _resp(m['status']?['response'] as String?),
        isResource: m['type'] == 'resource',
      ));
    }
    final myResp = _resp(e['responseStatus']?['response'] as String?);

    Conference? conf;
    final join = e['onlineMeeting']?['joinUrl'] as String?;
    if (join != null) {
      conf = Conference(type: ConferenceType.teams, joinUrl: join);
    } else {
      // Telemost/прочее — парсим из ПОЛНОГО тела: bodyPreview обрезан до 255
      // символов, поэтому ссылка (в конце текста) режется (`/j/9` вместо
      // полного id). body.content содержит полный текст.
      conf = const ConferenceParser().detect(
        location: e['location']?['displayName'] as String?,
        description:
            (e['body']?['content'] ?? e['bodyPreview']) as String?,
      );
    }

    final status = (e['isCancelled'] == true)
        ? EventStatus.cancelled
        : EventStatus.confirmed;

    return CalendarEvent(
      id: '${acc.id}:${e['id']}',
      calendarId: cal.id,
      title: (e['subject'] ?? '(без названия)').toString(),
      startUtc: start,
      endUtc: end,
      allDay: e['isAllDay'] == true,
      location: e['location']?['displayName'] as String?,
      description: e['bodyPreview'] as String?,
      attendees: attendees,
      myResponse: myResp,
      showAs: e['showAs'] == 'free' ? ShowAs.free : ShowAs.busy,
      conference: conf,
      status: status,
      webUrl: e['webLink'] as String?,
      // Признак серии: у экземпляров/исключений calendarView стоит seriesMasterId.
      // Кладём его в recurrenceId → событие распознаётся как повторяющееся и
      // хранит ссылку на мастер для удаления «всей серии».
      recurrenceId: e['seriesMasterId'] as String?,
      source: EventSource(
          accountId: acc.id, calendarId: cal.id, providerEventId: e['id'] as String?),
    );
  }

  Map<String, dynamic> _toGraph(CalendarEvent e) {
    Map<String, dynamic> t(DateTime d) =>
        {'dateTime': d.toUtc().toIso8601String(), 'timeZone': 'UTC'};
    final conf = e.conference;
    // Нативную Teams-встречу заводим только для «ожидающей» (pending) — если
    // ссылка уже есть (кросс-аккаунт: Zoom/Telemost/Meet или Teams из другой
    // УЗ), она встроена в тело ниже, второй раз не плодим.
    final nativeTeams =
        conf?.type == ConferenceType.teams && !(conf?.isReady ?? false);
    final body = descriptionWithConference(e.description, conf);
    return {
      'subject': e.title,
      'start': t(e.startUtc),
      'end': t(e.endUtc),
      'isAllDay': e.allDay,
      // Повторяющаяся серия (FR-E6): Graph не принимает RRULE-строку —
      // конвертируем в его patternedRecurrence (только у мастера).
      if (e.recurrenceRule != null && e.recurrenceId == null)
        'recurrence': ?rruleToGraphRecurrence(e.recurrenceRule!, e.startUtc),
      if (e.location != null) 'location': {'displayName': e.location},
      if (body != null) 'body': {'contentType': 'text', 'content': body},
      if (e.attendees.isNotEmpty)
        'attendees': [
          for (final a in e.attendees)
            {
              'emailAddress': {'address': a.email},
              'type': a.isResource ? 'resource' : 'required',
            }
        ],
      if (nativeTeams) ...{
        'isOnlineMeeting': true,
        'onlineMeetingProvider': 'teamsForBusiness',
      },
    };
  }

  static DateTime? _parseGraphTime(dynamic t) {
    if (t == null) return null;
    final s = (t['dateTime'] as String?);
    if (s == null) return null;
    // Prefer: outlook.timezone="UTC" → время в UTC, но без 'Z'.
    return DateTime.parse(s.endsWith('Z') ? s : '${s}Z').toUtc();
  }

  static ResponseStatus _resp(String? s) => switch (s) {
        'organizer' => ResponseStatus.organizer,
        'accepted' => ResponseStatus.accepted,
        'declined' => ResponseStatus.declined,
        'tentativelyAccepted' => ResponseStatus.tentative,
        'notResponded' => ResponseStatus.needsAction,
        _ => ResponseStatus.needsAction,
      };

  static int _hex(String? hex) {
    if (hex == null || !hex.startsWith('#') || hex.length < 7) return 0xFF7719AA;
    final rgb = int.tryParse(hex.substring(1, 7), radix: 16);
    return rgb == null ? 0xFF7719AA : 0xFF000000 | rgb;
  }
}
