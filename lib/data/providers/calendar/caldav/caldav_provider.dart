import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:rrule/rrule.dart';
import 'package:xml/xml.dart';

import '../../../../domain/models/account.dart';
import '../../../../domain/models/attendee.dart';
import '../../../../domain/models/calendar.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/conference.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/providers/calendar_provider.dart';
import '../../../../domain/providers/provider_capabilities.dart';
import 'ics.dart';

/// Один удалённый .ics-ресурс. Legacy-версии Calenfi могли
/// создать несколько ресурсов с UID, отличающимися только
/// повторённым `account:calendar:`-префиксом.
class _CalDavResource {
  const _CalDavResource({
    required this.href,
    required this.etag,
    required this.events,
    required this.legacyDepth,
  });

  final String href;
  final String? etag;
  final List<VEvent> events;
  final int legacyDepth;

  int get _sequence =>
      events.map((e) => e.sequence ?? -1).fold(-1, (a, b) => a > b ? a : b);

  int get _revisionMicros => events
      .map((e) => e.lastModifiedUtc ?? e.dtStampUtc)
      .whereType<DateTime>()
      .map((e) => e.microsecondsSinceEpoch)
      .fold(-1, (a, b) => a > b ? a : b);

  String get _uidFingerprint {
    final uids = events.map((e) => e.uid.trim()).toSet().toList()..sort();
    return uids.join('\u0000');
  }

  /// LAST-MODIFIED/DTSTAMP — главный межресурсный сигнал. SEQUENCE не
  /// сравним между разными producer/UID lineage (старый Calenfi писал
  /// epoch seconds, а Windows — малые инкременты). Поэтому SEQUENCE можно
  /// сравнивать только между ресурсами с тем же точным UID fingerprint.
  /// При равном времени между разными lineage предпочитаем raw UID, затем
  /// наименьшую глубину legacy-префикса. href даёт полную детерминированность.
  bool isNewerThan(_CalDavResource other) {
    if (_revisionMicros != other._revisionMicros) {
      return _revisionMicros > other._revisionMicros;
    }
    if (_uidFingerprint == other._uidFingerprint &&
        _sequence != other._sequence) {
      return _sequence > other._sequence;
    }
    if (legacyDepth != other.legacyDepth) {
      return legacyDepth < other.legacyDepth;
    }
    return href.compareTo(other.href) > 0;
  }
}

class _CompleteCalendarResponse {
  const _CompleteCalendarResponse({
    required this.href,
    required this.etag,
    required this.ics,
  });

  final String href;
  final String? etag;
  final String ics;
}

class _CalDavDeleteTarget {
  const _CalDavDeleteTarget({
    required this.href,
    required this.etag,
    required this.legacyDepth,
  });

  final String href;
  final String? etag;
  final int legacyDepth;
}

class _RawVEvent {
  const _RawVEvent({required this.match, required this.event});

  final RegExpMatch match;
  final VEvent event;
}

