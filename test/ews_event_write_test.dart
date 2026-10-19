import 'package:xml/xml.dart';
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
  for (final response in [
    ResponseStatus.accepted,
    ResponseStatus.tentative,
    ResponseStatus.declined,
  ]) {
    test('${response.name} sends a response to the original meeting', () async {
      await provider.respondToInvite(account, event, response);
      final verb = {
        ResponseStatus.accepted: 'AcceptItem',
        ResponseStatus.tentative: 'TentativelyAcceptItem',
        ResponseStatus.declined: 'DeclineItem',
      }[response];
      expect(http.bodies.single, contains('<t:$verb>'));
      expect(
        http.bodies.single,
        contains('<t:ReferenceItemId Id="server" ChangeKey="v1"'),
      );
      expect(
        http.bodies.single,
        contains('MessageDisposition="SendAndSaveCopy"'),
      );
      expect(http.bodies.single, isNot(contains('<t:CalendarItem>')));
    });
    for (final code in [
      'ErrorAccessDenied',
      'ErrorIrresolvableConflict',
      'ErrorItemNotFound',
      'ErrorServerBusy',
    ]) {
      test('${response.name} SOAP $code is not acknowledged', () async {
        http.code = code;
        await expectLater(
          provider.respondToInvite(account, event, response),
          throwsA(anything),
        );
      });
    }
    test('${response.name} missing server identity is an error', () async {
      await expectLater(
        provider.respondToInvite(
          account,
          event.copyWith(
            source: const EventSource(accountId: 'a', calendarId: 'a|calendar'),
          ),
          response,
        ),
        throwsStateError,
      );
      expect(http.bodies, isEmpty);
    });
  }
  test(
    'rescheduling an organized meeting sends updates to attendees',
    () async {
      final moved = event.copyWith(
        startUtc: DateTime.utc(2026, 10, 19, 12),
        endUtc: DateTime.utc(2026, 10, 19, 13),
      );
      await provider.updateEvent(account, moved);
      expect(
        DateTime.parse(
          XmlDocument.parse(
            http.bodies.single,
          ).findAllElements('t:Start').single.innerText,
        ),
        moved.startUtc,
      );
      expect(
        http.bodies.single,
        contains(
          'SendMeetingInvitationsOrCancellations="SendToAllAndSaveCopy"',
        ),
      );
    },
  );
  test('organizer cancellation notifies attendees', () async {
    await provider.deleteEvent(account, event, RecurrenceScope.all);
    expect(http.bodies.single, contains('<m:DeleteItem'));
    expect(
      http.bodies.single,
      contains('SendMeetingCancellations="SendToAllAndSaveCopy"'),
    );
  });
  test(
    'deleting my invited copy never cancels the meeting for everyone',
    () async {
      await provider.deleteEvent(
        account,
        event.copyWith(myResponse: ResponseStatus.accepted),
        RecurrenceScope.thisOnly,
      );
      expect(
        http.bodies.single,
        contains('SendMeetingCancellations="SendToNone"'),
      );
    },
  );
  for (final code in [
    'ErrorAccessDenied',
    'ErrorCannotDeleteObject',
    'ErrorIrresolvableConflict',
    'ErrorServerBusy',
  ]) {
    test('cancel SOAP $code remains a failure', () async {
      http.code = code;
      await expectLater(
        provider.deleteEvent(account, event, RecurrenceScope.all),
        throwsA(anything),
      );
    });
  }
  test('already absent meeting cancellation is idempotent', () async {
    http.code = 'ErrorItemNotFound';
    await provider.deleteEvent(account, event, RecurrenceScope.all);
  });
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
