import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/caldav/ics.dart';
import 'package:calenfi/data/providers/conference/conference_provisioner.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/data/secure/credential_source.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/yandex_caldav.dart';
import 'package:calenfi/features/event_editor/conference_options.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  const _Request(this.method, this.body);

  final String method;
  final String body;
}

class _RecordingAdapter implements HttpClientAdapter {
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
    requests.add(_Request(options.method, utf8.decode(bytes)));
    return ResponseBody.fromString('', options.method == 'PUT' ? 201 : 200);
  }

  @override
  void close({bool force = false}) {}
}

class _TelemostEndpointAdapter implements HttpClientAdapter {
  Uri? requestedUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUri = options.uri;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 'conference-id',
        'join_url': 'https://telemost.yandex.ru/j/conference-id',
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _yandex = Account(
  id: 'acc-yandex',
  provider: ProviderType.caldav,
  displayName: 'Yandex 360',
  email: 'ki@apsolutions.ru',
  config: AccountConfig(caldavHost: 'caldav.yandex.ru', caldavPort: 8443),
);

const _otherCalDav = Account(
  id: 'acc-other',
  provider: ProviderType.caldav,
  displayName: 'Other CalDAV',
  email: 'ki@example.test',
  config: AccountConfig(caldavHost: 'calendar.example.test'),
);

const _yandexCalendar = Calendar(
  id: 'acc-yandex|/calendars/ki%40apsolutions.ru/events-default/',
  accountId: 'acc-yandex',
  name: 'Рабочий',
  color: 0,
);

const _otherCalendar = Calendar(
  id: 'acc-other|/calendar/',
  accountId: 'acc-other',
  name: 'Other',
  color: 0,
);

CalendarEvent _event({
  required Calendar calendar,
  required Conference conference,
  String? description,
}) => CalendarEvent(
  id: 'local-uid',
  calendarId: calendar.id,
  title: 'Встреча',
  startUtc: DateTime.utc(2030, 1, 1, 10),
  endUtc: DateTime.utc(2030, 1, 1, 11),
  description: description,
  conference: conference,
  source: EventSource(
    accountId: calendar.accountId,
    calendarId: calendar.id,
    providerEventId: '/calendar/local-uid.ics',
  ),
);

Dio _dio(_RecordingAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  test('ki@apsolutions.ru gets account-scoped native Telemost option', () {
    expect(isYandexCalDavAccount(_yandex), isTrue);
    expect(
      isYandexCalDavAccount(
        const Account(
          id: 'trailing-dot',
          provider: ProviderType.caldav,
          displayName: 'Yandex',
          email: 'employee@business.example',
          config: AccountConfig(caldavHost: 'CALDAV.YANDEX.RU.'),
        ),
      ),
      isTrue,
    );
    expect(
      isYandexCalDavAccount(
        const Account(
          id: 'default-host',
          provider: ProviderType.caldav,
          displayName: 'Yandex',
          email: 'employee@business.example',
        ),
      ),
      isTrue,
    );
    expect(isYandexCalDavAccount(_otherCalDav), isFalse);

    final selected = yandexTelemostAccountForCalendar(
      calendarId: _yandexCalendar.id,
      calendars: const [_yandexCalendar, _otherCalendar],
      accounts: const [_yandex, _otherCalDav],
    );
    expect(selected?.id, _yandex.id);
    expect(selected?.email, 'ki@apsolutions.ru');

    expect(
      yandexTelemostAccountForCalendar(
        calendarId: _otherCalendar.id,
        calendars: const [_yandexCalendar, _otherCalendar],
        accounts: const [_yandex, _otherCalDav],
      ),
      isNull,
    );
  });

  test(
    'provisioner routes Yandex Telemost natively without OAuth token',
    () async {
      final provisioner = ConferenceProvisioner(
        credentials: CredentialSource.empty(),
      );

      final conference = await provisioner.resolve(
        ConferenceType.telemost,
        accountId: _yandex.id,
        target: _yandex,
        allAccounts: const [_yandex],
        start: DateTime.utc(2030, 1, 1, 10),
        end: DateTime.utc(2030, 1, 1, 11),
        subject: 'Встреча',
      );

      expect(conference.isReady, isFalse);
      expect(conference.accountId, _yandex.id);

      final withoutExplicitHost = await provisioner.resolve(
        ConferenceType.telemost,
        target: _yandex,
        allAccounts: const [_yandex],
        start: DateTime.utc(2030, 1, 1, 10),
        end: DateTime.utc(2030, 1, 1, 11),
        subject: 'Встреча из CLI',
      );
      expect(withoutExplicitHost.accountId, _yandex.id);
      expect(
        ConferenceProvisioner.nativeCapable(
          ConferenceType.telemost,
          _otherCalDav,
        ),
        isFalse,
      );
    },
  );

  test('CLI-style pending Telemost reaches CalDAV as an explicit request', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final provisioner = ConferenceProvisioner(
      credentials: CredentialSource.empty(),
    );
    final event = _event(
      calendar: _yandexCalendar,
      conference: const Conference.pending(ConferenceType.telemost),
    );

    final resolved = await provisioner.ensure(
      event,
      target: _yandex,
      allAccounts: const [_yandex],
      events: EventRepository(db),
    );
    expect(resolved.conference?.accountId, _yandex.id);

    final adapter = _RecordingAdapter();
    final provider = CalDavProvider(
      account: _yandex,
      password: 'app-password',
      dio: _dio(adapter),
    );
    await provider.createEvent(_yandex, _yandexCalendar, resolved);
    expect(
      adapter.requests.single.body,
      contains('X-TELEMOST-REQUIRED:TRUE\n'),
    );
  });

