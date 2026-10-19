import 'package:calenfi/data/local/db/database.dart' show AppDatabase;
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/domain/usecases/event_actions.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'dart:async';
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
  int getStatus = 200;
  String? deliveryStatus = '1.2';
  void Function()? afterPut;
  Completer<void>? readEntered;
  Completer<void>? readRelease;
  ({RequestOptions options, String body}) get lastPut =>
      requests.lastWhere((r) => r.options.method == 'PUT');
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
    if (options.method == 'GET' && readRelease != null) {
      final release = readRelease!;
      readRelease = null;
      readEntered?.complete();
      await release.future;
    }
    if (options.method == 'PUT' && putStatus >= 200 && putStatus < 300) {
      body = data
          .replaceAll(RegExp(r';SCHEDULE-FORCE-SEND=REPLY'), '')
          .replaceAll(RegExp(r';SCHEDULE-STATUS=(?:"[^"]*"|[^;:\r\n]*)'), '');
      if (deliveryStatus != null) {
        body = body.replaceAll(
          'ORGANIZER;',
          'ORGANIZER;SCHEDULE-STATUS="$deliveryStatus";',
        );
      }
      afterPut?.call();
    }
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
        getStatus,
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

// Real RSVP transport plus a small pull/CRUD stub to exercise durable queue
// handling without coupling the fixture to CalDAV discovery and REPORT XML.
class _SyncProvider extends CalDavProvider {
  _SyncProvider(this.server)
    : super(
        account: _account,
        password: 'test',
        dio: Dio()..httpClientAdapter = server,
      );
  final _Server server;
  CalendarEvent remote = _event();
  int updates = 0;
  @override
  Future<List<Calendar>> listCalendars(Account a) async => const [
    Calendar(id: 'a|/calendar/', accountId: 'a', name: 'Work', color: 0),
  ];
  @override
  Future<SyncResult> incrementalSync(
    Account a,
    Calendar c,
    String? state,
  ) async {
    final partstat = parseIcs(server.body).first.attendees.first.partstat;
    return SyncResult(
      upserts: [
        remote.copyWith(
          myResponse: switch (partstat) {
            'ACCEPTED' => ResponseStatus.accepted,
            'TENTATIVE' => ResponseStatus.tentative,
            'DECLINED' => ResponseStatus.declined,
            _ => ResponseStatus.needsAction,
          },
        ),
      ],
      deletedIds: [],
      newSyncState: null,
    );
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account a,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    updates++;
    remote = e;
    return e;
  }
}

Future<void> _withSync(
  _Server server,
  Future<void> Function(EventRepository, SyncEngine, _SyncProvider) run,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final accounts = AccountRepository(db);
  final events = EventRepository(db);
  final provider = _SyncProvider(server);
  final sync = SyncEngine(
    registry: ProviderRegistry(overrideFactory: (_) => provider),
    accounts: accounts,
    events: events,
  );
  try {
    await accounts.upsertAccount(_account);
    await sync.syncAccount(_account);
    await run(events, sync, provider);
  } finally {
    server.readRelease?.complete();
    await sync.whenIdle();
    sync.dispose();
    await db.close();
  }
}

