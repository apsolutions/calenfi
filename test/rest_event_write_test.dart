import 'package:calenfi/domain/models/attendee.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:calenfi/data/providers/calendar/google/google_provider.dart';
import 'package:calenfi/data/providers/calendar/caldav/caldav_provider.dart';
import 'package:calenfi/data/providers/calendar/token_exception.dart';
import 'package:calenfi/data/providers/calendar/google/google_token.dart';
import 'package:calenfi/data/providers/calendar/graph/graph_provider.dart';
import 'package:calenfi/data/providers/calendar/graph/graph_token.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Http implements HttpClientAdapter {
  int status = 200;
  String? calendarBody;
  final calls = <RequestOptions>[];
  Map<String, dynamic> body = {
    'id': 'server',
    'etag': 'v2',
    '@odata.etag': 'v2',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    if (options.method == 'PUT' && options.data is String && status < 300) {
      calendarBody = options.data as String;
    }
    final calendarRead = options.method == 'GET' && calendarBody != null;
    return ResponseBody.fromString(
      calendarRead ? calendarBody! : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          calendarRead ? 'text/calendar' : Headers.jsonContentType,
        ],
        'etag': ['v2'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final kind in [
    ProviderType.google,
    ProviderType.graph,
    ProviderType.caldav,
  ]) {
    group(kind.name, () {
      late _Http http;
      late CalendarProvider provider;
      late Account account;
      late CalendarEvent event;
      const calendar = Calendar(
        id: 'a|work',
        accountId: 'a',
        name: 'Work',
        color: 0,
      );
      setUp(() {
        account = Account(
          id: 'a',
          provider: kind,
          displayName: 'Test',
          email: 'me@example.test',
        );
        http = _Http();
        final dio = Dio()..httpClientAdapter = http;
        provider = kind == ProviderType.google
            ? GoogleProvider(
                account: account,
                dio: dio,
                token: GoogleToken(
                  clientId: 'test',
                  clientSecret: 'test',
                  refreshToken: 'test',
                  tokenUri: 'https://invalid.test',
                  accessToken: 'test',
                  expiry: DateTime.now().add(const Duration(hours: 1)),
                ),
              )
            : kind == ProviderType.caldav
            ? CalDavProvider(account: account, password: 'test', dio: dio)
            : GraphProvider(
                account: account,
                dio: dio,
                token: GraphToken(
                  clientId: 'test',
                  tenant: 'test',
                  refreshToken: 'test',
                  accessToken: 'test',
                  expiry: DateTime.now().add(const Duration(hours: 1)),
                ),
              );
        event = CalendarEvent(
          id: 'a:server',
          calendarId: calendar.id,
          title: 'Edited',
          startUtc: DateTime.utc(2026, 10, 18, 10),
          endUtc: DateTime.utc(2026, 10, 18, 11),
          source: EventSource(
            accountId: 'a',
            calendarId: calendar.id,
            providerEventId: 'server',
            etag: 'v1',
          ),
        );
      });
      CalendarEvent occurrence(CalendarEvent e) => CalendarEvent(
        id: e.id,
        calendarId: e.calendarId,
        title: e.title,
        startUtc: e.startUtc,
        endUtc: e.endUtc,
        source: e.source,
        recurrenceId: 'master',
        attendees: e.attendees,
      );
      for (final response in [
        ResponseStatus.accepted,
        ResponseStatus.tentative,
        ResponseStatus.declined,
      ]) {
        for (final recurring in [false, true]) {
          test(
            '${response.name} ${recurring ? "occurrence" : "meeting"}: ${kind == ProviderType.caldav ? "unsupported RSVP is explicit" : "sends only my response"}',
            () async {
              final invitation = (recurring ? occurrence(event) : event)
                  .copyWith(
                    attendees: const [
                      Attendee(email: 'ME@example.test'),
                      Attendee(
                        email: 'other@example.test',
                        response: ResponseStatus.accepted,
                        optional: true,
                      ),
                      Attendee(email: 'room@example.test', isResource: true),
                    ],
                  );
              if (kind == ProviderType.caldav) {
                await expectLater(
                  provider.respondToInvite(account, invitation, response),
                  throwsUnsupportedError,
                );
                expect(http.calls.single.method, 'OPTIONS');
                return;
              }
              await provider.respondToInvite(account, invitation, response);
              final call = http.calls.single;
              if (kind == ProviderType.google) {
                expect(call.method, 'PATCH');
                expect(call.path, endsWith('/events/server'));
                expect(call.data['attendeesOmitted'], isTrue);
                expect(call.data['attendees'], [
                  {'email': account.email, 'responseStatus': response.name},
                ]);
              } else {
                final action = {
                  ResponseStatus.accepted: 'accept',
                  ResponseStatus.tentative: 'tentativelyAccept',
                  ResponseStatus.declined: 'decline',
                }[response];
                expect(call.method, 'POST');
                expect(call.path, endsWith('/events/server/$action'));
                expect(call.data, {'sendResponse': true});
              }
            },
          );
        }
        if (kind != ProviderType.caldav) {
          for (final status in [401, 403, 412, 429, 500]) {
            test('${response.name} HTTP $status remains an error', () async {
              http.status = status;
              await expectLater(
                provider.respondToInvite(account, event, response),
                throwsA(isA<DioException>()),
              );
              expect(http.calls, hasLength(1));
            });
          }
          test(
            '${response.name} without server identity cannot silently succeed',
            () async {
              final local = event.copyWith(
                source: const EventSource(accountId: 'a', calendarId: 'a|work'),
              );
              await expectLater(
                provider.respondToInvite(account, local, response),
                throwsStateError,
              );
              expect(http.calls, isEmpty);
            },
          );
        }
      }
      if (kind == ProviderType.google) {
        test('RSVP works when cached attendee list is omitted', () async {
          await provider.respondToInvite(
            account,
            event,
            ResponseStatus.tentative,
          );
          expect(http.calls.single.data, {
            'attendees': [
              {'email': account.email, 'responseStatus': 'tentative'},
            ],
            'attendeesOmitted': true,
          });
        });
      }
      if (kind != ProviderType.caldav) {
        for (final scope in [RecurrenceScope.thisOnly, RecurrenceScope.all]) {
          test(
            'cancel $scope targets the requested occurrence or master',
            () async {
              await provider.deleteEvent(account, occurrence(event), scope);
              expect(http.calls.single.method, 'DELETE');
              expect(
                http.calls.single.path,
                endsWith(
                  '/events/${scope == RecurrenceScope.all ? "master" : "server"}',
                ),
              );
            },
          );
        }
        for (final status in [401, 403, 412, 429, 500]) {
          test('cancel HTTP $status does not pretend success', () async {
            http.status = status;
            await expectLater(
              provider.deleteEvent(account, event, RecurrenceScope.all),
              throwsA(isA<DioException>()),
            );
          });
        }
        for (final allDay in [false, true]) {
          test(
            'move ${allDay ? "all-day" : "timed"} meeting sends the new interval',
            () async {
              final moved = event.copyWith(
                startUtc: DateTime.utc(2026, 10, 20, allDay ? 0 : 15),
                endUtc: DateTime.utc(2026, 10, 21, allDay ? 0 : 16),
                allDay: allDay,
              );
              final result = await provider.updateEvent(account, moved);
              expect(result.startUtc, moved.startUtc);
              expect(result.endUtc, moved.endUtc);
              final body = http.calls.single.data as Map;
              expect(
                body['start'][kind == ProviderType.google && allDay
                    ? 'date'
                    : 'dateTime'],
                startsWith('2026-10-20'),
              );
              expect(
                body['end'][kind == ProviderType.google && allDay
                    ? 'date'
                    : 'dateTime'],
                startsWith('2026-10-21'),
              );
              expect(http.calls.single.path, endsWith('/events/server'));
            },
          );
        }
      }
      for (final status in [400, 401, 403, 404, 409, 412, 429, 500]) {
        test('HTTP $status never acknowledges an update', () async {
          http.status = status;
          await expectLater(
            provider.updateEvent(account, event),
            throwsA(isA<DioException>()),
          );
          expect(
            http.calls.single.method,
            kind == ProviderType.caldav ? 'PUT' : 'PATCH',
          );
        });
      }
      test(
        'update retains identity and returns new ETag for subsequent write',
        () async {
          final updated = await provider.updateEvent(account, event);
          if (kind != ProviderType.caldav) expect(updated.id, event.id);
          expect(updated.source.providerEventId, isNotNull);
          expect(updated.source.etag, 'v2');
          expect(http.calls.first.headers['If-Match'], 'v1');
          expect(
            http.calls.map((call) => call.method),
            kind == ProviderType.caldav ? ['PUT', 'GET'] : ['PATCH'],
          );
        },
      );
      if (kind != ProviderType.caldav) {
        test(
          'clearing location, description and attendees is sent explicitly',
          () async {
            await provider.updateEvent(account, event);
            final body = http.calls.single.data as Map;
            expect(body['attendees'], isEmpty);
            if (kind == ProviderType.google) {
              expect(body['location'], '');
              expect(body['description'], '');
            } else {
              expect(body['location']['displayName'], '');
              expect(body['body']['content'], '');
            }
          },
        );
        test('revoked refresh token still reports reconnect', () async {
          http.status = 400;
          http.body = {'error': 'invalid_grant'};
          if (provider is GoogleProvider) {
            (provider as GoogleProvider).token.expiry = DateTime.utc(2000);
          } else {
            (provider as GraphProvider).token.expiry = DateTime.utc(2000);
          }
          await expectLater(
            provider.updateEvent(account, event),
            throwsA(isA<TokenExpiredException>()),
          );
          expect(http.calls.single.method, 'POST');
        });
        test('rejected pull cannot masquerade as empty calendar', () async {
          http.status = 403;
          await expectLater(
            provider.fetchEvents(
              account,
              calendar,
              DateRange(DateTime.utc(2026), DateTime.utc(2027)),
            ),
            throwsA(isA<DioException>()),
          );
        });
        test('rejected delete stays an error', () async {
          http.status = 403;
          await expectLater(
            provider.deleteEvent(account, event, RecurrenceScope.thisOnly),
            throwsA(isA<DioException>()),
          );
        });
        test('rejected RSVP stays an error', () async {
          http.status = 429;
          await expectLater(
            provider.respondToInvite(account, event, ResponseStatus.accepted),
            throwsA(isA<DioException>()),
          );
        });
      }
    });
  }
}
