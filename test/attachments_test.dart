// Запрос: «у яндекса теперь есть вложения, надо добавить их в поля calenfi».
// Проверяем сквозной путь: ATTACH в ICS → поле attachments → карточка события,
// плюс вложения Google. Встроенные (VALUE=BINARY) в базу не тянем.

import 'package:calenfi/data/providers/calendar/caldav/ics.dart';
import 'package:calenfi/domain/models/attachment.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_details_sheet.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _ics(String attachLines) => '''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VEVENT\r
UID:141zhigo4681x3d24wkv222bgyandex.ru\r
DTSTART:20260921T160000Z\r
DTEND:20260921T170000Z\r
SUMMARY:Собеседование Морозов Илья Олегович\r
$attachLines\r
END:VEVENT\r
END:VCALENDAR''';

void main() {
  test('ATTACH с именем, типом и размером разбирается', () {
    final events = parseIcs(_ics(
        'ATTACH;FMTTYPE=application/pdf;SIZE=204800;FILENAME=Морозов Илья '
        'Олегович.pdf:https://disk.yandex.ru/i/abc123'));

    final a = events.single.attachments.single;
    expect(a.uri, 'https://disk.yandex.ru/i/abc123');
    expect(a.fileName, 'Морозов Илья Олегович.pdf');
    expect(a.mimeType, 'application/pdf');
    expect(a.sizeBytes, 204800);
  });

  test('несколько ATTACH и X-FILENAME', () {
    final events = parseIcs(_ics(
        'ATTACH;X-FILENAME=резюме.txt:https://disk.yandex.ru/i/one\r\n'
        'ATTACH:https://disk.yandex.ru/i/two'));

    final list = events.single.attachments;
    expect(list.length, 2);
    expect(list.first.fileName, 'резюме.txt');
    // Без имени показываем хвост ссылки.
    expect(list.last.fileName, isNull);
  });

  test('встроенный файл (VALUE=BINARY) в базу не попадает', () {
    final events = parseIcs(_ics(
        'ATTACH;VALUE=BINARY;ENCODING=BASE64;FMTTYPE=text/plain:0J/RgNC40LI='));

    expect(events.single.attachments, isEmpty);
  });

  test('без имени подпись берётся из ссылки', () {
    const a = Attachment(uri: 'https://disk.yandex.ru/d/x/%D0%9E%D1%82%D1%87.pdf');
    expect(a.displayName, 'Отч.pdf');
  });

  testWidgets('вложения видны в карточке события', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final start = DateTime.utc(2026, 9, 21, 16);
    final event = CalendarEvent(
      id: 'acc-yandex:events-10922764:141zhigo4681x3d24wkv222bgyandex.ru',
      calendarId: 'acc-yandex|events-10922764',
      title: 'Собеседование Морозов Илья Олегович',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      attachments: const [
        Attachment(
          uri: 'https://disk.yandex.ru/i/abc123',
          fileName: 'Морозов Илья Олегович.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 204800,
        ),
      ],
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'acc-yandex|events-10922764',
      ),
    );
    final merged = MergedEvent(
      groupId: 'g',
      primary: event,
      sources: [event],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarInfoProvider
              .overrideWith((ref) => const <String, CalendarInfo>{}),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEventDetails(context, merged),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Вложения'), findsOneWidget);
    expect(find.text('Морозов Илья Олегович.pdf'), findsOneWidget);
    expect(find.text('200 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
