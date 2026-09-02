import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  const _Request(this.method, this.uri, this.body, this.headers);

  final String method;
  final Uri uri;
  final String body;
  final Map<String, dynamic> headers;
}

class _LostCreateResponseAdapter implements HttpClientAdapter {
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

    if (options.method == 'PUT') {
      // Предыдущий PUT уже создал ресурс, но его успешный ответ был потерян.
      return ResponseBody.fromString('precondition failed', 412);
    }
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        '''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VEVENT\r
UID:local-uuid-1\r
DTSTART:20260828T120000Z\r
DTEND:20260828T130000Z\r
SUMMARY:Новая встреча\r
END:VEVENT\r
END:VCALENDAR\r
''',
        200,
        headers: {
          'etag': ['etag-after-lost-response'],
        },
      );
    }
    throw StateError('unexpected ${options.method} ${options.uri}');
  }

  @override
  void close({bool force = false}) {}
}

class _RetryCalDavProvider extends CalDavProvider {
  _RetryCalDavProvider({
    required super.account,
    required super.password,
    required super.dio,
    required this.calendar,
  });

  final Calendar calendar;
  CalendarEvent? remote;

  @override
  Future<List<Calendar>> listCalendars(Account acc) async => [calendar];

  @override
  Future<CalendarEvent> createEvent(
    Account acc,
    Calendar cal,
    CalendarEvent event,
  ) async {
    final created = await super.createEvent(acc, cal, event);
    remote = created;
    return created;
  }

  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  ) async => SyncResult(
    upserts: remote == null ? const [] : [remote!],
    deletedIds: const [],
    newSyncState: 'synced',
  );
}

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

  test(
    '412 после потерянного create подтверждает UID, rekey и очищает outbox',
    () async {
      final adapter = _LostCreateResponseAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final provider = _RetryCalDavProvider(
        account: account,
        password: 'x',
        dio: dio,
        calendar: calendar,
      );
      final db = AppDatabase(NativeDatabase.memory());
      final accounts = AccountRepository(db);
      final events = EventRepository(db);
      final engine = SyncEngine(
        registry: ProviderRegistry(overrideFactory: (_) => provider),
        accounts: accounts,
        events: events,
      );
      addTearDown(() async {
        engine.dispose();
        await db.close();
      });

      await accounts.upsertAccount(account);
      const localId = 'local-uuid-1';
      final local = CalendarEvent(
        id: localId,
        calendarId: calendar.id,
        title: 'Новая встреча',
        startUtc: DateTime.utc(2026, 8, 28, 12),
        endUtc: DateTime.utc(2026, 8, 28, 13),
        source: const EventSource(
          accountId: 'acc-yandex',
          calendarId: 'acc-yandex|/calendars/me%40example.org/events-10922764/',
          providerEventId: localId,
        ),
      );
      await accounts.upsertCalendars(const [calendar]);
      await events.putLocalDirty(local);
      await events.enqueue('create', local.id);

      final report = await engine.syncAccount(account);

      expect(report.ok, isTrue);
      expect(await events.pendingOutbox(), isEmpty);
      expect(await events.getById(localId), isNull);
      final rows = await db.select(db.events).get();
      expect(
        rows,
        hasLength(1),
        reason: 'локальный UUID не должен стать дублем',
      );
      expect(rows.single.id, 'acc-yandex:events-10922764:local-uuid-1');
      expect(rows.single.providerEventId, endsWith('/local-uuid-1.ics'));
      expect(rows.single.etag, 'etag-after-lost-response');
      expect(rows.single.dirty, isFalse);

      expect(adapter.requests.map((request) => request.method), ['PUT', 'GET']);
      expect(adapter.requests.first.headers['If-None-Match'], '*');
      expect(adapter.requests.first.body, contains('UID:local-uuid-1\n'));
      expect(adapter.requests.map((request) => request.uri.path).toSet(), {
        '/calendars/me%40example.org/events-10922764/local-uuid-1.ics',
      });
    },
  );
}