void main() {
  tz.initializeTimeZones();
  for (final response in [
    ResponseStatus.accepted,
    ResponseStatus.tentative,
    ResponseStatus.declined,
  ]) {
    test(
      '$response on unsupported server leaves event and queue unchanged',
      () async {
        final server = _Server()..dav = '1, calendar-access';
        await _withSync(server, (events, sync, provider) async {
          await expectLater(
            EventActions(events, sync).rsvp(_event(), response),
            throwsA(isA<UnsupportedError>()),
          );
          expect(await events.pendingOutbox(), isEmpty);
          expect(
            (await events.getById(_event().id))!.myResponse,
            ResponseStatus.needsAction,
          );
          await events.saveAndEnqueue(
            _event().copyWith(title: 'Later edit'),
            'update',
          );
          expect((await sync.syncAccount(_account)).ok, isTrue);
          expect(provider.remote.title, 'Later edit');
        });
      },
    );
  }

  test(
    'preflight validates event scheduling agent before changing local status',
    () async {
      final server = _Server()
        ..body = _ics.replaceAll(
          'ORGANIZER;',
          'ORGANIZER;SCHEDULE-AGENT=CLIENT;',
        );
      await _withSync(server, (events, sync, provider) async {
        await expectLater(
          EventActions(events, sync).rsvp(_event(), ResponseStatus.accepted),
          throwsA(isA<UnsupportedError>()),
        );
        expect(await events.pendingOutbox(), isEmpty);
        expect(
          (await events.getById(_event().id))!.myResponse,
          ResponseStatus.needsAction,
        );
      });
    },
  );

  test(
    'failed preflight read leaves no optimistic response or queued job',
    () async {
      final server = _Server()..getStatus = 503;
      await _withSync(server, (events, sync, provider) async {
        await expectLater(
          EventActions(events, sync).rsvp(_event(), ResponseStatus.accepted),
          throwsA(isA<DioException>()),
        );
        expect(await events.pendingOutbox(), isEmpty);
        expect(
          (await events.getById(_event().id))!.myResponse,
          ResponseStatus.needsAction,
        );
      });
    },
  );

  test('edit during preflight is preserved by the queued response', () async {
    final server = _Server();
    await _withSync(server, (events, sync, provider) async {
      final release = Completer<void>();
      server.readEntered = Completer<void>();
      server.readRelease = release;
      final reply = EventActions(
        events,
        sync,
      ).rsvp(_event(), ResponseStatus.accepted);
      await server.readEntered!.future;
      try {
        await events.saveAndEnqueue(
          _event().copyWith(title: 'Edited during preflight'),
          'update',
        );
      } finally {
        release.complete();
      }
      await reply;
      await sync.syncAccountById(_account.id);
      await sync.whenIdle();
      expect(
        (await events.getById(_event().id))!.title,
        'Edited during preflight',
      );
      expect(await events.pendingOutbox(), isEmpty);
    });
  });

  test('deletion during preflight cannot resurrect the invitation', () async {
    final server = _Server();
    await _withSync(server, (events, sync, provider) async {
      final release = Completer<void>();
      server.readEntered = Completer<void>();
      server.readRelease = release;
      final reply = EventActions(
        events,
        sync,
      ).rsvp(_event(), ResponseStatus.accepted);
      final failure = expectLater(reply, throwsStateError);
      await server.readEntered!.future;
      try {
        await events.hardDelete(_event().id);
      } finally {
        release.complete();
      }
      await failure;
      expect(await events.getById(_event().id), isNull);
      expect(await events.pendingOutbox(), isEmpty);
    });
  });

  test(
    'queued RSVP losing server support releases later edits and reports refusal',
    () async {
      final server = _Server();
      await _withSync(server, (events, sync, provider) async {
        await provider.validateInviteResponse(
          _account,
          _event(),
          ResponseStatus.accepted,
        );
        await events.queueInviteResponse(_event(), ResponseStatus.accepted);
        await events.saveAndEnqueue(
          _event().copyWith(title: 'Later edit'),
          'update',
        );
        server.dav = '1, calendar-access';
        expect((await sync.syncAccount(_account)).ok, isFalse);
        expect(await events.pendingOutbox(), isEmpty);
        expect(provider.updates, 1);
        expect((await events.getById(_event().id))!.title, 'Later edit');
        expect(
          (await events.getById(_event().id))!.myResponse,
          ResponseStatus.needsAction,
        );
        expect(
          (await sync.accounts.allAccounts()).single.lastError,
          contains('не поддерживает'),
        );
      });
    },
  );

  test('failed delivery remains visible and queued until confirmed', () async {
    final server = _Server()..deliveryStatus = '5.1';
    await _withSync(server, (events, sync, provider) async {
      await events.queueInviteResponse(_event(), ResponseStatus.accepted);
      expect((await sync.syncAccount(_account)).ok, isFalse);
      expect(await events.pendingOutbox(), hasLength(1));
      expect(
        (await sync.accounts.allAccounts()).single.lastError,
        contains('5.1'),
      );
      server.deliveryStatus = '1.2';
      expect((await sync.syncAccount(_account)).ok, isTrue);
      expect(await events.pendingOutbox(), isEmpty);
      expect(server.lastPut.body, contains('SCHEDULE-FORCE-SEND=REPLY'));
    });
  });

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
            'RSVP=TRUE;PARTSTAT=${response.name.toUpperCase()}:mailto:ME@example.org',
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
    final headers = server.lastPut.options.headers;
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
    expect(server.lastPut.options.headers['If-Match'], '"new"');
    expect(server.lastPut.body, contains('SUMMARY:Changed remotely'));
  });

  test('retry after successful PUT does not send a duplicate reply', () async {
    final server = _Server();
    final provider = server.provider();
    await provider.respondToInvite(_account, _event(), ResponseStatus.accepted);
    // The server retains its delivery status after the first PUT.
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
      final body = server.lastPut.body;
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
    final events = parseIcs(server.lastPut.body);
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
    final body = server.lastPut.body;
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

  for (final response in [
    ResponseStatus.accepted,
    ResponseStatus.tentative,
    ResponseStatus.declined,
  ]) {
    for (final status in [
      '3.7',
      '3.8',
      '5.1',
      '5.2',
      '5.3',
      '1.0',
      '1.2,5.2',
      null,
    ]) {
      test(
        '$response with delivery status $status is not acknowledged',
        () async {
          final server = _Server()..deliveryStatus = status;
          final provider = server.provider();
          await expectLater(
            provider.respondToInvite(_account, _event(), response),
            throwsStateError,
          );
          final puts = server.requests
              .where((r) => r.options.method == 'PUT')
              .length;
          await expectLater(
            provider.respondToInvite(_account, _event(), response),
            throwsStateError,
          );
          expect(
            server.requests.where((r) => r.options.method == 'PUT'),
            hasLength(puts + (status == '5.1' ? 1 : 0)),
          );
        },
      );
    }
  }

  for (final status in ['1.1', '1.2', '2.0']) {
    test('confirmed delivery $status is idempotent', () async {
      final server = _Server()..deliveryStatus = status;
      final provider = server.provider();
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      expect(
        server.requests.where((r) => r.options.method == 'PUT'),
        hasLength(1),
      );
    });
  }

  test(
    'organizer RSVP flag is preserved and does not duplicate confirmed replies',
    () async {
      final server = _Server();
      server.afterPut = () =>
          server.body = server.body.replaceAll('RSVP=FALSE', 'RSVP=TRUE');
      final provider = server.provider();
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      expect(
        server.requests.where((r) => r.options.method == 'PUT'),
        hasLength(1),
      );
      expect(server.lastPut.body, contains('RSVP=TRUE'));
    },
  );

  test(
    'temporary delivery failure retries with REPLY and then becomes idempotent',
    () async {
      final server = _Server()..deliveryStatus = '5.1';
      final provider = server.provider();
      await expectLater(
        provider.respondToInvite(_account, _event(), ResponseStatus.accepted),
        throwsStateError,
      );
      server.deliveryStatus = '1.2';
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      expect(server.lastPut.body, contains('SCHEDULE-FORCE-SEND=REPLY'));
      expect(
        parseIcs(server.lastPut.body).single.attendees.last.email,
        'alarm@example.org',
      );
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      expect(
        server.requests.where((r) => r.options.method == 'PUT'),
        hasLength(2),
      );
    },
  );

  test('pending delivery is polled without sending another reply', () async {
    final server = _Server()..deliveryStatus = '1.0';
    final provider = server.provider();
    await expectLater(
      provider.respondToInvite(_account, _event(), ResponseStatus.accepted),
      throwsStateError,
    );
    server.body = server.body.replaceAll(
      'SCHEDULE-STATUS="1.0"',
      'SCHEDULE-STATUS="1.2"',
    );
    await provider.respondToInvite(_account, _event(), ResponseStatus.accepted);
    expect(
      server.requests.where((r) => r.options.method == 'PUT'),
      hasLength(1),
    );
  });

  test(
    'failed read after PUT retries by confirming delivery without duplicate PUT',
    () async {
      final server = _Server();
      server.afterPut = () => server.getStatus = 503;
      final provider = server.provider();
      await expectLater(
        provider.respondToInvite(_account, _event(), ResponseStatus.accepted),
        throwsA(isA<DioException>()),
      );
      server.getStatus = 200;
      await provider.respondToInvite(
        _account,
        _event(),
        ResponseStatus.accepted,
      );
      expect(
        server.requests.where((r) => r.options.method == 'PUT'),
        hasLength(1),
      );
    },
  );

  test(
    'recurring reply checks delivery on its exception, not on the master',
    () async {
      final server = _Server()
        ..body = _ics.replaceAll(
          'DTSTART:',
          'RRULE:FREQ=DAILY;COUNT=3\nDTSTART:',
        );
      server.afterPut = () {
        // The master succeeded earlier, but delivery for the new exception failed.
        final firstEnd = server.body.indexOf('END:VEVENT');
        server.body =
            server.body.substring(0, firstEnd) +
            server.body
                .substring(firstEnd)
                .replaceAll('SCHEDULE-STATUS="1.2"', 'SCHEDULE-STATUS="5.2"');
      };
      final day = DateTime.utc(2026, 9, 4, 10);
      await expectLater(
        server.provider().respondToInvite(
          _account,
          _event(recurrenceId: '${day.millisecondsSinceEpoch}', start: day),
          ResponseStatus.accepted,
        ),
        throwsStateError,
      );
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
