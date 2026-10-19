import 'package:calenfi/data/providers/calendar/ews/ews_provider.dart';
import 'package:calenfi/data/providers/calendar/ews/ntlm_http.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transport extends NtlmHttp {
  _Transport() : super(user: 'test', password: 'test');
  int status = 200;
  String code = 'NoError';
  final bodies = <String>[];
  @override
  Future<NtlmResponse> post(
    Uri url, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    bodies.add(body);
    return NtlmResponse(
      status,
      '<m:UpdateItemResponseMessage xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages" xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" ResponseClass="${code == "NoError" ? "Success" : "Error"}"><m:ResponseCode>$code</m:ResponseCode><m:Items><t:CalendarItem><t:ItemId Id="server" ChangeKey="v2"/></t:CalendarItem></m:Items></m:UpdateItemResponseMessage>',
    );
  }
}

void main() {
  const account = Account(
    id: 'a',
    provider: ProviderType.ews,
    displayName: 'EWS',
    email: 'a@example.test',
  );
  late _Transport http;
  late EwsProvider provider;
  late CalendarEvent event;
  setUp(() {
    http = _Transport();
    provider = EwsProvider(
      account: account,
      password: 'test',
      ewsUrlOverride: 'https://invalid.test/EWS',
      http: http,
    );
    event = CalendarEvent(
      id: 'a:server',
      calendarId: 'a|calendar',
      title: 'Edited & <escaped>',
      startUtc: DateTime.utc(2026, 10, 18, 10),
      endUtc: DateTime.utc(2026, 10, 18, 11),
      source: const EventSource(
        accountId: 'a',
        calendarId: 'a|calendar',
        providerEventId: 'server',
        etag: 'v1',
      ),
    );
  });
  test(
    'UpdateItem keeps identity, escapes content and rotates ChangeKey',
    () async {
      final result = await provider.updateEvent(account, event);
      expect(result.id, event.id);
      expect(result.source.etag, 'v2');
      expect(http.bodies.single, contains('ChangeKey="v1"'));
      expect(http.bodies.single, contains('Edited &amp; &lt;escaped&gt;'));
      expect(http.bodies.single, contains('<m:UpdateItem'));
      expect(http.bodies.single, isNot(contains('<m:CreateItem')));
    },
  );
  for (final code in [
    'ErrorAccessDenied',
    'ErrorChangeKeyRequired',
    'ErrorIrresolvableConflict',
    'ErrorItemNotFound',
    'ErrorServerBusy',
  ]) {
    test('SOAP $code is never acknowledged', () async {
      http.code = code;
      await expectLater(
        provider.updateEvent(account, event),
        throwsA(anything),
      );
    });
  }
  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status is never acknowledged', () async {
      http.status = status;
      await expectLater(
        provider.updateEvent(account, event),
        throwsA(anything),
      );
    });
  }
}