/// Реальный адаптер CalDAV (Yandex и совместимые). App-password + Basic auth.
/// Параметры host/port/principal — из [Account.config] (FR-A3).
class CalDavProvider implements CalendarProvider {
  CalDavProvider({required this.account, required this.password, Dio? dio})
    : _dio = dio ?? Dio() {
    _dio.options
      ..validateStatus = ((s) => s != null && s < 500)
      ..connectTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 30)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers['Authorization'] = _basic
      ..headers['Content-Type'] = 'application/xml; charset=utf-8';
  }

  final Account account;
  final String password;
  final Dio _dio;

  String get _basic =>
      'Basic ${base64.encode(utf8.encode('${account.email}:$password'))}';

  String get _base {
    final host = account.config.caldavHost ?? 'caldav.yandex.ru';
    final port = account.config.caldavPort ?? 443;
    return 'https://$host:$port';
  }

  String _url(String href) {
    final uri = Uri.tryParse(href);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return uri.toString();
    }
    return '$_base${href.startsWith('/') ? href : '/$href'}';
  }

  @override
  ProviderType get type => ProviderType.caldav;

  @override
  ProviderCapabilities get caps => ProviderCapabilities.caldav;

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async {
    try {
      await _propfind(
        '/',
        0,
        '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>',
      );
      return AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, error: '$e');
    }
  }

  @override
  Future<void> refreshAuth(Account acc) async {}

  // ───────── структура ─────────

  Future<String> _calendarHome() async {
    final principal =
        account.config.caldavPrincipalPath ??
        '/principals/users/${Uri.encodeComponent(account.email)}/';
    final doc = await _propfind(
      principal,
      0,
      '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-home-set/></d:prop></d:propfind>',
    );
    final href = doc
        .findAllElements(
          'calendar-home-set',
          namespace: 'urn:ietf:params:xml:ns:caldav',
        )
        .expand((e) => e.findElements('href', namespace: 'DAV:'))
        .map((e) => e.innerText.trim())
        .firstOrNull;
    return href ?? '/calendars/${Uri.encodeComponent(account.email)}/';
  }

  @override
  Future<List<Calendar>> listCalendars(Account acc) async {
    final home = await _calendarHome();
    final doc = await _propfind(
      home,
      1,
      '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:ic="http://apple.com/ns/ical/"><d:prop><d:displayname/><d:resourcetype/><cs:getctag/><ic:calendar-color/></d:prop></d:propfind>',
    );

    final calendars = <Calendar>[];
    for (final resp in doc.findAllElements('response', namespace: 'DAV:')) {
      final href = resp
          .findElements('href', namespace: 'DAV:')
          .firstOrNull
          ?.innerText
          .trim();
      if (href == null) continue;
      final isCalendar = resp
          .findAllElements(
            'calendar',
            namespace: 'urn:ietf:params:xml:ns:caldav',
          )
          .isNotEmpty;
      if (!isCalendar) continue;
      if (href.endsWith('/inbox/') || href.endsWith('/outbox/')) continue;
      if (href.contains('/todos-')) continue; // списки задач — пропускаем

      final name = resp
          .findAllElements('displayname', namespace: 'DAV:')
          .firstOrNull
          ?.innerText
          .trim();
      final colorHex = resp
          .findAllElements(
            'calendar-color',
            namespace: 'http://apple.com/ns/ical/',
          )
          .firstOrNull
          ?.innerText
          .trim();

      calendars.add(
        Calendar(
          id: '${acc.id}|$href',
          accountId: acc.id,
          name: (name == null || name.isEmpty) ? href : name,
          color: _parseColor(colorHex),
          // syncState НЕ ставим здесь — иначе incrementalSync решит, что менять
          // нечего, и не подтянет события на первом синке. Его выставит синк.
        ),
      );
    }
    return calendars;
  }

  // ───────── чтение ─────────

  String _calHref(Calendar cal) => cal.id.split('|').last;

  @override
  Future<List<CalendarEvent>> fetchEvents(
    Account acc,
    Calendar cal,
    DateRange range,
  ) async {
    final body =
        '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
        '<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">'
        '<c:time-range start="${_z(range.startUtc)}" end="${_z(range.endUtc)}"/>'
        '</c:comp-filter></c:comp-filter></c:filter></c:calendar-query>';

    final resp = await _dio.requestUri(
      Uri.parse(_url(_calHref(cal))),
      data: body,
      options: _requestOptions('REPORT', headers: {'Depth': '1'}),
    );
    final doc = XmlDocument.parse(resp.data.toString());
    final resourcesByUid = <String, List<_CalDavResource>>{};
    for (final r in doc.findAllElements('response', namespace: 'DAV:')) {
      final parsed = _completeCalendarResponse(r);
      final href = parsed.href;
      final etag = parsed.etag;
      final ics = parsed.ics;

      // Один CalDAV-ресурс обычно содержит VEVENT-ы одного UID
      // (мастер + exceptions), но группируем явно, чтобы не полагаться
      // на это правило в кривом ответе сервера.
      final parsedEvents = parseIcs(ics);
      if (parsedEvents.isEmpty) {
        throw FormatException(
          'CalDAV REPORT: calendar-data без валидного VEVENT ($href)',
        );
      }
      if (parsedEvents.any((v) => v.uid.trim().isEmpty)) {
        throw FormatException('CalDAV REPORT: VEVENT без UID ($href)');
      }
      final byUid = parsedEvents.groupListsBy(
        (v) => _canonicalUid(acc, cal, v.uid),
      );
      for (final entry in byUid.entries) {
        final candidate = _CalDavResource(
          href: href,
          etag: etag,
          events: entry.value,
          legacyDepth: entry.value
              .map((v) => _legacyPrefixDepth(acc, cal, v.uid))
              .fold(0, (a, b) => a > b ? a : b),
        );
        resourcesByUid.putIfAbsent(entry.key, () => []).add(candidate);
      }
    }

    final out = <CalendarEvent>[];
    for (final entry in resourcesByUid.entries) {
      final resource = _newestResource(entry.value);
      out.addAll(_expandResource(acc, cal, resource, range));
    }
    return out;
  }

  static _CalDavResource _newestResource(List<_CalDavResource> resources) {
    var newest = resources.first;
    for (final resource in resources.skip(1)) {
      if (resource.isNewerThan(newest)) newest = resource;
    }
    return newest;
  }

  /// HTTP 207 означает лишь успех Multistatus целиком. Каждый
  /// response/propstat может быть 4xx/5xx. Неполный REPORT нельзя
  /// возвращать как fullWindow: reconcile принял бы недостающие
  /// ресурсы за remote delete и удалил бы их из кэша.
  static _CompleteCalendarResponse _completeCalendarResponse(XmlElement r) {
    final href = r
        .findElements('href', namespace: 'DAV:')
        .firstOrNull
        ?.innerText
        .trim();
    if (href == null || href.isEmpty) {
      throw const FormatException('CalDAV REPORT: response без href');
    }

    var hasStatus = false;
    final directStatuses = r.findElements('status', namespace: 'DAV:').toList();
    for (final status in directStatuses) {
      hasStatus = true;
      _requireSuccessfulDavStatus(status.innerText, href);
    }

    String? ics;
    String? etag;
    final propstats = r.findElements('propstat', namespace: 'DAV:').toList();
    for (final propstat in propstats) {
      final status = propstat
          .findElements('status', namespace: 'DAV:')
          .firstOrNull
          ?.innerText;
      if (status == null) {
        throw FormatException('CalDAV REPORT: propstat без status ($href)');
      }
      hasStatus = true;
      final code = _davStatusCode(status, href);
      final successful = code >= 200 && code < 300;
      final calendarData = propstat
          .findAllElements(
            'calendar-data',
            namespace: 'urn:ietf:params:xml:ns:caldav',
          )
          .toList();
      if (calendarData.isNotEmpty) {
        if (!successful) {
          throw FormatException(
            'CalDAV REPORT: calendar-data status $code ($href)',
          );
        }
        final value = calendarData.first.innerText;
        if (value.trim().isEmpty) {
          throw FormatException('CalDAV REPORT: пустой calendar-data ($href)');
        }
        ics ??= value;
      }
      if (successful) {
        etag ??= propstat
            .findAllElements('getetag', namespace: 'DAV:')
            .firstOrNull
            ?.innerText
            .trim();
      }
    }
    if (!hasStatus) {
      throw FormatException('CalDAV REPORT: response без status ($href)');
    }

    // Некоторые совместимые серверы кладут properties прямо в response.
    // Принимаем это только вместе с успешным direct status.
    if (ics == null && directStatuses.isNotEmpty) {
      final directCalendarData = r
          .findElements(
            'calendar-data',
            namespace: 'urn:ietf:params:xml:ns:caldav',
          )
          .firstOrNull
          ?.innerText;
      if (directCalendarData != null && directCalendarData.trim().isNotEmpty) {
        ics = directCalendarData;
      }
      etag ??= r
          .findElements('getetag', namespace: 'DAV:')
          .firstOrNull
          ?.innerText
          .trim();
    }
    if (ics == null || ics.trim().isEmpty) {
      throw FormatException(
        'CalDAV REPORT: successful response без calendar-data ($href)',
      );
    }
    return _CompleteCalendarResponse(href: href, etag: etag, ics: ics);
  }

  static int _davStatusCode(String value, String href) {
    final code = int.tryParse(
      RegExp(r'(?:^|\s)(\d{3})(?:\s|$)').firstMatch(value)?.group(1) ?? '',
    );
    if (code == null) {
      throw FormatException('CalDAV REPORT: invalid status $value ($href)');
    }
    return code;
  }

  static void _requireSuccessfulDavStatus(String value, String href) {
    final code = _davStatusCode(value, href);
    if (code < 200 || code >= 300) {
      throw FormatException('CalDAV REPORT: status $code ($href)');
    }
  }

  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  ) async {
    // CTag сохраняем для диагностики, но НЕ используем как
    // основание пропустить REPORT. Yandex может вернуть старое значение
    // после DELETE (фактически это max modified, а не надёжная версия
    // коллекции). Без полного окна SyncEngine не сможет удалить
    // локальный ресурс, исчезнувший в Windows/Yandex.
    final doc = await _propfind(
      _calHref(cal),
      0,
      '<d:propfind xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/"><d:prop><cs:getctag/></d:prop></d:propfind>',
    );
    final ctag = doc
        .findAllElements('getctag', namespace: 'http://calendarserver.org/ns/')
        .firstOrNull
        ?.innerText
        .trim();
    final now = DateTime.now().toUtc();
    final range = DateRange(
      now.subtract(const Duration(days: 90)),
      now.add(const Duration(days: 365)),
    );
    final events = await fetchEvents(acc, cal, range);
    return SyncResult(
      upserts: events,
      deletedIds: const [],
      newSyncState: ctag,
      fullWindow: range,
    );
  }

  // ───────── запись (CRUD) ─────────

  /// Путь ресурса .ics для события. Пришедший из REPORT href всегда
  /// имеет приоритет: имя CalDAV-ресурса не обязано совпадать с UID.
  /// Для нового/старого события без href строим best-effort путь из
  /// канонического UID, а не из локального `account:calendar:UID`.
  String _resourceHref(Calendar cal, CalendarEvent e, String uid) {
    final pid = e.source.providerEventId?.trim();
    if (pid != null && pid.isNotEmpty) {
      final uri = Uri.tryParse(pid);
      final absoluteHttp =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      if (pid.startsWith('/') || absoluteHttp) return pid;

      // Некоторые DAV-серверы возвращают только имя ресурса.
      if (!pid.contains('/') && pid.toLowerCase().endsWith('.ics')) {
        return '${_calendarDir(cal)}$pid';
      }
    }
    return '${_calendarDir(cal)}${Uri.encodeComponent(uid)}.ics';
  }

  String _calendarDir(Calendar cal) {
    final href = _calHref(cal);
    return href.endsWith('/') ? href : '$href/';
  }

  static bool _successfulStatus(int? status) =>
      status != null && status >= 200 && status < 300;

  static Options _requestOptions(
    String method, {
    Map<String, dynamic>? headers,
  }) => Options(
    method: method,
    headers: headers,
    validateStatus: _successfulStatus,
  );

  @override
  Future<CalendarEvent> createEvent(
    Account acc,
    Calendar cal,
    CalendarEvent e,
  ) async {
    final uid = _uidOf(acc, cal, e);
    final href = _resourceHref(cal, e, uid);
    late Response<dynamic> response;
    try {
      response = await _dio.requestUri(
        Uri.parse(_url(href)),
        data: _toIcs(e, uid),
        options: _requestOptions(
          'PUT',
          headers: {
            'Content-Type': 'text/calendar; charset=utf-8',
            'If-None-Match': '*',
          },
        ),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 412) rethrow;

      // PUT create идемпотентен по детерминированному href. Сервер мог успеть
      // сохранить ресурс, а клиент — потерять успешный ответ; тогда retry с
      // If-None-Match:* закономерно получает 412. Подтверждаем именно этот
      // ресурс и именно наш UID, прежде чем считать повтор успешным. Чужой
      // ресурс на том же href остаётся настоящим конфликтом.
      final existing = await _dio.requestUri(
        Uri.parse(_url(href)),
        options: _requestOptions('GET'),
      );
      final existingEvents = parseIcs(existing.data.toString());
      final ownsResource =
          existingEvents.isNotEmpty &&
          existingEvents.every((event) => event.uid.trim() == uid);
      if (!ownsResource) rethrow;
      response = existing;
    }
    // запоминаем href ресурса, чтобы update/delete били точно в него
    return e
        .withLocalId(_eventId(acc, cal, uid, e.recurrenceId))
        .copyWith(
          source: EventSource(
            accountId: acc.id,
            calendarId: cal.id,
            providerEventId: href,
            etag: response.headers.value('etag')?.trim() ?? e.source.etag,
          ),
        );
  }

  @override
  Future<CalendarEvent> updateEvent(Account acc, CalendarEvent e) async {
    final cal = _calOf(e);
    final uid = _uidOf(acc, cal, e);
    final href = _resourceHref(cal, e, uid);
    var body = _toIcs(e, uid);
    var etag = e.source.etag?.trim();

    // CalDAV хранит мастер и все RECURRENCE-ID exceptions в одном .ics.
    // Однокомпонентный PUT уничтожил бы RRULE/остальные исключения. Поэтому
    // повторяющееся событие сначала читаем целиком и заменяем ровно его
    // мастер либо один exception. Свежий GET ETag одновременно закрывает
    // гонку с изменением серии другим клиентом.
    if (e.isRecurring) {
      final existing = await _dio.requestUri(
        Uri.parse(_url(href)),
        options: _requestOptions('GET'),
      );
      body = _mergeRecurringUpdate(acc, cal, existing.data.toString(), e, uid);
      etag = existing.headers.value('etag')?.trim() ?? etag;
    }

    final response = await _dio.requestUri(
      Uri.parse(_url(href)),
      data: body,
      options: _requestOptions(
        'PUT',
        headers: {
          'Content-Type': 'text/calendar; charset=utf-8',
          if (etag != null && etag.isNotEmpty) 'If-Match': etag,
        },
      ),
    );
    return e
        .withLocalId(_eventId(acc, cal, uid, e.recurrenceId))
        .copyWith(
          source: EventSource(
            accountId: e.source.accountId,
            calendarId: e.calendarId,
            providerEventId: href,
            etag: response.headers.value('etag')?.trim() ?? e.source.etag,
          ),
        );
  }

  String _mergeRecurringUpdate(
    Account acc,
    Calendar cal,
    String ics,
    CalendarEvent updated,
    String canonicalUid,
  ) {
    final components = _rawVEvents(ics);
    final family = components
        .where(
          (component) =>
              _canonicalUid(acc, cal, component.event.uid) == canonicalUid,
        )
        .toList();
    if (family.isEmpty) {
      throw FormatException(
        'CalDAV update: ресурс не содержит UID $canonicalUid',
      );
    }

    _RawVEvent? target;
    if (updated.recurrenceId == null) {
      target = family.firstWhereOrNull(
        (component) =>
            component.event.recurrenceIdUtc == null &&
            component.event.rrule != null,
      );
      if (target == null) {
        throw const FormatException(
          'CalDAV update: мастер повторяющейся серии не найден',
        );
      }
    } else {
      final recurrenceMillis = int.tryParse(updated.recurrenceId!);
      if (recurrenceMillis == null) {
        throw UnsupportedError(
          'CalDAV update: неизвестный RECURRENCE-ID ${updated.recurrenceId}',
        );
      }
      target = family.firstWhereOrNull(
        (component) =>
            component.event.recurrenceIdUtc?.millisecondsSinceEpoch ==
            recurrenceMillis,
      );

      // Первое редактирование экземпляра создаёт новый exception рядом с
      // мастером. Повторное — заменяет exception с тем же RECURRENCE-ID.
      if (target == null) {
        final master = family.firstWhereOrNull(
          (component) =>
              component.event.recurrenceIdUtc == null &&
              component.event.rrule != null,
        );
        if (master == null) {
          throw const FormatException(
            'CalDAV update: серия для нового exception не найдена',
          );
        }
        return _insertVEvent(ics, _toVEvent(updated, master.event.uid));
      }
    }

    final replacement = _mergeVEventFields(
      target.match.group(0)!,
      updated,
      target.event.uid,
    );
    return ics.replaceRange(target.match.start, target.match.end, replacement);
  }

  /// Обновляет только поля, которыми владеет редактор Calenfi, сохраняя
  /// остальные top-level свойства и вложенные компоненты исходного VEVENT.
  /// В частности, EXDATE/RDATE и VALARM нельзя терять при редактировании
  /// мастера: иначе ранее исключённые экземпляры воскреснут после PUT.
  String _mergeVEventFields(
    String existing,
    CalendarEvent updated,
    String remoteUid,
  ) {
    const replacedProperties = {
      'DTSTAMP',
      'SEQUENCE',
      'DTSTART',
      'DTEND',
      'SUMMARY',
      'RRULE',
      'LOCATION',
      'DESCRIPTION',
      'ORGANIZER',
      'ATTENDEE',
    };
    final eol = existing.contains('\r\n') ? '\r\n' : '\n';
    final blocks = _logicalPropertyBlocks(existing, eol);
    final kept = <String>[];
    var nestedDepth = 0;
    for (final block in blocks) {
      final unfolded = block.replaceAll(RegExp(r'\r?\n[ \t]'), '');
      final name = _propertyName(unfolded);
      final value = _propertyValue(unfolded).toUpperCase();
      if (name == 'BEGIN' && value != 'VEVENT') {
        nestedDepth++;
        kept.add(block);
        continue;
      }
      if (name == 'END' && value != 'VEVENT') {
        kept.add(block);
        if (nestedDepth > 0) nestedDepth--;
        continue;
      }
      if (nestedDepth == 0 && replacedProperties.contains(name)) continue;
      kept.add(block);
    }

    final generated = _toVEvent(updated, remoteUid)
        .split(RegExp(r'\r?\n'))
        .where((line) {
          final name = _propertyName(line);
          return replacedProperties.contains(name);
        })
        .toList();
    final uidIndex = kept.indexWhere((block) => _propertyName(block) == 'UID');
    if (uidIndex < 0) {
      throw const FormatException('CalDAV update: VEVENT без UID');
    }
    kept.insertAll(uidIndex + 1, generated);
    return kept.join(eol);
  }

  static List<String> _logicalPropertyBlocks(String component, String eol) {
    final physical = component.split(RegExp(r'\r?\n'));
    final blocks = <String>[];
    for (final line in physical) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          blocks.isNotEmpty) {
        blocks[blocks.length - 1] = '${blocks.last}$eol$line';
      } else {
        blocks.add(line);
      }
    }
    return blocks;
  }

  static String _propertyName(String line) {
    final colon = line.indexOf(':');
    final semicolon = line.indexOf(';');
    final int end;
    if (colon < 0) {
      end = semicolon < 0 ? line.length : semicolon;
    } else if (semicolon < 0) {
      end = colon;
    } else {
      end = colon < semicolon ? colon : semicolon;
    }
    return line.substring(0, end).toUpperCase();
  }

  static String _propertyValue(String line) {
    final colon = line.indexOf(':');
    return colon < 0 ? '' : line.substring(colon + 1).trim();
  }

  static List<_RawVEvent> _rawVEvents(String ics) {
    final pattern = RegExp(
      r'BEGIN:VEVENT(?:\r?\n)[\s\S]*?END:VEVENT',
      caseSensitive: false,
    );
    final result = <_RawVEvent>[];
    for (final match in pattern.allMatches(ics)) {
      final parsed = parseIcs(
        'BEGIN:VCALENDAR\r\n${match.group(0)!}\r\nEND:VCALENDAR',
      );
      if (parsed.length == 1) {
        result.add(_RawVEvent(match: match, event: parsed.single));
      }
    }
    return result;
  }

  static String _insertVEvent(String ics, String component) {
    final ends = RegExp(
      r'^END:VCALENDAR\s*$',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(ics).toList();
    if (ends.isEmpty) {
      throw const FormatException('CalDAV update: END:VCALENDAR не найден');
    }
    final end = ends.last;
    final eol = ics.contains('\r\n') ? '\r\n' : '\n';
    final normalized = component.replaceAll(RegExp(r'\r?\n'), eol);
    final prefix = ics.substring(0, end.start);
    final separator = prefix.endsWith('\n') ? '' : eol;
    return '$prefix$separator$normalized$eol${ics.substring(end.start)}';
  }

  @override
  Future<void> deleteEvent(
    Account acc,
    CalendarEvent e,
    RecurrenceScope scope,
  ) async {
    final cal = _calOf(e);
    final uid = _uidOf(acc, cal, e);
    final href = _resourceHref(cal, e, uid);
    final url = _url(href);
    // Вся серия или не повтор → удаляем всю legacy-семью UID.
    if (scope == RecurrenceScope.all || e.recurrenceRule == null) {
      await _deleteUidFamily(acc, cal, e, uid, href);
      return;
    }
    // Один экземпляр / это-и-последующие → правим мастер-VEVENT и кладём назад.
    final resp = await _dio.requestUri(
      Uri.parse(url),
      options: _requestOptions('GET'),
    );
    var ics = resp.data.toString();
    final occ = e.startUtc.toUtc();
    ics = scope == RecurrenceScope.thisOnly
        ? _addExdate(ics, occ) // исключаем один экземпляр
        : _setRruleUntil(ics, occ.subtract(const Duration(seconds: 1)));
    final etag = resp.headers.value('etag')?.trim() ?? e.source.etag?.trim();
    await _dio.requestUri(
      Uri.parse(url),
      data: ics,
      options: _requestOptions(
        'PUT',
        headers: {
          'Content-Type': 'text/calendar; charset=utf-8',
          if (etag != null && etag.isNotEmpty) 'If-Match': etag,
        },
      ),
    );
  }

  /// Legacy-версии Calenfi могли записать одну встречу в
  /// несколько .ics-ресурсов, каждый раз добавляя к UID ещё один
  /// `account:calendar:`. Pull намеренно показывает только новейшую
  /// копию; удаление только её href дало бы старой копии «воскреснуть».
  ///
  /// Поэтому перед мутацией делаем REPORT по UID без time-range и
  /// удаляем все ресурсы, чей UID сводится к тому же каноническому
  /// значению. Это работает и в свежем provider до первого pull.
  Future<void> _deleteUidFamily(
    Account acc,
    Calendar cal,
    CalendarEvent event,
    String uid,
    String primaryHref,
  ) async {
    final discovered = await _discoverUidFamily(acc, cal, uid);
    final primaryUrl = _url(primaryHref);
    final byUrl = <String, _CalDavDeleteTarget>{};
    var primaryWasDiscovered = false;

    for (final target in discovered) {
      final targetUrl = _url(target.href);
      if (targetUrl == primaryUrl) primaryWasDiscovered = true;
      final old = byUrl[targetUrl];
      if (old == null || (old.etag == null && target.etag != null)) {
        byUrl[targetUrl] = target;
      }
    }

    // REPORT может не увидеть только что созданный ресурс
    // из-за eventual consistency. Сохранённый href всё равно удаляем.
    byUrl.putIfAbsent(
      primaryUrl,
      () => _CalDavDeleteTarget(
        href: primaryHref,
        etag: event.source.etag?.trim(),
        legacyDepth: 0,
      ),
    );

    // Сначала старые копии, победитель pull — последним. Если
    // промежуточный DELETE получит 412, актуальная копия останется
    // видимой, а outbox безопасно повторит всю операцию.
    final targets = byUrl.entries.toList()
      ..sort((a, b) {
        final aPrimary = a.key == primaryUrl;
        final bPrimary = b.key == primaryUrl;
        if (aPrimary != bPrimary) return aPrimary ? 1 : -1;
        if (a.value.legacyDepth != b.value.legacyDepth) {
          return b.value.legacyDepth.compareTo(a.value.legacyDepth);
        }
        return a.key.compareTo(b.key);
      });

    for (final entry in targets) {
      final etag = entry.value.etag?.trim();
      final primaryMissingBeforeDelete =
          entry.key == primaryUrl && !primaryWasDiscovered;
      await _dio.requestUri(
        Uri.parse(entry.key),
        options: Options(
          method: 'DELETE',
          headers: {if (etag != null && etag.isNotEmpty) 'If-Match': etag},
          validateStatus: (status) =>
              _successfulStatus(status) ||
              (primaryMissingBeforeDelete && (status == 404 || status == 410)),
        ),
      );
    }
  }

  Future<List<_CalDavDeleteTarget>> _discoverUidFamily(
    Account acc,
    Calendar cal,
    String uid,
  ) async {
    // RFC 4791 §9.7.5: text-match — substring match. Значит чистый
    // UID найдёт и raw UID, и UID с любым числом legacy-префиксов.
    final escapedUid = XmlText(uid).toXmlString();
    final body =
        '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
        '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
        '<c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">'
        '<c:prop-filter name="UID"><c:text-match collation="i;octet">'
        '$escapedUid</c:text-match></c:prop-filter>'
        '</c:comp-filter></c:comp-filter></c:filter></c:calendar-query>';
    final response = await _dio.requestUri(
      Uri.parse(_url(_calHref(cal))),
      data: body,
      options: _requestOptions('REPORT', headers: {'Depth': '1'}),
    );
    final doc = XmlDocument.parse(response.data.toString());
    final targets = <_CalDavDeleteTarget>[];

    for (final element in doc.findAllElements('response', namespace: 'DAV:')) {
      final parsed = _completeCalendarResponse(element);
      final events = parseIcs(parsed.ics);
      if (events.isEmpty || events.any((event) => event.uid.trim().isEmpty)) {
        throw FormatException(
          'CalDAV delete discovery: invalid VEVENT (${parsed.href})',
        );
      }
      final canonicalUids = events
          .map((event) => _canonicalUid(acc, cal, event.uid))
          .toSet();
      if (!canonicalUids.contains(uid)) continue;
      if (canonicalUids.length != 1) {
        throw FormatException(
          'CalDAV delete discovery: resource mixes UID families '
          '(${parsed.href})',
        );
      }
      targets.add(
        _CalDavDeleteTarget(
          href: parsed.href,
          etag: parsed.etag,
          legacyDepth: events
              .map((event) => _legacyPrefixDepth(acc, cal, event.uid))
              .fold(0, (a, b) => a > b ? a : b),
        ),
      );
    }
    return targets;
  }

  static String _icsStamp(DateTime d) {
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    final u = d.toUtc();
    return '${p(u.year, 4)}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
  }

  /// Добавляет EXDATE сразу после строки RRULE (внутри мастер-VEVENT).
  static String _addExdate(String ics, DateTime occ) {
    final m = RegExp(r'^RRULE:.*$', multiLine: true).firstMatch(ics);
    if (m == null) return ics;
    return '${ics.substring(0, m.end)}\r\nEXDATE:${_icsStamp(occ)}${ics.substring(m.end)}';
  }

  /// Ставит UNTIL в RRULE (убирая конфликтующие UNTIL/COUNT).
  static String _setRruleUntil(String ics, DateTime until) {
    final u = _icsStamp(until);
    return ics.replaceAllMapped(RegExp(r'^RRULE:(.*)$', multiLine: true), (m) {
      final parts =
          m
              .group(1)!
              .split(';')
              .where(
                (p) =>
                    p.isNotEmpty &&
                    !p.toUpperCase().startsWith('UNTIL') &&
                    !p.toUpperCase().startsWith('COUNT'),
              )
              .toList()
            ..add('UNTIL=$u');
      return 'RRULE:${parts.join(';')}';
    });
  }

  @override
  Future<void> respondToInvite(
    Account acc,
    CalendarEvent e,
    ResponseStatus r,
  ) async {
    throw UnsupportedError('RSVP по CalDAV не поддержан в MVP (FR-R4)');
  }

  // ───────── helpers ─────────

  Calendar _calOf(CalendarEvent e) => Calendar(
    id: e.calendarId,
    accountId: e.source.accountId,
    name: '',
    color: 0,
  );

  Future<XmlDocument> _propfind(String path, int depth, String body) async {
    final resp = await _dio.requestUri(
      Uri.parse(_url(path)),
      data: body,
      options: _requestOptions('PROPFIND', headers: {'Depth': '$depth'}),
    );
    return XmlDocument.parse(resp.data.toString());
  }

  /// Разворачивает мастер и накладывает серверные RECURRENCE-ID exceptions.
  /// Без overlay перенесённый экземпляр появлялся дважды: старое время снова
  /// генерировалось из RRULE, а exception терял свой стабильный локальный id.
  List<CalendarEvent> _expandResource(
    Account acc,
    Calendar cal,
    _CalDavResource resource,
    DateRange range,
  ) {
    final master = resource.events.firstWhereOrNull(
      (event) =>
          event.recurrenceIdUtc == null &&
          event.rrule != null &&
          event.rrule!.isNotEmpty,
    );
    if (master == null) {
      return [
        for (final event in resource.events)
          if (_overlaps(event.startUtc, event.endUtc, range))
            _build(
              acc,
              cal,
              event,
              resource.href,
              resource.etag,
              event.startUtc,
              event.endUtc,
              event.recurrenceIdUtc?.millisecondsSinceEpoch.toString(),
            ),
      ];
    }

    final expanded = _expand(
      acc,
      cal,
      master,
      resource.href,
      resource.etag,
      range,
    );
    final byRecurrenceId = <String, CalendarEvent>{
      for (final event in expanded)
        if (event.recurrenceId != null) event.recurrenceId!: event,
    };
    final withoutStableId = expanded
        .where((event) => event.recurrenceId == null)
        .toList();

    for (final exception in resource.events.where(
      (event) => event.recurrenceIdUtc != null,
    )) {
      final recurrenceId = exception.recurrenceIdUtc!.millisecondsSinceEpoch
          .toString();
      // Удаляем сгенерированное старое время даже если exception был перенесён
      // за пределы окна либо отменён.
      byRecurrenceId.remove(recurrenceId);
      if (!_overlaps(exception.startUtc, exception.endUtc, range)) continue;
      byRecurrenceId[recurrenceId] = _build(
        acc,
        cal,
        exception,
        resource.href,
        resource.etag,
        exception.startUtc,
        exception.endUtc,
        recurrenceId,
        recurrenceRule: master.rrule,
      );
    }

    final result = [...withoutStableId, ...byRecurrenceId.values]
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return result;
  }

  static bool _overlaps(DateTime start, DateTime end, DateRange range) =>
      end.isAfter(range.startUtc) && start.isBefore(range.endUtc);

  /// Разворачивает VEVENT в экземпляры внутри [range] (повторы RRULE, FR-E6).
  List<CalendarEvent> _expand(
    Account acc,
    Calendar cal,
    VEvent v,
    String href,
    String? etag,
    DateRange range,
  ) {
    if (v.rrule == null || v.rrule!.isEmpty) {
      return [_build(acc, cal, v, href, etag, v.startUtc, v.endUtc, null)];
    }
    try {
      final duration = v.endUtc.difference(v.startUtc);
      final rule = RecurrenceRule.fromString('RRULE:${v.rrule}');
      final start = v.startUtc.isUtc ? v.startUtc : v.startUtc.toUtc();
      final excluded = v.exdatesUtc
          .map((date) => date.toUtc().millisecondsSinceEpoch)
          .toSet();
      final result = <CalendarEvent>[];
      for (final occ in rule.getInstances(start: start)) {
        if (occ.isAfter(range.endUtc)) break;
        if (excluded.contains(occ.toUtc().millisecondsSinceEpoch)) continue;
        final occEnd = occ.add(duration);
        if (occEnd.isBefore(range.startUtc)) continue;
        result.add(
          _build(
            acc,
            cal,
            v,
            href,
            etag,
            occ,
            occEnd,
            occ.millisecondsSinceEpoch.toString(),
          ),
        );
        if (result.length > 500) break;
      }
      return result;
    } catch (_) {
      return [_build(acc, cal, v, href, etag, v.startUtc, v.endUtc, null)];
    }
  }

  /// Короткий стабильный токен календаря для id события: последний непустой
  /// сегмент пути (напр. `events-10922764`). Нужен, чтобы id был УНИКАЛЕН per
  /// календарь: CalDAV-сервер (Яндекс) кладёт одно приглашение с одним UID в
  /// НЕСКОЛЬКО коллекций (основной календарь + календарь переговорки). Раньше
  /// id был `acc:UID` — одна строка на все копии, и copy из скрытого календаря
  /// перезаписывала копию из видимого → событие «пропадало» из сетки.
  /// Теперь копии сосуществуют (склейка дублей объединяет их в UI), а
  /// видимость календаря фильтрует каждую копию отдельно.
  static String _calToken(Calendar cal) {
    final segs = cal.id.split('/').where((s) => s.isNotEmpty);
    return segs.isEmpty ? cal.id : segs.last;
  }

  static String _eventPrefix(Account acc, Calendar cal) =>
      '${acc.id}:${_calToken(cal)}:';

  /// Снимает точный Calenfi-префик account+calendar, а также
  /// более старый account-only префик. Account-only форму снимаем,
  /// если остаток не похож на calendar-scoped UID из другой коллекции.
  /// Это сохраняет межкалендарную уникальность и мигрирует ID версий,
  /// где локальный ключ был `account:UID`.
  static String _canonicalUid(Account acc, Calendar cal, String value) {
    var uid = value.trim();
    while (true) {
      final stripped = _stripLegacyPrefix(acc, cal, uid);
      if (stripped == null) break;
      uid = stripped;
    }
    return uid;
  }

  static int _legacyPrefixDepth(Account acc, Calendar cal, String value) {
    var uid = value.trim();
    var depth = 0;
    while (true) {
      final stripped = _stripLegacyPrefix(acc, cal, uid);
      if (stripped == null) break;
      uid = stripped;
      depth++;
    }
    return depth;
  }

  static String? _stripLegacyPrefix(Account acc, Calendar cal, String value) {
    final scopedPrefix = _eventPrefix(acc, cal);
    if (value.length > scopedPrefix.length && value.startsWith(scopedPrefix)) {
      return value.substring(scopedPrefix.length);
    }

    final accountPrefix = '${acc.id}:';
    if (value.length <= accountPrefix.length ||
        !value.startsWith(accountPrefix)) {
      return null;
    }
    final remainder = value.substring(accountPrefix.length);

    // `account:other-calendar:UID` — не account-only legacy, а чужой
    // calendar-scoped UID. Повторённый `account:account:UID`
    // однозначно legacy и должен схлопнуться.
    if (remainder.contains(':') && !remainder.startsWith(accountPrefix)) {
      return null;
    }
    return remainder;
  }

  static String _eventId(
    Account acc,
    Calendar cal,
    String uid,
    String? recurrenceId,
  ) {
    final canonical = _canonicalUid(acc, cal, uid);
    return '${_eventPrefix(acc, cal)}$canonical'
        '${recurrenceId != null ? ':$recurrenceId' : ''}';
  }

  static String _uidOf(Account acc, Calendar cal, CalendarEvent e) {
    var candidate = e.id;
    final recurrenceId = e.recurrenceId;
    if (recurrenceId != null) {
      final suffix = ':$recurrenceId';
      if (candidate.endsWith(suffix)) {
        candidate = candidate.substring(0, candidate.length - suffix.length);
      }
    }
    return _canonicalUid(acc, cal, candidate);
  }

  /// Открытая обёртка [_build] для тестов (регресс календарно-скоупных id).
  @visibleForTesting
  CalendarEvent buildEventForTest(Account acc, Calendar cal, VEvent v) =>
      _build(acc, cal, v, 'href', null, v.startUtc, v.endUtc, null);

  CalendarEvent _build(
    Account acc,
    Calendar cal,
    VEvent v,
    String href,
    String? etag,
    DateTime start,
    DateTime end,
    String? recurrenceId, {
    String? recurrenceRule,
  }) {
    final myEmail = acc.email.toLowerCase();
    final mine = v.attendees
        .where((a) => a.email.toLowerCase() == myEmail)
        .firstOrNull;
    final response = v.organizerEmail?.toLowerCase() == myEmail
        ? ResponseStatus.organizer
        : _partstat(mine?.partstat);
    final status = switch (v.status) {
      'CANCELLED' => EventStatus.cancelled,
      'TENTATIVE' => EventStatus.tentative,
      _ => EventStatus.confirmed,
    };
    return CalendarEvent(
      id: _eventId(acc, cal, v.uid, recurrenceId),
      calendarId: cal.id,
      title: v.summary,
      startUtc: start,
      endUtc: end,
      timeZoneId: v.timeZoneId,
      allDay: v.allDay,
      location: v.location,
      description: v.description,
      recurrenceRule: recurrenceRule ?? v.rrule,
      recurrenceId: recurrenceId,
      attendees: v.attendees
          .map(
            (a) => Attendee(
              email: a.email,
              response: _partstat(a.partstat),
              isOrganizer:
                  a.email.toLowerCase() == v.organizerEmail?.toLowerCase(),
              isResource: a.cutype == 'ROOM' || a.cutype == 'RESOURCE',
            ),
          )
          .toList(),
      myResponse: response,
      status: status,
      webUrl: v.url,
      source: EventSource(
        accountId: acc.id,
        calendarId: cal.id,
        providerEventId: href,
        etag: etag,
      ),
    );
  }

  static String _partstatIcs(ResponseStatus r) => switch (r) {
    ResponseStatus.accepted => 'ACCEPTED',
    ResponseStatus.declined => 'DECLINED',
    ResponseStatus.tentative => 'TENTATIVE',
    _ => 'NEEDS-ACTION',
  };

  static ResponseStatus _partstat(String? p) => switch (p) {
    'ACCEPTED' => ResponseStatus.accepted,
    'DECLINED' => ResponseStatus.declined,
    'TENTATIVE' => ResponseStatus.tentative,
    _ => ResponseStatus.needsAction,
  };

  String _toIcs(CalendarEvent e, String uid) =>
      'BEGIN:VCALENDAR\n'
      'VERSION:2.0\n'
      'PRODID:-//Calenfi//EN\n'
      '${_toVEvent(e, uid)}\n'
      'END:VCALENDAR\n';

  String _toVEvent(CalendarEvent e, String uid) {
    // SEQUENCE должен расти при каждом PUT, иначе Yandex игнорирует изменения.
    final seq = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final buf = StringBuffer()
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid')
      ..writeln('DTSTAMP:${_z(DateTime.now())}')
      ..writeln('SEQUENCE:$seq');
    final recurrenceId = e.recurrenceId;
    if (recurrenceId != null) {
      final millis = int.tryParse(recurrenceId);
      if (millis == null) {
        throw UnsupportedError(
          'CalDAV update: неизвестный RECURRENCE-ID $recurrenceId',
        );
      }
      buf.writeln(
        'RECURRENCE-ID:${_z(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true))}',
      );
    }
    buf
      ..writeln('DTSTART:${_z(e.startUtc)}')
      ..writeln('DTEND:${_z(e.endUtc)}')
      ..writeln('SUMMARY:${_esc(e.title)}');
    // Повторяющаяся серия (FR-E6). RRULE только у мастера, не у экземпляров.
    if (e.recurrenceRule != null && e.recurrenceId == null) {
      buf.writeln('RRULE:${e.recurrenceRule}');
    }
    if (e.location != null) buf.writeln('LOCATION:${_esc(e.location!)}');
    // Кросс-аккаунтная конференция (Teams/Meet/Zoom/Telemost) встраивается в
    // описание — CalDAV сам конференции не заводит.
    final description = descriptionWithConference(e.description, e.conference);
    if (description != null) buf.writeln('DESCRIPTION:${_esc(description)}');
    // Yandex принимает участников только с ORGANIZER и полными параметрами ATTENDEE.
    if (e.attendees.isNotEmpty) {
      buf.writeln(
        'ORGANIZER;CN=${_esc(account.email)}:mailto:${account.email}',
      );
      for (final a in e.attendees) {
        final cn = a.displayName != null ? ';CN=${_esc(a.displayName!)}' : '';
        if (a.isResource) {
          // Переговорка: ресурс-участник, комната сама подтверждает бронь.
          buf.writeln(
            'ATTENDEE;ROLE=NON-PARTICIPANT;CUTYPE=ROOM;PARTSTAT=${_partstatIcs(a.response)};RSVP=FALSE$cn:mailto:${a.email}',
          );
        } else {
          buf.writeln(
            'ATTENDEE;ROLE=REQ-PARTICIPANT;CUTYPE=INDIVIDUAL;PARTSTAT=${_partstatIcs(a.response)};RSVP=TRUE$cn:mailto:${a.email}',
          );
        }
      }
    }
    buf.write('END:VEVENT');
    return buf.toString();
  }

  static String _esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');

  static String _z(DateTime d) =>
      '${d.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';

  static int _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return 0xFF7E57C2;
    var h = hex.substring(1);
    if (h.length == 8) {
      h = h.substring(6) + h.substring(0, 6); // RRGGBBAA→AARRGGBB? нет
    }
    if (h.length >= 6) {
      final rgb = int.tryParse(h.substring(0, 6), radix: 16);
      if (rgb != null) return 0xFF000000 | rgb;
    }
    return 0xFF7E57C2;
  }
}
