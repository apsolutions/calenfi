import 'package:timezone/timezone.dart' as tz;

/// Разобранное VEVENT (нейтральная структура, маппится в CalendarEvent в адаптере).
class VEvent {
  VEvent({
    required this.uid,
    required this.summary,
    required this.startUtc,
    required this.endUtc,
    required this.allDay,
    this.location,
    this.description,
    this.status,
    this.rrule,
    this.recurrenceIdUtc,
    this.exdatesUtc = const [],
    this.organizerEmail,
    this.attendees = const [],
    this.timeZoneId = 'UTC',
    this.url,
    this.telemostConferenceUrl,
    this.sequence,
    this.dtStampUtc,
    this.lastModifiedUtc,
  });

  final String uid;
  final String summary;
  final DateTime startUtc;
  final DateTime endUtc;
  final bool allDay;
  final String? location;
  final String? description;
  final String? status; // CONFIRMED | TENTATIVE | CANCELLED
  final String? rrule;

  /// Исходное время экземпляра серии из `RECURRENCE-ID`.
  ///
  /// Оно не обязано совпадать с [startUtc]: после переноса exception сохраняет
  /// старый RECURRENCE-ID, а DTSTART содержит новое время. Именно этот штамп
  /// служит стабильным ключом экземпляра при следующем pull.
  final DateTime? recurrenceIdUtc;

  /// Исключённые RRULE-вхождения из всех строк EXDATE мастера.
  final List<DateTime> exdatesUtc;
  final String? organizerEmail;
  final List<IcsAttendee> attendees;
  final String timeZoneId;

  /// Web-ссылка на событие (Yandex кладёт сюда calendar.yandex.ru/event?...).
  final String? url;

  /// Yandex CalDAV extension populated after the server creates Telemost.
  final String? telemostConferenceUrl;

  /// Поля версии RFC 5545. Нужны для детерминированного выбора
  /// новейшей копии, если legacy-баг создал на сервере несколько
  /// ресурсов одной UID-семьи.
  final int? sequence;
  final DateTime? dtStampUtc;
  final DateTime? lastModifiedUtc;
}

class IcsAttendee {
  IcsAttendee(this.email, this.partstat, this.role, {this.cutype});
  final String email;
  final String? partstat; // ACCEPTED | DECLINED | TENTATIVE | NEEDS-ACTION
  final String? role;
  final String? cutype; // INDIVIDUAL | ROOM | RESOURCE — ROOM = переговорка
}

/// Минимальный парсер iCalendar: разворачивает все VEVENT из одного объекта.
/// Поддерживает UTC (Z), TZID и VALUE=DATE (all-day). Свёрнутые строки (RFC 5545)
/// разворачиваются.
List<VEvent> parseIcs(String ics) {
  final lines = _unfold(ics);
  final events = <VEvent>[];

  Map<String, _Prop>? cur;
  final attendees = <IcsAttendee>[];
  final exdates = <DateTime>[];
  for (final line in lines) {
    if (line == 'BEGIN:VEVENT') {
      cur = {};
      attendees.clear();
      exdates.clear();
    } else if (line == 'END:VEVENT') {
      if (cur != null) {
        final e = _build(cur, List.of(attendees), List.of(exdates));
        if (e != null) events.add(e);
      }
      cur = null;
    } else if (cur != null) {
      final prop = _Prop.parse(line);
      if (prop == null) continue;
      if (prop.name == 'ATTENDEE') {
        attendees.add(
          IcsAttendee(
            _mailto(prop.value),
            prop.params['PARTSTAT'],
            prop.params['ROLE'],
            cutype: prop.params['CUTYPE'],
          ),
        );
      } else if (prop.name == 'EXDATE') {
        for (final value in prop.value.split(',')) {
          try {
            exdates.add(_parseDate(_Prop(prop.name, value, prop.params)));
          } catch (_) {
            // Одна битая дата не должна скрывать весь VEVENT.
          }
        }
      } else {
        cur[prop.name] = prop;
      }
    }
  }
  return events;
}