  test('Yandex create emits X-TELEMOST-REQUIRED', () async {
    final adapter = _RecordingAdapter();
    final provider = CalDavProvider(
      account: _yandex,
      password: 'app-password',
      dio: _dio(adapter),
    );

    await provider.createEvent(
      _yandex,
      _yandexCalendar,
      _event(
        calendar: _yandexCalendar,
        conference: const Conference.pending(
          ConferenceType.telemost,
          accountId: 'acc-yandex',
        ),
      ),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'PUT');
    expect(
      adapter.requests.single.body,
      contains('X-TELEMOST-REQUIRED:TRUE\n'),
    );
    expect(
      adapter.requests.single.body,
      isNot(contains('X-TELEMOST-CONFERENCE:')),
    );
  });

  test(
    'standalone fallback uses the documented Telemost REST endpoint',
    () async {
      final adapter = _TelemostEndpointAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final provisioner = ConferenceProvisioner(
        dio: dio,
        credentials: CredentialSource.fromMap(const {
          'TELEMOST_OAUTH_TOKEN': 'test-token',
        }),
      );

      await provisioner.resolve(
        ConferenceType.telemost,
        target: null,
        allAccounts: const [],
        start: DateTime.utc(2030, 1, 1, 10),
        end: DateTime.utc(2030, 1, 1, 11),
        subject: 'Встреча',
      );

      expect(
        adapter.requestedUri,
        Uri.parse('https://cloud-api.yandex.net/v1/telemost-api/conferences'),
      );
    },
  );

  test(
    'Yandex update requests Telemost without echoing response-only field',
    () async {
      final adapter = _RecordingAdapter();
      final provider = CalDavProvider(
        account: _yandex,
        password: 'app-password',
        dio: _dio(adapter),
      );
      const url = 'https://telemost.yandex.ru/j/78566269088286';

      await provider.updateEvent(
        _yandex,
        _event(
          calendar: _yandexCalendar,
          description: 'Ссылка на видеовстречу: $url\n\nПовестка',
          conference: const Conference(
            type: ConferenceType.telemost,
            joinUrl: url,
            meetingId: '78566269088286',
            accountId: 'acc-yandex',
          ),
        ),
      );

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.body,
        contains('X-TELEMOST-REQUIRED:TRUE\n'),
      );
      expect(adapter.requests.single.body, contains(url));
      expect(
        RegExp(RegExp.escape(url)).allMatches(adapter.requests.single.body),
        hasLength(1),
        reason: 'повторная правка не должна дублировать Telemost URL',
      );
      expect(
        adapter.requests.single.body,
        isNot(contains('X-TELEMOST-CONFERENCE:')),
      );
    },
  );

  test('arbitrary CalDAV never receives the Yandex-only marker', () async {
    final adapter = _RecordingAdapter();
    final provider = CalDavProvider(
      account: _otherCalDav,
      password: 'app-password',
      dio: _dio(adapter),
    );

    await provider.createEvent(
      _otherCalDav,
      _otherCalendar,
      _event(
        calendar: _otherCalendar,
        conference: const Conference.pending(ConferenceType.telemost),
      ),
    );

    expect(
      adapter.requests.single.body,
      isNot(contains('X-TELEMOST-REQUIRED')),
    );
  });

  test('external Telemost URL does not request a new Yandex meeting', () async {
    final adapter = _RecordingAdapter();
    final provider = CalDavProvider(
      account: _yandex,
      password: 'app-password',
      dio: _dio(adapter),
    );

    await provider.updateEvent(
      _yandex,
      _event(
        calendar: _yandexCalendar,
        conference: const Conference(
          type: ConferenceType.telemost,
          joinUrl: 'https://telemost.yandex.ru/j/external-meeting',
        ),
      ),
    );

    expect(adapter.requests.single.body, contains('external-meeting'));
    expect(
      adapter.requests.single.body,
      isNot(contains('X-TELEMOST-REQUIRED')),
    );
  });

  test('X-TELEMOST-CONFERENCE is parsed into a ready conference', () {
    const url = 'https://telemost.yandex.ru/j/78566269088286';
    final parsed = parseIcs('''BEGIN:VCALENDAR\r
BEGIN:VEVENT\r
UID:remote-uid\r
DTSTART:20300101T100000Z\r
DTEND:20300101T110000Z\r
SUMMARY:Встреча\r
X-TELEMOST-CONFERENCE:$url\r
END:VEVENT\r
END:VCALENDAR\r
''').single;
    final provider = CalDavProvider(account: _yandex, password: 'x');
    final event = provider.buildEventForTest(_yandex, _yandexCalendar, parsed);

    expect(parsed.telemostConferenceUrl, url);
    expect(event.conference?.type, ConferenceType.telemost);
    expect(event.conference?.joinUrl, url);
    expect(event.conference?.meetingId, '78566269088286');
    expect(event.conference?.accountId, _yandex.id);
  });
}
