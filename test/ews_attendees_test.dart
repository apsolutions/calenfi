// Баг (задача KGR8E): у встреч Exchange после синхронизации не было
// участников — FindItem их не отдаёт, а GetItem запрашивал только Body.

import 'package:calenfi/data/providers/calendar/ews/ews_provider.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  const xml = '''<m:GetItemResponseMessage ResponseClass="Success"
 xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
 xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types">
<m:Items><t:CalendarItem>
<t:Organizer><t:Mailbox><t:Name>Иван Организатор</t:Name><t:EmailAddress>org@example.test</t:EmailAddress><t:RoutingType>SMTP</t:RoutingType></t:Mailbox></t:Organizer>
<t:RequiredAttendees>
 <t:Attendee><t:Mailbox><t:Name>Анна</t:Name><t:EmailAddress>anna@example.test</t:EmailAddress></t:Mailbox><t:ResponseType>Accept</t:ResponseType></t:Attendee>
 <t:Attendee><t:Mailbox><t:Name>Пётр</t:Name><t:EmailAddress>petr@example.test</t:EmailAddress></t:Mailbox><t:ResponseType>NoResponseReceived</t:ResponseType></t:Attendee>
 <t:Attendee><t:Mailbox><t:Name>Иван Организатор</t:Name><t:EmailAddress>org@example.test</t:EmailAddress></t:Mailbox><t:ResponseType>Organizer</t:ResponseType></t:Attendee>
 <t:Attendee><t:Mailbox><t:Name>Внутренний</t:Name><t:EmailAddress>/O=EXCHANGE/OU=X/CN=RECIPIENTS/CN=USER</t:EmailAddress><t:RoutingType>EX</t:RoutingType></t:Mailbox></t:Attendee>
</t:RequiredAttendees>
<t:OptionalAttendees>
 <t:Attendee><t:Mailbox><t:EmailAddress>maybe@example.test</t:EmailAddress></t:Mailbox><t:ResponseType>Tentative</t:ResponseType></t:Attendee>
</t:OptionalAttendees>
<t:Resources>
 <t:Attendee><t:Mailbox><t:Name>Переговорка 501</t:Name><t:EmailAddress>room501@example.test</t:EmailAddress></t:Mailbox><t:ResponseType>Decline</t:ResponseType></t:Attendee>
</t:Resources>
</t:CalendarItem></m:Items></m:GetItemResponseMessage>''';

  test('организатор, гости, необязательные и переговорка с ответами', () {
    final list = EwsProvider.parseAttendees(XmlDocument.parse(xml).rootElement);
    final by = {for (final a in list) a.email: a};

    expect(by.keys, [
      'org@example.test',
      'anna@example.test',
      'petr@example.test',
      'maybe@example.test',
      'room501@example.test',
    ], reason: 'организатор один раз, адрес без @ (legacy DN) пропущен');
    expect(by['org@example.test']!.isOrganizer, isTrue);
    expect(by['org@example.test']!.displayName, 'Иван Организатор');
    expect(by['anna@example.test']!.response, ResponseStatus.accepted);
    expect(by['petr@example.test']!.response, ResponseStatus.needsAction);
    expect(by['maybe@example.test']!.optional, isTrue);
    expect(by['maybe@example.test']!.response, ResponseStatus.tentative);
    expect(by['room501@example.test']!.isResource, isTrue);
    expect(by['room501@example.test']!.response, ResponseStatus.declined);
  });

  test('без участников — пустой список', () {
    const empty = '<m:GetItemResponseMessage xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages" xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"><m:Items><t:CalendarItem/></m:Items></m:GetItemResponseMessage>';
    expect(EwsProvider.parseAttendees(XmlDocument.parse(empty).rootElement), isEmpty);
  });
}
