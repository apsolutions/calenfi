import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/widget/agenda_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native agenda payload carries absolute interval and display metadata',
    () {
      final event = CalendarEvent(
        id: 'event-1',
        calendarId: 'calendar-1',
        title: 'Встреча',
        startUtc: DateTime.utc(2026, 9, 3, 20, 30),
        endUtc: DateTime.utc(2026, 9, 3, 21, 15),
        location: 'Переговорная',
        source: const EventSource(
          accountId: 'account-1',
          calendarId: 'calendar-1',
        ),
      );
      final merged = MergedEvent(
        groupId: 'group-1',
        primary: event,
        sources: [event],
      );

      final item = buildAgendaWidgetItemsForTest(
        [merged],
        const {'calendar-1': 0xFF123456},
      ).single;

      expect(
        item['start_ms'],
        DateTime.utc(2026, 9, 3, 20, 30).millisecondsSinceEpoch,
      );
      expect(
        item['end_ms'],
        DateTime.utc(2026, 9, 3, 21, 15).millisecondsSinceEpoch,
      );
      expect(item['all_day'], isFalse);
      expect(item.containsKey('start_date'), isFalse);
      expect(item.containsKey('end_date'), isFalse);
      expect(item['location'], 'Переговорная');
      expect(item['title'], 'Встреча');
      expect(item['color'], 0xFF123456);
    },
  );

  test('all-day payload carries floating end-exclusive dates', () {
    final event = CalendarEvent(
      id: 'event-all-day',
      calendarId: 'calendar-1',
      title: 'Отпуск',
      startUtc: DateTime.utc(2026, 9, 3),
      endUtc: DateTime.utc(2026, 9, 5),
      allDay: true,
      source: const EventSource(
        accountId: 'account-1',
        calendarId: 'calendar-1',
      ),
    );
    final merged = MergedEvent(
      groupId: 'group-all-day',
      primary: event,
      sources: [event],
    );

    final item = buildAgendaWidgetItemsForTest([merged], const {}).single;

    expect(item['start_date'], '2026-09-03');
    expect(item['end_date'], '2026-09-05');
    expect(item['start_ms'], event.startUtc.millisecondsSinceEpoch);
    expect(item['end_ms'], event.endUtc.millisecondsSinceEpoch);
    expect(item['all_day'], isTrue);
  });

  test('offline cache spans the provider future-sync horizon', () {
    expect(agendaWidgetFutureCacheDays, greaterThanOrEqualTo(365));
  });
}
