import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/caldav/ics.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

const _account = Account(
  id: 'a',
  provider: ProviderType.caldav,
  displayName: 'Test',
  email: 'me@example.org',
);
const _ics = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Original//EN
BEGIN:VEVENT
UID:invite
DTSTAMP:20260901T000000Z
SEQUENCE:7
DTSTART:20260903T100000Z
DTEND:20260903T110000Z
SUMMARY:Invitation
ORGANIZER;CN="Owner: calendar":mailto:owner@example.org
ATTENDEE;CN="Me: work; PARTSTAT=bogus";ROLE=REQ-PARTICIPANT;
 PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:ME@example.org
ATTENDEE;PARTSTAT=TENTATIVE:mailto:other@example.org
X-CUSTOM:preserve
BEGIN:VALARM
ACTION:EMAIL
ATTENDEE:mailto:alarm@example.org
TRIGGER:-PT15M
DESCRIPTION:Reminder
END:VALARM
END:VEVENT
END:VCALENDAR
''';

class _Server implements HttpClientAdapter {
  String body = _ics;
  String dav = '1, calendar-access, calendar-auto-schedule';
  String? etag = '"fresh"';
  String? scheduleTag;
  int putStatus = 204;
  final requests = <({RequestOptions options, String body})>[];

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
    final data = utf8.decode(bytes);
    requests.add((options: options, body: data));
    return switch (options.method) {
      'OPTIONS' => ResponseBody.fromString(
        '',
        200,
        headers: {
          'dav': [dav],
        },
      ),
      'GET' => ResponseBody.fromString(
        body,
        200,
        headers: {
          if (etag != null) 'etag': [etag!],
          if (scheduleTag != null) 'schedule-tag': [scheduleTag!],
        },
      ),
      'PUT' => ResponseBody.fromString('', putStatus),
      _ => throw StateError('Unexpected method'),
    };
  }

  @override
  void close({bool force = false}) {}

  CalDavProvider provider() => CalDavProvider(
    account: _account,
    password: 'test',
    dio: Dio()..httpClientAdapter = this,
  );
}

CalendarEvent _event({String? recurrenceId, DateTime? start}) => CalendarEvent(
  id: 'a:calendar:invite${recurrenceId == null ? '' : ':$recurrenceId'}',
  calendarId: 'a|/calendar/',
  title: 'Stale title must not be sent',
  startUtc: start ?? DateTime.utc(2026, 9, 3, 10),
  endUtc: (start ?? DateTime.utc(2026, 9, 3, 10)).add(const Duration(hours: 1)),
  recurrenceId: recurrenceId,
  source: const EventSource(
    accountId: 'a',
    calendarId: 'a|/calendar/',
    providerEventId: '/calendar/invite.ics',
    etag: '"stale"',
  ),
);

void main() {
  tz.initializeTimeZones();
  for (final response in [
    ResponseStatus.accepted,
    ResponseStatus.declined,
    ResponseStatus.tentative,
  ]) {
    test(
      '$response changes only own response and preserves organizer fields',
      () async {
        final server = _Server();
        await server.provider().respondToInvite(_account, _event(), response);
        final put = server.requests.singleWhere(
          (r) => r.options.method == 'PUT',
        );
        expect(put.options.headers['If-Match'], '"fresh"');
        expect(
          put.body,
          contains(
            'PARTSTAT=${response.name.toUpperCase()};RSVP=FALSE:mailto:ME@example.org',
          ),
        );
        for (final preserved in [
          'SEQUENCE:7',
          'SUMMARY:Invitation',
          'DTSTART:20260903T100000Z',
          'CN="Me: work; PARTSTAT=bogus"',
          'ATTENDEE;PARTSTAT=TENTATIVE:mailto:other@example.org',
          'X-CUSTOM:preserve',
          'ATTENDEE:mailto:alarm@example.org',
          'PRODID:-//Original//EN',
        ]) {
          expect(put.body, contains(preserved));
        }
        expect(put.body, isNot(contains('Stale title')));
        final mine = parseIcs(put.body).single.attendees.first;
        expect(mine.email.toLowerCase(), _account.email);
        expect(mine.partstat, response.name.toUpperCase());
      },
    );
  }

  test('uses Schedule-Tag instead of stale ETag when supplied', () async {
    final server = _Server()..scheduleTag = '"schedule"';
    await server.provider().respondToInvite(
      _account,
      _event(),
      ResponseStatus.accepted,
    );
    final headers = server.requests.last.options.headers;
    expect(headers['If-Schedule-Tag-Match'], '"schedule"');
    expect(headers.containsKey('If-Match'), isFalse);
  });

  test(
    'does not PUT without concurrency token or scheduling support',
    () async {
      for (final server in [
        _Server()..etag = null,
        _Server()..dav = '1, calendar-access',
      ]) {
        await expectLater(
          server.provider().respondToInvite(
            _account,
            _event(),
            ResponseStatus.accepted,
          ),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          server.requests.where((r) => r.options.method == 'PUT'),
          isEmpty,
        );
      }
    },
  );

  test(
    'refuses invalid response, missing attendee, wrong UID or organizer reply',
    () async {
      for (final body in [
        _ics.replaceAll('ME@example.org', 'someone@example.org'),
        _ics.replaceAll('UID:invite', 'UID:other'),
        _ics.replaceAll('owner@example.org', 'me@example.org'),
        _ics.replaceAll('ORGANIZER;CN=', 'ORGANIZER;SCHEDULE-AGENT=CLIENT;CN='),
      ]) {
        final server = _Server()..body = body;
        await expectLater(
          server.provider().respondToInvite(
            _account,
            _event(),
            ResponseStatus.accepted,
          ),
          throwsA(isA<UnsupportedError>()),
        );
        expect(
          server.requests.where((r) => r.options.method == 'PUT'),
          isEmpty,
        );
      }
      final server = _Server();
      await expectLater(
        server.provider().respondToInvite(
          _account,
          _event(),
          ResponseStatus.organizer,
        ),
        throwsArgumentError,
      );
      expect(server.requests, isEmpty);
    },
  );

  test('412 remains a failure and retry reads fresh server data', () async {
    final server = _Server()..putStatus = 412;
    final provider = server.provider();
    await expectLater(
      provider.respondToInvite(_account, _event(), ResponseStatus.accepted),
      throwsA(isA<DioException>()),
    );
    server
      ..putStatus = 204
      ..etag = '"new"'
      ..body = _ics.replaceAll(
        'SUMMARY:Invitation',
        'SUMMARY:Changed remotely',
      );
    await provider.respondToInvite(_account, _event(), ResponseStatus.accepted);
    expect(server.requests.last.options.headers['If-Match'], '"new"');
    expect(server.requests.last.body, contains('SUMMARY:Changed remotely'));
  });

  test('retry after successful PUT does not send a duplicate reply', () async {
    final server = _Server();
    final provider = server.provider();
    await provider.respondToInvite(_account, _event(), ResponseStatus.accepted);
    server.body = server.requests.last.body;
    server.requests.clear();
    await provider.respondToInvite(_account, _event(), ResponseStatus.accepted);
    expect(server.requests.where((r) => r.options.method == 'PUT'), isEmpty);
  });

  test(
    'new recurrence exception preserves master, timezone and other attendees',
    () async {
      final server = _Server()
        ..body = _ics
            .replaceAll(
              'DTSTART:20260903T100000Z',
              'DTSTART;TZID=Europe/Moscow:20260903T130000\nRRULE:FREQ=DAILY;COUNT=3',
            )
            .replaceAll(
              'DTEND:20260903T110000Z',
              'DTEND;TZID=Europe/Moscow:20260903T140000',
            );
      final original = server.body;
      final occurrence = DateTime.utc(2026, 9, 4, 10);
      await server.provider().respondToInvite(
        _account,
        _event(
          recurrenceId: '${occurrence.millisecondsSinceEpoch}',
          start: occurrence,
        ),
        ResponseStatus.tentative,
      );
      final body = server.requests.last.body;
      expect(
        body,
        startsWith(original.substring(0, original.indexOf('END:VCALENDAR'))),
      );
      final events = parseIcs(body);
      expect(events, hasLength(2));
      expect(events.first.rrule, 'FREQ=DAILY;COUNT=3');
      expect(events.last.rrule, isNull);
      expect(events.last.recurrenceIdUtc, occurrence);
      expect(events.last.startUtc, occurrence);
      expect(events.last.attendees.first.partstat, 'TENTATIVE');
      expect(
        body,
        contains('RECURRENCE-ID;TZID="Europe/Moscow":20260904T130000'),
      );
    },
  );

  test('existing moved exception only updates its own response', () async {
    final exception = _ics
        .substring(_ics.indexOf('BEGIN:VEVENT'), _ics.indexOf('END:VCALENDAR'))
        .replaceAll(
          'DTSTART:20260903T100000Z',
          'RECURRENCE-ID:20260904T100000Z\nDTSTART:20260904T120000Z',
        )
        .replaceAll('DTEND:20260903T110000Z', 'DTEND:20260904T130000Z');
    final master = _ics.replaceAll(
      'DTSTART:',
      'RRULE:FREQ=DAILY;COUNT=3\nDTSTART:',
    );
    final server = _Server()
      ..body = master.replaceFirst(
        'END:VCALENDAR',
        '${exception}END:VCALENDAR',
      );
    await server.provider().respondToInvite(
      _account,
      _event(
        recurrenceId: '${DateTime.utc(2026, 9, 4, 10).millisecondsSinceEpoch}',
      ),
      ResponseStatus.declined,
    );
    final events = parseIcs(server.requests.last.body);
    expect(events, hasLength(2));
    expect(events.first.attendees.first.partstat, 'NEEDS-ACTION');
    expect(events.last.startUtc, DateTime.utc(2026, 9, 4, 12));
    expect(events.last.attendees.first.partstat, 'DECLINED');
  });

  test('all-day recurrence keeps DATE values and duration', () async {
    final server = _Server()
      ..body = _ics
          .replaceAll(
            'DTSTART:20260903T100000Z',
            'DTSTART;VALUE=DATE:20260903\nRRULE:FREQ=DAILY;COUNT=3',
          )
          .replaceAll('DTEND:20260903T110000Z', 'DTEND;VALUE=DATE:20260904');
    final day = DateTime.utc(2026, 9, 4);
    await server.provider().respondToInvite(
      _account,
      _event(recurrenceId: '${day.millisecondsSinceEpoch}', start: day),
      ResponseStatus.accepted,
    );
    final body = server.requests.last.body;
    expect(body, contains('RECURRENCE-ID;VALUE=DATE:20260904'));
    final exception = parseIcs(body).last;
    expect(exception.allDay, isTrue);
    expect(exception.startUtc, day);
    expect(exception.endUtc, day.add(const Duration(days: 1)));
  });

  test(
    'excluded occurrences and cancelled events are not resurrected',
    () async {
      final occurrence = DateTime.utc(2026, 9, 4, 10);
      final server = _Server()
        ..body = _ics.replaceAll(
          'DTSTART:',
          'RRULE:FREQ=DAILY;COUNT=3\nEXDATE:20260904T100000Z\nDTSTART:',
        );
      await expectLater(
        server.provider().respondToInvite(
          _account,
          _event(recurrenceId: '${occurrence.millisecondsSinceEpoch}'),
          ResponseStatus.accepted,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      server.body = _ics.replaceAll('SUMMARY:', 'STATUS:CANCELLED\nSUMMARY:');
      await expectLater(
        server.provider().respondToInvite(
          _account,
          _event(),
          ResponseStatus.accepted,
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(server.requests.where((r) => r.options.method == 'PUT'), isEmpty);
    },
  );

  test(
    'foreign account and cross-origin href never receive credentials',
    () async {
      for (final source in [
        const EventSource(
          accountId: 'other',
          calendarId: 'other|/calendar/',
          providerEventId: '/calendar/invite.ics',
        ),
        const EventSource(
          accountId: 'a',
          calendarId: 'a|/calendar/',
          providerEventId: 'https://other.example.org/invite.ics',
        ),
      ]) {
        final server = _Server();
        await expectLater(
          server.provider().respondToInvite(
            _account,
            _event().copyWith(source: source),
            ResponseStatus.accepted,
          ),
          throwsArgumentError,
        );
        expect(server.requests, isEmpty);
      }
    },
  );
}
