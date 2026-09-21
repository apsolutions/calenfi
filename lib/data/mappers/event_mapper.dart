import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/attendee.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/attachment.dart';
import '../../domain/models/conference.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/reminder.dart';
import '../../services/conference_parser.dart';
import '../local/db/database.dart';

/// Маппинг между строкой Drift [Event] и доменной [CalendarEvent].
///
/// Участники / конференция / напоминания денормализованы в JSON-колонки
/// (см. docs/architecture.md §14).
class EventMapper {
  const EventMapper();

  static const _conferenceParser = ConferenceParser();

  CalendarEvent toDomain(Event r) {
    // Видеовстреча: явно сохранённая, иначе — распознанная из текста (FR-M1),
    // чтобы кнопка «Присоединиться» появлялась даже когда ссылка в описании.
    final conference =
        _decodeConference(r.conferenceJson) ??
        _conferenceParser.detect(
          location: r.location,
          description: r.description,
        );
    return CalendarEvent(
      id: r.id,
      calendarId: r.calendarId,
      title: r.title,
      startUtc: r.startUtc,
      endUtc: r.endUtc,
      timeZoneId: r.timeZoneId,
      allDay: r.allDay,
      location: r.location,
      description: r.description,
      recurrenceRule: r.recurrenceRule,
      recurrenceId: r.recurrenceId,
      attendees: _decodeAttendees(r.attendeesJson),
      myResponse: r.myResponse,
      showAs: r.showAs,
      visibility: r.visibility,
      reminders: _decodeReminders(r.remindersJson),
      attachments: _decodeAttachments(r.attachmentsJson),
      conference: conference,
      source: EventSource(
        accountId: r.accountId,
        calendarId: r.calendarId,
        providerEventId: r.providerEventId,
        etag: r.etag,
      ),
      status: r.status,
      deletedRemotely: r.deletedRemotely,
      colorOverride: r.colorOverride,
      mergedGroupId: r.mergedGroupId,
      webUrl: r.webUrl,
    );
  }

  EventsCompanion toCompanion(CalendarEvent e, {bool dirty = false}) {
    return EventsCompanion(
      id: Value(e.id),
      calendarId: Value(e.calendarId),
      accountId: Value(e.source.accountId),
      providerEventId: Value(e.source.providerEventId),
      etag: Value(e.source.etag),
      title: Value(e.title),
      startUtc: Value(e.startUtc),
      endUtc: Value(e.endUtc),
      timeZoneId: Value(e.timeZoneId),
      allDay: Value(e.allDay),
      location: Value(e.location),
      description: Value(e.description),
      recurrenceRule: Value(e.recurrenceRule),
      recurrenceId: Value(e.recurrenceId),
      myResponse: Value(e.myResponse),
      showAs: Value(e.showAs),
      visibility: Value(e.visibility),
      status: Value(e.status),
      deletedRemotely: Value(e.deletedRemotely),
      colorOverride: Value(e.colorOverride),
      mergedGroupId: Value(e.mergedGroupId),
      webUrl: Value(e.webUrl),
      conferenceJson: Value(_encodeConference(e.conference)),
      attendeesJson: Value(_encodeAttendees(e.attendees)),
      remindersJson: Value(_encodeReminders(e.reminders)),
      attachmentsJson: Value(_encodeAttachments(e.attachments)),
      dirty: Value(dirty),
    );
  }

  // --- attendees ---
  static String? _encodeAttendees(List<Attendee> a) => a.isEmpty
      ? null
      : jsonEncode([
          for (final x in a)
            {
              'email': x.email,
              'name': x.displayName,
              'resp': x.response.index,
              'org': x.isOrganizer,
              'opt': x.optional,
              'res': x.isResource,
            },
        ]);

  static List<Attendee> _decodeAttendees(String? s) {
    if (s == null || s.isEmpty) return const [];
    final list = jsonDecode(s) as List;
    return [
      for (final m in list)
        Attendee(
          email: m['email'] as String,
          displayName: m['name'] as String?,
          response: ResponseStatus.values[m['resp'] as int],
          isOrganizer: m['org'] as bool? ?? false,
          optional: m['opt'] as bool? ?? false,
          isResource: m['res'] as bool? ?? false,
        ),
    ];
  }

  // --- conference ---
  static String? _encodeConference(Conference? c) => c == null
      ? null
      : jsonEncode({
          'type': c.type.index,
          'url': c.joinUrl,
          'id': c.meetingId,
          'pwd': c.password,
          'accountId': c.accountId,
        });

  static Conference? _decodeConference(String? s) {
    if (s == null || s.isEmpty) return null;
    final m = jsonDecode(s) as Map<String, dynamic>;
    return Conference(
      type: ConferenceType.values[m['type'] as int],
      joinUrl: m['url'] as String,
      meetingId: m['id'] as String?,
      password: m['pwd'] as String?,
      accountId: m['accountId'] as String?,
    );
  }

  // --- attachments ---
  static String? _encodeAttachments(List<Attachment> a) => a.isEmpty
      ? null
      : jsonEncode([
          for (final x in a)
            {
              'uri': x.uri,
              if (x.fileName != null) 'name': x.fileName,
              if (x.mimeType != null) 'mime': x.mimeType,
              if (x.sizeBytes != null) 'size': x.sizeBytes,
            },
        ]);

  static List<Attachment> _decodeAttachments(String? s) {
    if (s == null || s.isEmpty) return const [];
    final list = jsonDecode(s) as List;
    return [
      for (final m in list)
        Attachment(
          uri: m['uri'] as String,
          fileName: m['name'] as String?,
          mimeType: m['mime'] as String?,
          sizeBytes: m['size'] as int?,
        ),
    ];
  }

  // --- reminders ---
  static String? _encodeReminders(List<Reminder> r) => r.isEmpty
      ? null
      : jsonEncode([
          for (final x in r) {'min': x.before.inMinutes, 'popup': x.popup},
        ]);

  static List<Reminder> _decodeReminders(String? s) {
    if (s == null || s.isEmpty) return const [];
    final list = jsonDecode(s) as List;
    return [
      for (final m in list)
        Reminder(
          before: Duration(minutes: m['min'] as int),
          popup: m['popup'] as bool? ?? true,
        ),
    ];
  }
}
