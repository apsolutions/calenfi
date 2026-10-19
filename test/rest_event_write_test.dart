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
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
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
          expect(http.calls.single.headers['If-Match'], 'v1');
          expect(
            http.calls.single.method,
            kind == ProviderType.caldav ? 'PUT' : 'PATCH',
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
