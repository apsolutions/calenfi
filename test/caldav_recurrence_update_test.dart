// Регрессия: CalDAV update повторяющегося события раньше падал уже после
// optimistic putLocalDirty. Outbox «сгорал» с UnsupportedError, а локальная
// правка навсегда оставалась dirty. Контракт: provider делает read/merge/write,
// не уничтожает мастер и соседние exceptions, а pull связывает exception с тем
// же стабильным id экземпляра.

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  const _Request(this.method, this.body, this.headers);

  final String method;
  final String body;
  final Map<String, dynamic> headers;
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <_Request>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    requests.add(
      _Request(
        options.method,
        utf8.decode(bytes),
        Map<String, dynamic>.from(options.headers),
      ),
    );
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_RecordingAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  const account = Account(
    id: 'acc-yandex',
    provider: ProviderType.caldav,
    displayName: 'Yandex',
    email: 'me@example.org',
  );
  const calendar = Calendar(
    id: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
    accountId: 'acc-yandex',
    name: 'Основной',
    color: 0,
  );
  const href = '/calendars/me/events-10922764/series.ics';

  const originalIcs = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
PRODID:-//Server//EN\r
BEGIN:VEVENT\r
UID:series-uid\r
DTSTAMP:20260831T100000Z\r
DTSTART:20260901T100000Z\r
DTEND:20260901T110000Z\r
RRULE:FREQ=DAILY;COUNT=3\r
SUMMARY:Серия\r
X-MASTER-PRESERVED:yes\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:series-uid\r
RECURRENCE-ID:20260902T100000Z\r
DTSTART:20260902T110000Z\r
DTEND:20260902T120000Z\r
SUMMARY:Другой exception\r
X-OTHER-PRESERVED:yes\r
END:VEVENT\r
END:VCALENDAR''';

  test('update occurrence сохраняет RRULE и соседний VEVENT', () async {
    final adapter = _RecordingAdapter(
      (options) => options.method == 'GET'
          ? ResponseBody.fromString(
              originalIcs,
              200,
              headers: {
                'etag': ['fresh-etag'],
              },
            )
          : ResponseBody.fromString(
              '',
              204,
              headers: {
                'etag': ['updated-etag'],
              },
            ),
    );
    final provider = CalDavProvider(
      account: account,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final recurrenceId = DateTime.utc(
      2026,
      9,
      3,
      10,
    ).millisecondsSinceEpoch.toString();
    final occurrence = CalendarEvent(
      id: 'acc-yandex:events-10922764:series-uid:$recurrenceId',
      calendarId: calendar.id,
      title: 'Перенесённый экземпляр',
      startUtc: DateTime.utc(2026, 9, 3, 15, 15),
      endUtc: DateTime.utc(2026, 9, 3, 16, 15),
      recurrenceRule: 'FREQ=DAILY;COUNT=3',
      recurrenceId: recurrenceId,
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: href,
        etag: 'stale-etag',
      ),
    );

    final updated = await provider.updateEvent(account, occurrence);

    expect(adapter.requests.map((request) => request.method), ['GET', 'PUT']);
    final put = adapter.requests.last;
    expect(put.headers['If-Match'], 'fresh-etag');
    expect(put.body, contains('RRULE:FREQ=DAILY;COUNT=3'));
    expect(put.body, contains('X-MASTER-PRESERVED:yes'));
    expect(put.body, contains('RECURRENCE-ID:20260902T100000Z'));
    expect(put.body, contains('X-OTHER-PRESERVED:yes'));
    expect(put.body, contains('RECURRENCE-ID:20260903T100000Z'));
    expect(put.body, contains('DTSTART:20260903T151500Z'));
    expect(put.body, contains('SUMMARY:Перенесённый экземпляр'));
    expect(updated.id, occurrence.id);
    expect(updated.source.etag, 'updated-etag');
  });

  // Жалоба: «у повторяющихся событий нельзя менять периодичность». Новое
  // правило приходит с вхождением и должно попасть в мастер, а не потеряться
  // (раньше RRULE всегда брался из мастера, то есть оставался прежним).
  test('новая периодичность уходит в RRULE мастера', () async {
    final adapter = _RecordingAdapter(
      (options) => options.method == 'GET'
          ? ResponseBody.fromString(originalIcs, 200, headers: {
              'etag': ['fresh-etag'],
            })
          : ResponseBody.fromString('', 204, headers: {
              'etag': ['updated-etag'],
            }),
    );
    final provider = CalDavProvider(
      account: account,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final recurrenceId =
        DateTime.utc(2026, 9, 3, 10).millisecondsSinceEpoch.toString();
    final occurrence = CalendarEvent(
      id: 'acc-yandex:events-10922764:series-uid:$recurrenceId',
      calendarId: calendar.id,
      title: 'Серия',
      startUtc: DateTime.utc(2026, 9, 3, 10),
      endUtc: DateTime.utc(2026, 9, 3, 11),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=TH',
      recurrenceId: recurrenceId,
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: href,
        etag: 'stale-etag',
      ),
    );

    await provider.updateEvent(account, occurrence,
        scope: RecurrenceScope.all,
        originalStartUtc: DateTime.utc(2026, 9, 3, 10));

    final put = adapter.requests.last;
    expect(put.body, contains('RRULE:FREQ=WEEKLY;BYDAY=TH'));
    expect(put.body, isNot(contains('RRULE:FREQ=DAILY;COUNT=3')));
    // Мастер остаётся мастером: его дата начала не переезжает на вхождение.
    expect(put.body, contains('DTSTART:20260901T100000Z'));
  });

  test('update мастера сохраняет EXDATE, RDATE и VALARM', () async {
    const ics = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:series-uid\r
DTSTAMP:20260831T100000Z\r
DTSTART:20260901T100000Z\r
DTEND:20260901T110000Z\r
RRULE:FREQ=DAILY;COUNT=5\r
EXDATE:20260902T100000Z\r
RDATE:20260910T100000Z\r
SUMMARY:Старое название\r
BEGIN:VALARM\r
TRIGGER:-PT15M\r
ACTION:DISPLAY\r
DESCRIPTION:Reminder\r
END:VALARM\r
END:VEVENT\r
END:VCALENDAR''';
    final adapter = _RecordingAdapter(
      (options) => options.method == 'GET'
          ? ResponseBody.fromString(
              ics,
              200,
              headers: {
                'etag': ['master-fresh-etag'],
              },
            )
          : ResponseBody.fromString('', 204),
    );
    final provider = CalDavProvider(
      account: account,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final master = CalendarEvent(
      id: 'acc-yandex:events-10922764:series-uid',
      calendarId: calendar.id,
      title: 'Новое название',
      startUtc: DateTime.utc(2026, 9, 1, 12),
      endUtc: DateTime.utc(2026, 9, 1, 13),
      recurrenceRule: 'FREQ=WEEKLY;COUNT=5',
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: href,
        etag: 'master-stale-etag',
      ),
    );

    await provider.updateEvent(account, master);

    final put = adapter.requests.last;
    expect(adapter.requests.map((request) => request.method), ['GET', 'PUT']);
    expect(put.headers['If-Match'], 'master-fresh-etag');
    expect(put.body, contains('RRULE:FREQ=WEEKLY;COUNT=5'));
    expect(put.body, isNot(contains('RRULE:FREQ=DAILY;COUNT=5')));
    expect(put.body, contains('EXDATE:20260902T100000Z'));
    expect(put.body, contains('RDATE:20260910T100000Z'));
    expect(put.body, contains('BEGIN:VALARM'));
    expect(put.body, contains('TRIGGER:-PT15M'));
    expect(put.body, contains('DESCRIPTION:Reminder'));
    expect(put.body, contains('SUMMARY:Новое название'));
    expect(put.body, contains('DTSTART:20260901T120000Z'));
  });

  test('pull накладывает RECURRENCE-ID без дубля в старом времени', () async {
    const withMovedException = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:series-uid\r
DTSTART:20260901T100000Z\r
DTEND:20260901T110000Z\r
RRULE:FREQ=DAILY;COUNT=3\r
SUMMARY:Серия\r
END:VEVENT\r
BEGIN:VEVENT\r
UID:series-uid\r
RECURRENCE-ID:20260902T100000Z\r
DTSTART:20260902T170000Z\r
DTEND:20260902T180000Z\r
SUMMARY:Перенесённый экземпляр\r
END:VEVENT\r
END:VCALENDAR''';
    final report =
        '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>$href</d:href>
    <d:propstat><d:prop>
      <d:getetag>roundtrip-etag</d:getetag>
      <c:calendar-data><![CDATA[$withMovedException]]></c:calendar-data>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>''';
    final adapter = _RecordingAdapter(
      (_) => ResponseBody.fromString(report, 207),
    );
    final provider = CalDavProvider(
      account: account,
      password: 'x',
      dio: _dioWith(adapter),
    );

    final events = await provider.fetchEvents(
      account,
      calendar,
      DateRange(DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 5)),
    );

    expect(events, hasLength(3));
    expect(
      events.where((event) => event.startUtc == DateTime.utc(2026, 9, 2, 10)),
      isEmpty,
    );
    final moved = events.singleWhere(
      (event) => event.startUtc == DateTime.utc(2026, 9, 2, 17),
    );
    final recurrenceId = DateTime.utc(
      2026,
      9,
      2,
      10,
    ).millisecondsSinceEpoch.toString();
    expect(moved.id, 'acc-yandex:events-10922764:series-uid:$recurrenceId');
    expect(moved.recurrenceId, recurrenceId);
    expect(moved.recurrenceRule, 'FREQ=DAILY;COUNT=3');
    expect(moved.title, 'Перенесённый экземпляр');
  });
}