VEvent? _build(
  Map<String, _Prop> p,
  List<IcsAttendee> attendees,
  List<DateTime> exdates,
) {
  final dtstart = p['DTSTART'];
  if (dtstart == null) return null;
  final allDay = dtstart.params['VALUE'] == 'DATE';
  final start = _parseDate(dtstart);
  final dtend = p['DTEND'];
  final end = dtend != null
      ? _parseDate(dtend)
      : start.add(allDay ? const Duration(days: 1) : const Duration(hours: 1));

  return VEvent(
    uid: p['UID']?.value ?? '',
    summary: _unescape(p['SUMMARY']?.value) ?? '(без названия)',
    startUtc: start,
    endUtc: end,
    allDay: allDay,
    location: _unescape(p['LOCATION']?.value),
    description: _unescape(p['DESCRIPTION']?.value),
    status: p['STATUS']?.value,
    rrule: p['RRULE']?.value,
    recurrenceIdUtc: _tryParseDate(p['RECURRENCE-ID']),
    exdatesUtc: exdates,
    organizerEmail: p['ORGANIZER'] != null
        ? _mailto(p['ORGANIZER']!.value)
        : null,
    attendees: attendees,
    timeZoneId: dtstart.params['TZID'] ?? 'UTC',
    url: p['URL']?.value.trim(),
    telemostConferenceUrl: p['X-TELEMOST-CONFERENCE']?.value.trim(),
    sequence: int.tryParse(p['SEQUENCE']?.value.trim() ?? ''),
    dtStampUtc: _tryParseDate(p['DTSTAMP']),
    lastModifiedUtc: _tryParseDate(p['LAST-MODIFIED']),
  );
}

DateTime? _tryParseDate(_Prop? p) {
  if (p == null) return null;
  try {
    return _parseDate(p);
  } catch (_) {
    return null;
  }
}

DateTime _parseDate(_Prop p) {
  final v = p.value.trim();
  // all-day: YYYYMMDD
  if (p.params['VALUE'] == 'DATE' || (v.length == 8 && !v.contains('T'))) {
    final y = int.parse(v.substring(0, 4));
    final m = int.parse(v.substring(4, 6));
    final d = int.parse(v.substring(6, 8));
    return DateTime.utc(y, m, d);
  }
  final isUtc = v.endsWith('Z');
  final s = isUtc ? v.substring(0, v.length - 1) : v;
  final y = int.parse(s.substring(0, 4));
  final mo = int.parse(s.substring(4, 6));
  final d = int.parse(s.substring(6, 8));
  final h = int.parse(s.substring(9, 11));
  final mi = int.parse(s.substring(11, 13));
  final se = s.length >= 15 ? int.parse(s.substring(13, 15)) : 0;

  if (isUtc) return DateTime.utc(y, mo, d, h, mi, se);

  final tzid = p.params['TZID'];
  if (tzid != null) {
    try {
      final loc = tz.getLocation(_normalizeTz(tzid));
      return tz.TZDateTime(loc, y, mo, d, h, mi, se).toUtc();
    } catch (_) {
      // неизвестная зона — трактуем как локальную
    }
  }
  return DateTime(y, mo, d, h, mi, se).toUtc();
}

String _normalizeTz(String tzid) {
  // некоторые серверы отдают "Russia TZ 2 Standard Time" — оставляем как есть,
  // tz.getLocation бросит, и сработает фолбэк.
  return tzid;
}

String _mailto(String v) =>
    v.toLowerCase().startsWith('mailto:') ? v.substring(7) : v;

String? _unescape(String? v) => v
    ?.replaceAll(r'\n', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', '\\');

List<String> _unfold(String ics) {
  final raw = ics.split(RegExp(r'\r?\n'));
  final out = <String>[];
  for (final line in raw) {
    if (line.isEmpty) continue;
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.isNotEmpty) {
      out[out.length - 1] = out.last + line.substring(1);
    } else {
      out.add(line);
    }
  }
  return out;
}

class _Prop {
  _Prop(this.name, this.value, this.params);
  final String name;
  final String value;
  final Map<String, String> params;

  static _Prop? parse(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return null;
    final left = line.substring(0, colon);
    final value = line.substring(colon + 1);
    final parts = left.split(';');
    final name = parts.first.toUpperCase();
    final params = <String, String>{};
    for (final p in parts.skip(1)) {
      final eq = p.indexOf('=');
      if (eq > 0) {
        params[p.substring(0, eq).toUpperCase()] = p.substring(eq + 1);
      }
    }
    return _Prop(name, value, params);
  }
}
