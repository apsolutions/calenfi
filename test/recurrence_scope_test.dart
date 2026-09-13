// Правка вхождения повторяющейся серии: «только это» должно уходить PATCH-ем
// по id вхождения, «вся серия» — по id мастера и СДВИГОМ на дельту правки
// (иначе серия переезжает на дату того вхождения, которое тянули мышью).

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/providers/calendar/google/google_provider.dart';
import 'package:calenfi/data/providers/calendar/google/google_token.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/attendee.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Call {
  _Call(this.method, this.path, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> body;
}

class _GoogleAdapter implements HttpClientAdapter {
  _GoogleAdapter(this.master);

  final Map<String, dynamic> master;
  final calls = <_Call>[];

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
    final raw = utf8.decode(bytes);
    calls.add(
      _Call(
        options.method,
        options.uri.path,
        raw.isEmpty
            ? const {}
            : (jsonDecode(raw) as Map).cast<String, dynamic>(),
      ),
    );
    final payload = options.method == 'GET' ? master : {'id': 'ok'};
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const account = Account(
    id: 'acc-google',
    provider: ProviderType.google,
    displayName: 'Google',
    email: 'me@example.com',
  );

  GoogleProvider providerWith(_GoogleAdapter adapter) => GoogleProvider(
    account: account,
    token: GoogleToken(
      clientId: 'id',
      clientSecret: 'secret',
      refreshToken: 'refresh',
      tokenUri: 'https://oauth2.googleapis.com/token',
      accessToken: 'access',
      expiry: DateTime.now().add(const Duration(hours: 1)),
    ),
    dio: Dio()..httpClientAdapter = adapter,
  );

  /// Вхождение серии 13 сентября, перенесённое пользователем с 11:00 на 11:15.
  CalendarEvent movedOccurrence() => CalendarEvent(
    id: 'acc-google:master_20260913T110000Z',
    calendarId: 'acc-google|primary',
    title: 'Тренировка',
    startUtc: DateTime.utc(2026, 9, 13, 11, 15),
    endUtc: DateTime.utc(2026, 9, 13, 12, 15),
    recurrenceId: 'master',
    source: const EventSource(
      accountId: 'acc-google',
      calendarId: 'acc-google|primary',
      providerEventId: 'master_20260913T110000Z',
    ),
  );

  Map<String, dynamic> masterJson() => {
    'id': 'master',
    'summary': 'Тренировка',
    'start': {'dateTime': '2026-08-30T11:00:00Z'},
    'end': {'dateTime': '2026-08-30T12:00:00Z'},
    'recurrence': ['RRULE:FREQ=WEEKLY;BYDAY=SU'],
  };

  test('«только это» правит вхождение и мастера не трогает', () async {
    final adapter = _GoogleAdapter(masterJson());
    await providerWith(adapter).updateEvent(account, movedOccurrence());

    expect(adapter.calls.length, 1);
    expect(adapter.calls.single.method, 'PATCH');
    expect(
      adapter.calls.single.path,
      endsWith('/events/master_20260913T110000Z'),
    );
  });

  test('«вся серия» сдвигает мастера на дельту правки, а не на дату вхождения',
      () async {
    final adapter = _GoogleAdapter(masterJson());
    await providerWith(adapter).updateEvent(
      account,
      movedOccurrence(),
      scope: RecurrenceScope.all,
      originalStartUtc: DateTime.utc(2026, 9, 13, 11),
    );

    expect(adapter.calls.map((c) => c.method).toList(), ['GET', 'PATCH']);
    final patch = adapter.calls.last;
    expect(patch.path, endsWith('/events/master'));
    // Мастер начинался 30 августа в 11:00 — после переноса вхождения на
    // +15 минут он обязан остаться 30 августа, но в 11:15.
    expect(patch.body['start']['dateTime'], '2026-08-30T11:15:00.000Z');
    expect(patch.body['end']['dateTime'], '2026-08-30T12:15:00.000Z');
    // Правило серии остаётся серверным: перезаписывать его правкой нельзя.
    expect(patch.body.containsKey('recurrence'), isFalse);
  });

  test('дельта берётся из id вхождения, когда исходное время не передали',
      () async {
    final adapter = _GoogleAdapter(masterJson());
    await providerWith(adapter)
        .updateEvent(account, movedOccurrence(), scope: RecurrenceScope.all);

    final patch = adapter.calls.last;
    expect(patch.body['start']['dateTime'], '2026-08-30T11:15:00.000Z');
  });

  test('перенос серии не переотправляет тот же список участников', () async {
    final withAttendees = Map<String, dynamic>.from(masterJson())
      ..['attendees'] = [
        {'email': 'guest@example.com'},
      ];
    final adapter = _GoogleAdapter(withAttendees);
    final occurrence = CalendarEvent(
      id: 'acc-google:master_20260913T110000Z',
      calendarId: 'acc-google|primary',
      title: 'Тренировка',
      startUtc: DateTime.utc(2026, 9, 13, 11, 15),
      endUtc: DateTime.utc(2026, 9, 13, 12, 15),
      recurrenceId: 'master',
      attendees: const [Attendee(email: 'guest@example.com')],
      source: const EventSource(
        accountId: 'acc-google',
        calendarId: 'acc-google|primary',
        providerEventId: 'master_20260913T110000Z',
      ),
    );

    await providerWith(adapter)
        .updateEvent(account, occurrence, scope: RecurrenceScope.all);

    expect(adapter.calls.last.body.containsKey('attendees'), isFalse);
  });

  test('изменённый состав участников серии всё-таки отправляется', () async {
    final adapter = _GoogleAdapter(masterJson());
    final occurrence = CalendarEvent(
      id: 'acc-google:master_20260913T110000Z',
      calendarId: 'acc-google|primary',
      title: 'Тренировка',
      startUtc: DateTime.utc(2026, 9, 13, 11),
      endUtc: DateTime.utc(2026, 9, 13, 12),
      recurrenceId: 'master',
      attendees: const [Attendee(email: 'new@example.com')],
      source: const EventSource(
        accountId: 'acc-google',
        calendarId: 'acc-google|primary',
        providerEventId: 'master_20260913T110000Z',
      ),
    );

    await providerWith(adapter)
        .updateEvent(account, occurrence, scope: RecurrenceScope.all);

    expect(adapter.calls.last.body['attendees'], [
      {'email': 'new@example.com'},
    ]);
  });

  test('перенос на другой день сдвигает серию на те же сутки', () async {
    final adapter = _GoogleAdapter(masterJson());
    final moved = CalendarEvent(
      id: 'acc-google:master_20260913T110000Z',
      calendarId: 'acc-google|primary',
      title: 'Тренировка',
      startUtc: DateTime.utc(2026, 9, 14, 11),
      endUtc: DateTime.utc(2026, 9, 14, 12),
      recurrenceId: 'master',
      source: const EventSource(
        accountId: 'acc-google',
        calendarId: 'acc-google|primary',
        providerEventId: 'master_20260913T110000Z',
      ),
    );
    await providerWith(adapter)
        .updateEvent(account, moved, scope: RecurrenceScope.all);

    expect(
      adapter.calls.last.body['start']['dateTime'],
      '2026-08-31T11:00:00.000Z',
    );
  });
}
