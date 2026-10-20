import 'package:calenfi/data/providers/calendar/ews/ews_provider.dart';
import 'package:calenfi/data/providers/calendar/ews/ntlm_http.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

class _Bodies extends NtlmHttp {
  _Bodies(this.description, this.bodyType)
    : super(user: 'test', password: 'test');
  final String description;
  final String bodyType;
  @override
  Future<NtlmResponse> post(
    Uri url, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    const ns =
        'xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"';
    if (body.contains('<m:FindItem')) {
      return NtlmResponse(
        200,
        '<m:FindItemResponseMessage $ns><t:CalendarItem><t:ItemId Id="id"/><t:UID>uid</t:UID><t:Subject>Meeting</t:Subject><t:Start>2026-10-20T13:00:00Z</t:Start><t:End>2026-10-20T14:00:00Z</t:End></t:CalendarItem></m:FindItemResponseMessage>',
      );
    }
    final escaped = XmlText(description).toXmlString();
    return NtlmResponse(
      200,
      '<m:GetItemResponseMessage $ns ResponseClass="Success"><m:ResponseCode>NoError</m:ResponseCode><t:CalendarItem><t:Body BodyType="$bodyType">$escaped</t:Body></t:CalendarItem></m:GetItemResponseMessage>',
    );
  }
}

void main() {
  const account = Account(
    id: 'a',
    provider: ProviderType.ews,
    displayName: 'EWS',
    email: 'me@example.test',
  );
  Future<String?> read(String body, {String type = 'HTML'}) async {
    final provider = EwsProvider(
      account: account,
      password: 'test',
      ewsUrlOverride: 'https://example.test/ews',
      http: _Bodies(body, type),
    );
    final cal = (await provider.listCalendars(account)).single;
    final result = await provider.fetchEvents(
      account,
      cal,
      DateRange(DateTime.utc(2026, 10, 20), DateTime.utc(2026, 10, 21)),
    );
    return result.single.description;
  }

  test('hidden meeting href survives GetItem HTML conversion', () async {
    expect(
      await read(
        '<p>Video meeting</p><a href="https://video.example.test/join/123?x=1&amp;y=2"><span>Join(External)</span></a>',
      ),
      contains('Join(External) (https://video.example.test/join/123?x=1&y=2)'),
    );
  });
  test('uppercase and single-quoted multiline anchor survives', () async {
    expect(
      await read("<A\nHREF='https://video.example.test/join/123'>Join</A>"),
      contains('https://video.example.test/join/123'),
    );
  });
  test('unquoted href and numeric entities survive', () async {
    expect(
      await read(
        '<a href=https://video.example.test/join?x=1&#38;y=2>Join</a>',
      ),
      contains('?x=1&y=2'),
    );
  });
  test('visible URL is not duplicated', () async {
    expect(
      await read(
        '<a href="https://video.example.test/join">https://video.example.test/join</a>',
      ),
      'https://video.example.test/join',
    );
  });
  test('plain text angle brackets are not treated as HTML', () async {
    const text =
        'Host <person@example.test>\nhttps://video.example.test/join?a=1&b=2';
    expect(await read(text, type: 'Text'), text);
  });
  test('script and fragment href do not become launch links', () async {
    expect(
      await read(
        '<a href="javascript:alert(1)">Join</a><br><a href="#top">Top</a>',
      ),
      'Join\nTop',
    );
  });
}
