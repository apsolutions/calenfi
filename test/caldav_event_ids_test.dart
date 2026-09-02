// Регрессионный тест бага «событие пропадало из сетки» (июль 2026): Яндекс
// CalDAV кладёт одно приглашение с одним UID в НЕСКОЛЬКО коллекций (основной
// календарь + календарь переговорки). При id вида `acc:UID` копии коллапсировали
// в одну строку БД, и копия из СКРЫТОГО календаря переговорки перезаписывала
// копию из видимого — «Собеседование» исчезало при «всё синхронизировано».
// Контракт: id события календарно-скоупный → копии сосуществуют.

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/caldav/ics.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  const _Request(this.method, this.uri, this.body, this.headers);

  final String method;
  final Uri uri;
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
        options.uri,
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
  const acc = Account(
    id: 'acc-yandex',
    provider: ProviderType.caldav,
    displayName: 'Y',
    email: 'me@example.org',
  );

  const mainCal = Calendar(
    id: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
    accountId: 'acc-yandex',
    name: 'me@example.org',
    color: 0,
  );
  const roomCal = Calendar(
    id: 'acc-yandex|/calendars/me%40example.org/events-6352832/',
    accountId: 'acc-yandex',
    name: 'Переговорка',
    color: 0,
  );

  final vevent = VEvent(
    uid: 'interview-123@yandex.ru',
    summary: 'Собеседование',
    startUtc: DateTime.utc(2026, 7, 22, 11),
    endUtc: DateTime.utc(2026, 7, 22, 12),
    allDay: false,
  );

  test('один UID в двух календарях → РАЗНЫЕ id (копии сосуществуют)', () {
    final p = CalDavProvider(account: acc, password: 'x');
    final inMain = p.buildEventForTest(acc, mainCal, vevent);
    final inRoom = p.buildEventForTest(acc, roomCal, vevent);

    expect(
      inMain.id,
      isNot(inRoom.id),
      reason: 'коллизия id: копия из скрытого календаря затрёт видимую',
    );
    // Токен календаря в id — последний сегмент пути коллекции.
    expect(inMain.id, 'acc-yandex:events-10922764:interview-123@yandex.ru');
    expect(inRoom.id, 'acc-yandex:events-6352832:interview-123@yandex.ru');
    // Каждая копия привязана к своему календарю (видимость фильтрует отдельно).
    expect(inMain.calendarId, mainCal.id);
    expect(inRoom.calendarId, roomCal.id);
  });

  test('дедуп склеит копии в одну карточку (одинаковые название+время)', () {
    final p = CalDavProvider(account: acc, password: 'x');
    final a = p.buildEventForTest(acc, mainCal, vevent);
    final b = p.buildEventForTest(acc, roomCal, vevent);
    // Эвристика dedup_engine: normalized title + start + end (см. FR-D2).
    expect(
      a.title == b.title && a.startUtc == b.startUtc && a.endUtc == b.endUtc,
      isTrue,
    );
  });

  test('legacy-префиксы UID схлопываются без коллизии календарей', () {
    const uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
    const mainPrefix = 'acc-yandex:events-10922764:';
    const roomPrefix = 'acc-yandex:events-6352832:';
    final p = CalDavProvider(account: acc, password: 'x');

    VEvent event(String value) => VEvent(
      uid: value,
      summary: 'МЭС с Леной',
      startUtc: DateTime.utc(2026, 8, 28, 12, 15),
      endUtc: DateTime.utc(2026, 8, 28, 13, 15),
      allDay: false,
    );

    final main = p.buildEventForTest(
      acc,
      mainCal,
      event('$mainPrefix$mainPrefix$mainPrefix$uid'),
    );
    final room = p.buildEventForTest(
      acc,
      roomCal,
      event('$roomPrefix$roomPrefix$uid'),
    );
    final accountOnlyLegacy = p.buildEventForTest(
      acc,
      mainCal,
      event('acc-yandex:$uid'),
    );
    final foreignPrefixIsPartOfUid = p.buildEventForTest(
      acc,
      mainCal,
      event('$roomPrefix$uid'),
    );

    expect(main.id, '$mainPrefix$uid');
    expect(room.id, '$roomPrefix$uid');
    expect(accountOnlyLegacy.id, '$mainPrefix$uid');
    expect(main.id, isNot(room.id));
    expect(
      foreignPrefixIsPartOfUid.id,
      '$mainPrefix$roomPrefix$uid',
      reason: 'чужой calendar-prefix нельзя срезать: возникнет коллизия',
    );
  });

  test(
    'update legacy-id пишет чистый UID; повторный pull не меняет id',
    () async {
      const uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
      const prefix = 'acc-yandex:events-10922764:';
      const href =
          '/calendars/me%40example.org/events-10922764/server-resource.ics';
      final adapter = _RecordingAdapter(
        (_) => ResponseBody.fromString('', 204),
      );
      final p = CalDavProvider(
        account: acc,
        password: 'x',
        dio: _dioWith(adapter),
      );
      final legacy = CalendarEvent(
        id: '$prefix$prefix$prefix$prefix$uid',
        calendarId: mainCal.id,
        title: 'МЭС с Леной',
        startUtc: DateTime.utc(2026, 8, 28, 12, 15),
        endUtc: DateTime.utc(2026, 8, 28, 13, 15),
        source: const EventSource(
          accountId: 'acc-yandex',
          calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
          providerEventId: href,
          etag: '1787918567000',
        ),
      );

      final updated = await p.updateEvent(acc, legacy);

      expect(updated.id, '$prefix$uid');
      expect(updated.source.providerEventId, href);
      expect(adapter.requests.single.method, 'PUT');
      expect(
        adapter.requests.single.uri.path,
        '/calendars/me%40example.org/events-10922764/server-resource.ics',
      );
      expect(adapter.requests.single.body, contains('UID:$uid\n'));
      expect(adapter.requests.single.body, isNot(contains('UID:$prefix')));
      expect(
        adapter.requests.single.headers['If-Match'],
        '1787918567000',
        reason: 'bare numeric Yandex ETag нельзя самовольно менять',
      );

      final pulledAgain = p.buildEventForTest(
        acc,
        mainCal,
        VEvent(
          uid: uid,
          summary: legacy.title,
          startUtc: legacy.startUtc,
          endUtc: legacy.endUtc,
          allDay: false,
        ),
      );
      expect(pulledAgain.id, updated.id);
    },
  );

  test('create разделяет resource href, UID и локальный id', () async {
    const uid = 'local-uuid-1';
    const prefix = 'acc-yandex:events-10922764:';
    final adapter = _RecordingAdapter(
      (_) => ResponseBody.fromString(
        '',
        201,
        headers: {
          'etag': ['created-bare-etag'],
        },
      ),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final local = CalendarEvent(
      id: uid,
      calendarId: mainCal.id,
      title: 'Новая встреча',
      startUtc: DateTime.utc(2026, 8, 28, 12),
      endUtc: DateTime.utc(2026, 8, 28, 13),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: uid,
      ),
    );

    final created = await p.createEvent(acc, mainCal, local);

    expect(created.id, '$prefix$uid');
    expect(
      created.source.providerEventId,
      '/calendars/me%40example.org/events-10922764/local-uuid-1.ics',
    );
    expect(adapter.requests.single.body, contains('UID:$uid\n'));
    expect(
      adapter.requests.single.uri.path,
      '/calendars/me%40example.org/events-10922764/local-uuid-1.ics',
    );
    expect(adapter.requests.single.headers['If-None-Match'], '*');
    expect(created.source.etag, 'created-bare-etag');
  });

  test('update мигрирует старый account-only локальный id', () async {
    const uid = '5dac077e-7c73-4954-8f66-49c2bed3fc2a';
    const prefix = 'acc-yandex:events-10922764:';
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString('', 204));
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final legacy = CalendarEvent(
      id: 'acc-yandex:$uid',
      calendarId: mainCal.id,
      title: 'Старое событие',
      startUtc: DateTime.utc(2026, 8, 28, 12),
      endUtc: DateTime.utc(2026, 8, 28, 13),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId:
            '/calendars/me%40example.org/events-10922764/account-only.ics',
      ),
    );

    final updated = await p.updateEvent(acc, legacy);

    expect(updated.id, '$prefix$uid');
    expect(adapter.requests.single.body, contains('UID:$uid\n'));
    expect(
      adapter.requests.single.body,
      isNot(contains('UID:acc-yandex:$uid')),
    );
  });

  test('delete адресует сохранённый href, а не строит URL из id', () async {
    const href =
        '/calendars/me%40example.org/events-10922764/real-server-name.ics';
    const report =
        '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response><d:href>$href</d:href><d:propstat><d:prop>
    <c:calendar-data><![CDATA[BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:5dac077e-7c73-4954-8f66-49c2bed3fc2a\r
DTSTART:20260828T120000Z\r
DTEND:20260828T130000Z\r
END:VEVENT\r
END:VCALENDAR]]></c:calendar-data>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';
    final adapter = _RecordingAdapter(
      (options) => options.method == 'REPORT'
          ? ResponseBody.fromString(report, 207)
          : ResponseBody.fromString('', 204),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final event = CalendarEvent(
      id:
          'acc-yandex:events-10922764:'
          '5dac077e-7c73-4954-8f66-49c2bed3fc2a',
      calendarId: mainCal.id,
      title: 'Встреча',
      startUtc: DateTime.utc(2026, 8, 28, 12),
      endUtc: DateTime.utc(2026, 8, 28, 13),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: href,
      ),
    );

    await p.deleteEvent(acc, event, RecurrenceScope.all);

    expect(adapter.requests.map((r) => r.method), ['REPORT', 'DELETE']);
    expect(
      adapter.requests.last.uri.path,
      '/calendars/me%40example.org/events-10922764/real-server-name.ics',
    );
    expect(adapter.requests.last.uri.path, isNot(contains(event.id)));
  });

  test('HTTP 404/4xx на DELETE не считается успехом', () async {
    const report = '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response><d:href>/calendars/me/events-10922764/resource.ics</d:href>
  <d:propstat><d:prop><c:calendar-data><![CDATA[BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:uid\r
DTSTART:20260828T120000Z\r
DTEND:20260828T130000Z\r
END:VEVENT\r
END:VCALENDAR]]></c:calendar-data></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';
    final adapter = _RecordingAdapter(
      (options) => options.method == 'REPORT'
          ? ResponseBody.fromString(report, 207)
          : ResponseBody.fromString('not found', 404),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final event = CalendarEvent(
      id: 'acc-yandex:events-10922764:uid',
      calendarId: mainCal.id,
      title: 'Встреча',
      startUtc: DateTime.utc(2026, 8, 28, 12),
      endUtc: DateTime.utc(2026, 8, 28, 13),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: '/calendars/me/events-10922764/resource.ics',
      ),
    );

    await expectLater(
      p.deleteEvent(acc, event, RecurrenceScope.all),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'partial recurrence PUT использует свежий GET ETag и отклоняет 412',
    () async {
      const ics = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:series-uid\r
DTSTART:20260828T120000Z\r
DTEND:20260828T130000Z\r
RRULE:FREQ=WEEKLY\r
END:VEVENT\r
END:VCALENDAR''';
      final adapter = _RecordingAdapter((options) {
        if (options.method == 'GET') {
          return ResponseBody.fromString(
            ics,
            200,
            headers: {
              'etag': ['fresh-bare-etag'],
            },
          );
        }
        return ResponseBody.fromString('precondition failed', 412);
      });
      final p = CalDavProvider(
        account: acc,
        password: 'x',
        dio: _dioWith(adapter),
      );
      final event = CalendarEvent(
        id: 'acc-yandex:events-10922764:series-uid',
        calendarId: mainCal.id,
        title: 'Серия',
        startUtc: DateTime.utc(2026, 8, 28, 12),
        endUtc: DateTime.utc(2026, 8, 28, 13),
        recurrenceRule: 'FREQ=WEEKLY',
        source: const EventSource(
          accountId: 'acc-yandex',
          calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
          providerEventId: '/calendars/me/events-10922764/series.ics',
          etag: 'stale-saved-etag',
        ),
      );

      await expectLater(
        p.deleteEvent(acc, event, RecurrenceScope.thisOnly),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests.map((r) => r.method), ['GET', 'PUT']);
      expect(adapter.requests.last.headers['If-Match'], 'fresh-bare-etag');
    },
  );

  test(
    'partial recurrence PUT использует сохранённый ETag как fallback',
    () async {
      const ics = '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:series-uid\r
DTSTART:20260828T120000Z\r
DTEND:20260828T130000Z\r
RRULE:FREQ=WEEKLY\r
END:VEVENT\r
END:VCALENDAR''';
      final adapter = _RecordingAdapter(
        (options) => options.method == 'GET'
            ? ResponseBody.fromString(ics, 200)
            : ResponseBody.fromString('', 204),
      );
      final p = CalDavProvider(
        account: acc,
        password: 'x',
        dio: _dioWith(adapter),
      );
      final event = CalendarEvent(
        id: 'acc-yandex:events-10922764:series-uid',
        calendarId: mainCal.id,
        title: 'Серия',
        startUtc: DateTime.utc(2026, 8, 28, 12),
        endUtc: DateTime.utc(2026, 8, 28, 13),
        recurrenceRule: 'FREQ=WEEKLY',
        source: const EventSource(
          accountId: 'acc-yandex',
          calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
          providerEventId: '/calendars/me/events-10922764/series.ics',
          etag: '1787918567000',
        ),
      );

      await p.deleteEvent(acc, event, RecurrenceScope.thisOnly);

      expect(adapter.requests.map((r) => r.method), ['GET', 'PUT']);
      expect(adapter.requests.last.headers['If-Match'], '1787918567000');
    },
  );

  test('update occurrence с пустым GET отклоняется до PUT', () async {
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString('', 204));
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final occurrence = CalendarEvent(
      id: 'acc-yandex:events-10922764:series-uid:1787929200000',
      calendarId: mainCal.id,
      title: 'Экземпляр серии',
      startUtc: DateTime.utc(2026, 8, 28, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16),
      recurrenceRule: 'FREQ=WEEKLY',
      recurrenceId: '1787929200000',
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: '/calendars/me/events-10922764/series.ics',
        etag: '1787918567000',
      ),
    );

    await expectLater(
      p.updateEvent(acc, occurrence),
      throwsA(isA<FormatException>()),
    );
    expect(
      adapter.requests.map((request) => request.method),
      ['GET'],
      reason: 'неполный ресурс нельзя перезаписывать одним VEVENT',
    );
  });

  test('update мастера с пустым GET тоже отклоняется до PUT', () async {
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString('', 204));
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final master = CalendarEvent(
      id: 'acc-yandex:events-10922764:series-uid',
      calendarId: mainCal.id,
      title: 'Серия',
      startUtc: DateTime.utc(2026, 8, 28, 15),
      endUtc: DateTime.utc(2026, 8, 28, 16),
      recurrenceRule: 'FREQ=WEEKLY',
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: '/calendars/me/events-10922764/series.ics',
      ),
    );

    await expectLater(
      p.updateEvent(acc, master),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests.map((request) => request.method), ['GET']);
  });

  test('update с If-Match не считает 412 успехом', () async {
    final adapter = _RecordingAdapter(
      (_) => ResponseBody.fromString('precondition failed', 412),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );
    final event = CalendarEvent(
      id: 'acc-yandex:events-10922764:uid',
      calendarId: mainCal.id,
      title: 'Конфликт',
      startUtc: DateTime.utc(2026, 8, 28, 12),
      endUtc: DateTime.utc(2026, 8, 28, 13),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
        providerEventId: '/calendars/me/events-10922764/resource.ics',
        etag: '1787918567000',
      ),
    );

    await expectLater(p.updateEvent(acc, event), throwsA(isA<DioException>()));
    expect(adapter.requests.single.headers['If-Match'], '1787918567000');
  });

  test('same CTag не пропускает REPORT/fullWindow после remote delete', () async {
    const propfind = '''
<d:multistatus xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/">
  <d:response><d:propstat><d:prop>
    <cs:getctag>1787918567000</cs:getctag>
  </d:prop></d:propstat></d:response>
</d:multistatus>''';
    const emptyReport =
        '<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"/>';
    final adapter = _RecordingAdapter(
      (options) => ResponseBody.fromString(
        options.method == 'PROPFIND' ? propfind : emptyReport,
        207,
        headers: {
          Headers.contentTypeHeader: ['application/xml'],
        },
      ),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );

    final result = await p.incrementalSync(acc, mainCal, '1787918567000');

    expect(adapter.requests.map((r) => r.method), ['PROPFIND', 'REPORT']);
    expect(result.upserts, isEmpty);
    expect(
      result.fullWindow,
      isNotNull,
      reason: 'SyncEngine без fullWindow не удалит исчезнувший 5dac…',
    );
    expect(result.newSyncState, '1787918567000');
  });

  test('частичный REPORT не возвращается как fullWindow', () async {
    const propfind = '''
<d:multistatus xmlns:d="DAV:" xmlns:cs="http://calendarserver.org/ns/">
  <d:response><d:propstat><d:prop>
    <cs:getctag>1787918567000</cs:getctag>
  </d:prop></d:propstat></d:response>
</d:multistatus>''';
    const partialReport = '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>/cal/broken.ics</d:href>
    <d:propstat>
      <d:prop><c:calendar-data/></d:prop>
      <d:status>HTTP/1.1 500 Internal Server Error</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>''';
    final adapter = _RecordingAdapter(
      (options) => ResponseBody.fromString(
        options.method == 'PROPFIND' ? propfind : partialReport,
        207,
        headers: {
          Headers.contentTypeHeader: ['application/xml'],
        },
      ),
    );
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );

    await expectLater(
      p.incrementalSync(acc, mainCal, '1787918567000'),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests.map((r) => r.method), ['PROPFIND', 'REPORT']);
  });

  test('REPORT отклоняет calendar-data без VEVENT/UID', () async {
    String response(String ics) =>
        '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>/cal/broken.ics</d:href>
    <d:propstat><d:prop>
      <c:calendar-data><![CDATA[$ics]]></c:calendar-data>
    </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
  </d:response>
</d:multistatus>''';

    for (final ics in [
      'BEGIN:VCALENDAR\r\nEND:VCALENDAR',
      'BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART:20260828T120000Z\r\nDTEND:20260828T130000Z\r\nEND:VEVENT\r\nEND:VCALENDAR',
    ]) {
      final adapter = _RecordingAdapter(
        (_) => ResponseBody.fromString(response(ics), 207),
      );
      final p = CalDavProvider(
        account: acc,
        password: 'x',
        dio: _dioWith(adapter),
      );
      await expectLater(
        p.fetchEvents(
          acc,
          mainCal,
          DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 9, 1)),
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('REPORT read-only выбирает новейший ресурс legacy-семьи', () async {
    const uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
    const prefix = 'acc-yandex:events-10922764:';
    String ics(String eventUid, String title, int hour, int minute, int seq) =>
        '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:$eventUid\r
DTSTAMP:20260828T${(10 + seq).toString().padLeft(2, '0')}0000Z\r
SEQUENCE:$seq\r
DTSTART:20260828T${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}00Z\r
DTEND:20260828T${(hour + 1).toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}00Z\r
SUMMARY:$title\r
END:VEVENT\r
END:VCALENDAR''';

    String response(String href, String calendarData) =>
        '''
<d:response>
  <d:href>$href</d:href>
	  <d:propstat><d:prop>
	    <d:getetag>"etag"</d:getetag>
	    <c:calendar-data><![CDATA[$calendarData]]></c:calendar-data>
	  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
	</d:response>''';

    // Новейший ресурс намеренно идёт первым: последний в REPORT
    // должен быть проигнорирован, несмотря на порядок XML.
    final xml =
        '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
${response('/cal/newest.ics', ics('$prefix$prefix$prefix$uid', 'Новая 15:15', 15, 15, 4))}
${response('/cal/middle.ics', ics('$prefix$prefix$uid', 'Старая 17:00', 17, 0, 3))}
${response('/cal/oldest.ics', ics(uid, 'Самая старая 17:00', 17, 0, 1))}
</d:multistatus>''';
    final adapter = _RecordingAdapter((options) {
      if (options.method != 'REPORT') {
        return ResponseBody.fromString('', 204);
      }
      return ResponseBody.fromString(
        xml,
        207,
        headers: {
          Headers.contentTypeHeader: ['application/xml'],
        },
      );
    });
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );

    final events = await p.fetchEvents(
      acc,
      mainCal,
      DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 9, 1)),
    );

    expect(events, hasLength(1));
    expect(events.single.id, '$prefix$uid');
    expect(events.single.title, 'Новая 15:15');
    expect(events.single.startUtc, DateTime.utc(2026, 8, 28, 15, 15));
    expect(
      events.single.source.providerEventId,
      '/cal/newest.ics',
      reason: 'pull сохраняет href выбранного ресурса и ничего не переписывает',
    );
    expect(adapter.requests.map((r) => r.method), ['REPORT']);
  });

  test('Windows timestamp важнее legacy epoch SEQUENCE', () async {
    const uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
    const prefix = 'acc-yandex:events-10922764:';
    String ics(String eventUid, String stamp, int seq, String title) =>
        '''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:$eventUid\r
DTSTAMP:$stamp\r
LAST-MODIFIED:$stamp\r
SEQUENCE:$seq\r
DTSTART:20260828T151500Z\r
DTEND:20260828T161500Z\r
SUMMARY:$title\r
END:VEVENT\r
END:VCALENDAR''';
    String response(String href, String calendarData) =>
        '''
<d:response>
  <d:href>$href</d:href>
  <d:propstat><d:prop>
    <c:calendar-data><![CDATA[$calendarData]]></c:calendar-data>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''';
    final xml =
        '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
${response('/cal/legacy.ics', ics('$prefix$uid', '20260828T140000Z', 1787918567, 'Старая 17:00'))}
${response('/cal/windows.ics', ics(uid, '20260828T150000Z', 7, 'Новая 15:15'))}
</d:multistatus>''';
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString(xml, 207));
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );

    final events = await p.fetchEvents(
      acc,
      mainCal,
      DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 9, 1)),
    );

    expect(events.single.title, 'Новая 15:15');
    expect(events.single.source.providerEventId, '/cal/windows.ics');
    expect(adapter.requests.map((r) => r.method), ['REPORT']);
  });

  test('при равном timestamp raw UID важнее чужого epoch SEQUENCE', () async {
    const uid = 'ea5c1418-3a71-4bd9-9728-c3a9ca1ce34e';
    const prefix = 'acc-yandex:events-10922764:';
    String response(String href, String eventUid, int seq, String title) =>
        '''
<d:response>
  <d:href>$href</d:href>
  <d:propstat><d:prop><c:calendar-data><![CDATA[BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:$eventUid\r
DTSTAMP:20260828T150000Z\r
SEQUENCE:$seq\r
DTSTART:20260828T151500Z\r
DTEND:20260828T161500Z\r
SUMMARY:$title\r
END:VEVENT\r
END:VCALENDAR]]></c:calendar-data></d:prop>
  <d:status>HTTP/1.1 200 OK</d:status></d:propstat>
</d:response>''';
    final xml =
        '''
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
${response('/cal/raw.ics', uid, 7, 'Windows')}
${response('/cal/legacy.ics', '$prefix$uid', 1787918567, 'Legacy')}
</d:multistatus>''';
    final adapter = _RecordingAdapter((_) => ResponseBody.fromString(xml, 207));
    final p = CalDavProvider(
      account: acc,
      password: 'x',
      dio: _dioWith(adapter),
    );

    final events = await p.fetchEvents(
      acc,
      mainCal,
      DateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 9, 1)),
    );

    expect(events.single.title, 'Windows');
    expect(events.single.source.providerEventId, '/cal/raw.ics');
  });
}
