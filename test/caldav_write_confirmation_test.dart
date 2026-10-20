import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/caldav/ics.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/attendee.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const account = Account(
  id: 'a',
  provider: ProviderType.caldav,
  displayName: 'Yandex',
  email: 'guest@example.test',
);
const calendar = Calendar(
  id: 'a|/calendars/guest/events-1/',
  accountId: 'a',
  name: 'Main',
  color: 0,
);
CalendarEvent eventAt(int hour) => CalendarEvent(
  id: 'a:events-1:meeting',
  calendarId: calendar.id,
  title: 'Meeting',
  startUtc: DateTime.utc(2026, 10, 20, hour),
  endUtc: DateTime.utc(2026, 10, 20, hour, 30),
  attendees: const [
    Attendee(email: 'host@example.test', isOrganizer: true),
    Attendee(email: 'guest@example.test', response: ResponseStatus.accepted),
  ],
  myResponse: ResponseStatus.accepted,
  source: EventSource(
    accountId: 'a',
    calendarId: calendar.id,
    providerEventId: '/calendars/guest/events-1/meeting.ics',
    etag: 'old',
  ),
);
String storedAt(int hour) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:meeting\r\nSUMMARY:Meeting\r\nDTSTART:20261020T${hour}0000Z\r\nDTEND:20261020T${hour}3000Z\r\nEND:VEVENT\r\nEND:VCALENDAR';

class _Server implements HttpClientAdapter {
  String? stored;
  String? sent;
  int getStatus = 200;
  int putStatus = 204;
  final methods = <String>[];
  final reachedRead = Completer<void>();
  Completer<void>? releaseRead;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    if (options.method == 'PUT') {
      sent = utf8.decode(
        await stream!.fold<List<int>>([], (a, b) => a..addAll(b)),
      );
      return ResponseBody.fromString(
        '',
        putStatus,
        headers: {
          'etag': ['put-version'],
        },
      );
    }
    if (!reachedRead.isCompleted) reachedRead.complete();
    await releaseRead?.future;
    return ResponseBody.fromString(
      stored ?? sent ?? '',
      getStatus,
      headers: {
        'etag': ['verified-version'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Provider extends CalDavProvider {
  _Provider(_Server server)
    : super(
        account: account,
        password: 'test',
        dio: Dio()..httpClientAdapter = server,
      );
  @override
  Future<List<Calendar>> listCalendars(Account acc) async => [calendar];
  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  ) async =>
      SyncResult(upserts: [eventAt(15)], deletedIds: [], newSyncState: 'v1');
}

void main() {
  test(
    'organizer outside ATTENDEE survives read and subsequent update',
    () async {
      final server = _Server();
      final provider = _Provider(server);
      final raw = storedAt(15).replaceFirst(
        'END:VEVENT',
        'ORGANIZER:mailto:host@example.test\r\nATTENDEE:mailto:guest@example.test\r\nEND:VEVENT',
      );
      final event = provider.buildEventForTest(
        account,
        calendar,
        parseIcs(raw).single,
      );
      expect(
        event.attendees.where((a) => a.isOrganizer).single.email,
        'host@example.test',
      );
      await provider.updateEvent(
        account,
        event.copyWith(
          startUtc: eventAt(16).startUtc,
          endUtc: eventAt(16).endUtc,
        ),
      );
      expect(server.sent, contains('ORGANIZER:mailto:host@example.test'));
    },
  );

  test(
    'successful PUT with unchanged server time is not acknowledged',
    () async {
      final server = _Server()..stored = storedAt(15);
      await expectLater(
        _Provider(server).updateEvent(account, eventAt(16)),
        throwsA(isA<StateError>()),
      );
      expect(server.methods, ['PUT', 'GET']);
    },
  );
  test(
    'confirmed move returns the readback ETag and keeps the organizer',
    () async {
      final server = _Server();
      final saved = await _Provider(server).updateEvent(account, eventAt(16));
      expect(saved.source.etag, 'verified-version');
      expect(saved.startUtc, eventAt(16).startUtc);
      expect(server.sent, contains('ORGANIZER:mailto:host@example.test'));
      expect(
        server.sent,
        isNot(contains('ORGANIZER:mailto:guest@example.test')),
      );
    },
  );
  for (final (label, response) in [
    ('empty', ''),
    ('wrong UID', storedAt(16).replaceAll('UID:meeting', 'UID:other')),
    ('wrong duration', storedAt(16).replaceAll('T163000Z', 'T170000Z')),
  ]) {
    test(
      'missing resource, different UID or different duration is not success: $label',
      () async {
        final server = _Server()..stored = response;
        await expectLater(
          _Provider(server).updateEvent(account, eventAt(16)),
          throwsA(isA<StateError>()),
        );
      },
    );
  }
  test('readback network error is not a successful write', () async {
    final server = _Server()..getStatus = 503;
    await expectLater(
      _Provider(server).updateEvent(account, eventAt(16)),
      throwsA(isA<DioException>()),
    );
  });
  test(
    '412 does not issue a verification read or acknowledge an edit',
    () async {
      final server = _Server()..putStatus = 412;
      await expectLater(
        _Provider(server).updateEvent(account, eventAt(16)),
        throwsA(isA<DioException>()),
      );
      expect(server.methods, ['PUT']);
    },
  );
  for (final newerEdit in [false, true]) {
    test(
      'ignored move remains dirty and queued across pull; newer edit=$newerEdit',
      () async {
        final server = _Server()
          ..stored = storedAt(15)
          ..releaseRead = Completer<void>();
        final db = AppDatabase(NativeDatabase.memory());
        final accounts = AccountRepository(db);
        final events = EventRepository(db);
        final engine = SyncEngine(
          registry: ProviderRegistry(overrideFactory: (_) => _Provider(server)),
          accounts: accounts,
          events: events,
        );
        addTearDown(() async {
          engine.dispose();
          await db.close();
        });
        await accounts.upsertAccount(account);
        await accounts.upsertCalendars([calendar]);
        await events.saveAndEnqueue(eventAt(16), 'update');
        final syncing = engine.syncAccount(account);
        await server.reachedRead.future;
        if (newerEdit) await events.saveAndEnqueue(eventAt(17), 'update');
        server.releaseRead!.complete();
        final report = await syncing;
        expect(report.ok, isFalse);
        expect(report.error, contains('не подтвердил'));
        expect(await events.pendingOutbox(), isNotEmpty);
        final row = (await db.select(db.events).get()).single;
        expect(row.dirty, isTrue);
        expect(await events.watchWriteState(row.id).first, (
          dirty: true,
          failed: true,
        ));
        expect(row.startUtc.toUtc(), eventAt(newerEdit ? 17 : 16).startUtc);
        expect(server.methods.where((m) => m == 'PUT'), hasLength(1));
      },
    );
  }
}
