import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  const _Request(this.method, this.uri, this.body, this.headers);

  final String method;
  final Uri uri;
  final String body;
  final Map<String, dynamic> headers;
}

class _FamilyAdapter implements HttpClientAdapter {
  _FamilyAdapter({this.failHref});

  final String? failHref;
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
        options.uri,
        utf8.decode(bytes),
        Map<String, dynamic>.from(options.headers),
      ),
    );

    if (options.method == 'REPORT') {
      return ResponseBody.fromString(
        _familyReport,
        207,
        headers: {
          Headers.contentTypeHeader: ['application/xml; charset=utf-8'],
        },
      );
    }
    if (options.method == 'DELETE' && options.uri.path == failHref) {
      return ResponseBody.fromString('precondition failed', 412);
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

const _uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
const _prefix = 'acc-yandex:events-10922764:';
const _calendarHref = '/calendars/me%40example.org/events-10922764/';

String _resource(String href, String uid, String etag) =>
    '''
<d:response>
  <d:href>$href</d:href>
  <d:propstat><d:prop>
    <d:getetag>&quot;$etag&quot;</d:getetag>
    <c:calendar-data><![CDATA[BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:$uid\r
DTSTAMP:20260828T150000Z\r
DTSTART:20260828T151500Z\r
DTEND:20260828T161500Z\r
SUMMARY:МЭС с Леной\r
END:VEVENT\r
END:VCALENDAR]]></c:calendar-data>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''';

final _familyReport =
    '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
${_resource('${_calendarHref}newest.ics', '$_prefix$_prefix$_prefix$_uid', 'etag-newest')}
${_resource('${_calendarHref}legacy-middle.ics', '$_prefix$_prefix$_uid', 'etag-middle')}
${_resource('${_calendarHref}legacy-oldest.ics', _uid, 'etag-oldest')}
${_resource('${_calendarHref}unrelated.ics', 'not-$_uid-extra', 'etag-unrelated')}
</d:multistatus>''';

void main() {
  const account = Account(
    id: 'acc-yandex',
    provider: ProviderType.caldav,
    displayName: 'Yandex',
    email: 'me@example.org',
  );
  const calendar = Calendar(
    id: 'acc-yandex|$_calendarHref',
    accountId: 'acc-yandex',
    name: 'Calendar',
    color: 0,
  );

  CalendarEvent event() => CalendarEvent(
    id: '$_prefix$_uid',
    calendarId: calendar.id,
    title: 'МЭС с Леной',
    startUtc: DateTime.utc(2026, 8, 28, 15, 15),
    endUtc: DateTime.utc(2026, 8, 28, 16, 15),
    source: const EventSource(
      accountId: 'acc-yandex',
      calendarId: 'acc-yandex|$_calendarHref',
      providerEventId: '${_calendarHref}newest.ics',
      etag: 'stale-local-etag',
    ),
  );

  test(
    'fresh provider deletes every href in a canonical legacy UID family',
    () async {
      final adapter = _FamilyAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = CalDavProvider(
        account: account,
        password: 'x',
        dio: dio,
      );

      await provider.deleteEvent(account, event(), RecurrenceScope.all);

      expect(adapter.requests.map((request) => request.method), [
        'REPORT',
        'DELETE',
        'DELETE',
        'DELETE',
      ]);
      expect(
        adapter.requests.first.body,
        contains('<c:prop-filter name="UID">'),
      );
      expect(adapter.requests.first.body, contains(_uid));
      expect(adapter.requests.first.body, isNot(contains('<c:time-range')));
      expect(adapter.requests.skip(1).map((request) => request.uri.path), [
        '${_calendarHref}legacy-middle.ics',
        '${_calendarHref}legacy-oldest.ics',
        '${_calendarHref}newest.ics',
      ]);
      expect(
        adapter.requests.skip(1).map((request) => request.headers['If-Match']),
        ['"etag-middle"', '"etag-oldest"', '"etag-newest"'],
        reason: 'DELETE uses the fresh per-resource ETag returned by discovery',
      );
      expect(
        adapter.requests.map((request) => request.uri.path),
        isNot(contains('${_calendarHref}unrelated.ics')),
        reason: 'substring REPORT results still require exact canonical UID',
      );
    },
  );

  test('a failed sibling DELETE leaves the pull winner untouched', () async {
    final adapter = _FamilyAdapter(
      failHref: '${_calendarHref}legacy-middle.ics',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final provider = CalDavProvider(account: account, password: 'x', dio: dio);

    await expectLater(
      provider.deleteEvent(account, event(), RecurrenceScope.all),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests.map((request) => request.method), [
      'REPORT',
      'DELETE',
    ]);
    expect(
      adapter.requests.map((request) => request.uri.path),
      isNot(contains('${_calendarHref}newest.ics')),
    );
  });
}
