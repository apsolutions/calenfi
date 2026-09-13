import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/widget/agenda_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

MergedEvent _merged(CalendarEvent e) =>
    MergedEvent(groupId: e.id, primary: e, sources: [e]);

CalendarEvent _event({
  required String id,
  required DateTime startLocal,
  required DateTime endLocal,
  bool allDay = false,
  EventStatus status = EventStatus.confirmed,
}) => CalendarEvent(
  id: id,
  calendarId: 'calendar-1',
  title: id,
  // All-day хранится плавающей датой (UTC-полночь), остальное — моментом.
  startUtc: allDay
      ? DateTime.utc(startLocal.year, startLocal.month, startLocal.day)
      : startLocal.toUtc(),
  endUtc: allDay
      ? DateTime.utc(endLocal.year, endLocal.month, endLocal.day)
      : endLocal.toUtc(),
  allDay: allDay,
  status: status,
  source: const EventSource(accountId: 'account-1', calendarId: 'calendar-1'),
);

void main() {
  final now = DateTime(2026, 9, 4, 10, 0);

  Map<String, dynamic> snapshotOf(List<CalendarEvent> events) =>
      AgendaWidgetService.buildMacosSnapshot(
        buildAgendaWidgetItemsForTest(
          events.map(_merged).toList(),
          const {'calendar-1': 0xFF112233},
        ),
        now,
      );

  test('снимок отдаёт события ближайших дней и счётчики по дням', () {
    final snapshot = snapshotOf([
      _event(
        id: 'today',
        startLocal: DateTime(2026, 9, 4, 12),
        endLocal: DateTime(2026, 9, 4, 13),
      ),
      _event(
        id: 'far',
        startLocal: DateTime(2026, 10, 20, 9),
        endLocal: DateTime(2026, 10, 20, 10),
      ),
    ]);

    final ids = (snapshot['events'] as List)
        .map((e) => (e as Map)['title'])
        .toList();
    expect(ids, ['today'], reason: 'дальние встречи в повестку не попадают');

    final counts = snapshot['day_counts'] as Map<String, dynamic>;
    expect(counts['2026-09-04'], 1);
    expect(
      counts['2026-10-20'],
      1,
      reason: 'мини-календарь листает месяцы, поэтому счётчики шире повестки',
    );
  });

  test('all-day занимает дни от начала до эксклюзивного конца', () {
    final counts =
        snapshotOf([
              _event(
                id: 'vacation',
                startLocal: DateTime(2026, 9, 10),
                endLocal: DateTime(2026, 9, 13),
                allDay: true,
              ),
            ])['day_counts']
            as Map<String, dynamic>;

    expect(counts.keys.toList()..sort(), [
      '2026-09-10',
      '2026-09-11',
      '2026-09-12',
    ]);
  });

  test('встреча до ровной полуночи не задевает следующий день', () {
    final counts =
        snapshotOf([
              _event(
                id: 'late',
                startLocal: DateTime(2026, 9, 4, 22),
                endLocal: DateTime(2026, 9, 5),
              ),
            ])['day_counts']
            as Map<String, dynamic>;

    expect(counts.keys.toList(), ['2026-09-04']);
  });

  test('отменённые встречи не попадают ни в повестку, ни в счётчики', () {
    final snapshot = snapshotOf([
      _event(
        id: 'cancelled',
        startLocal: DateTime(2026, 9, 4, 15),
        endLocal: DateTime(2026, 9, 4, 16),
        status: EventStatus.cancelled,
      ),
    ]);

    expect(snapshot['events'], isEmpty);
    expect(snapshot['day_counts'], isEmpty);
  });
}
