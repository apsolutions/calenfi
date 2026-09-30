import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/services/dedup_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent ev({
  required String id,
  required String title,
  required DateTime start,
  Duration dur = const Duration(hours: 1),
  bool allDay = false,
  String? uid,
  String calendarId = 'cal',
}) {
  return CalendarEvent(
    id: id,
    calendarId: calendarId,
    title: title,
    startUtc: start.toUtc(),
    endUtc: start.toUtc().add(dur),
    allDay: allDay,
    source: EventSource(
      accountId: 'a',
      calendarId: calendarId,
      providerEventId: uid,
    ),
  );
}

void main() {
  const engine = DedupEngine();
  final t = DateTime.utc(2026, 6, 11, 10);

  group('DedupEngine (FR-D2)', () {
    test('склеивает одинаковые заголовок+время из разных календарей', () {
      final groups = engine.group([
        ev(id: '1', title: 'Daily Standup', start: t, calendarId: 'work'),
        ev(id: '2', title: 'daily   standup ', start: t, calendarId: 'personal'),
      ]);
      expect(groups.length, 1);
      expect(groups.first.isMerged, isTrue);
      expect(groups.first.sources.length, 2);
    });

    test('не склеивает разные события в одно время', () {
      final groups = engine.group([
        ev(id: '1', title: 'Standup A', start: t),
        ev(id: '2', title: 'Standup B', start: t),
      ]);
      expect(groups.length, 2);
    });

    test('склеивает по UID даже при отличии заголовков', () {
      final groups = engine.group([
        ev(id: '1', title: 'Встреча', start: t, uid: 'UID-123'),
        ev(id: '2', title: 'Meeting (copy)', start: t.add(const Duration(minutes: 5)), uid: 'UID-123'),
      ]);
      expect(groups.length, 1);
    });

    test('all-day и timed с одним названием/временем не склеиваются', () {
      final groups = engine.group([
        ev(id: '1', title: 'День рождения', start: t, allDay: true),
        ev(id: '2', title: 'День рождения', start: t, allDay: false),
      ]);
      expect(groups.length, 2);
    });

    test('combine=false оставляет каждое событие отдельно', () {
      final groups = engine.group([
        ev(id: '1', title: 'X', start: t),
        ev(id: '2', title: 'X', start: t),
      ], combine: false);
      expect(groups.length, 2);
      expect(groups.every((g) => !g.isMerged), isTrue);
    });

    test('транзитивная склейка через общий UID и ключ', () {
      // 1↔2 по ключу, 2↔3 по UID → все в одной группе
      final groups = engine.group([
        ev(id: '1', title: 'Sync', start: t),
        ev(id: '2', title: 'Sync', start: t, uid: 'U1'),
        ev(id: '3', title: 'Sync renamed', start: t.add(const Duration(hours: 2)), uid: 'U1'),
      ]);
      expect(groups.length, 1);
      expect(groups.first.sources.length, 3);
    });
    test('вхождения одной серии с общим UID не склеиваются между собой', () {
      // У всех вхождений повторяющейся серии один iCalendar UID. Виджет берёт
      // диапазон на год вперёд: склейка по голому UID сворачивала серию в одну
      // группу, и сегодняшнее вхождение пропадало из повестки.
      final groups = engine.group([
        for (var d = 0; d < 5; d++)
          ev(
            id: 'o365:$d',
            title: 'Статус проекта',
            start: t.add(Duration(days: 7 * d)),
            uid: 'SERIES-1',
            calendarId: 'work',
          ),
        for (var d = 0; d < 5; d++)
          ev(
            id: 'yandex:$d',
            title: 'Статус проекта ',
            start: t.add(Duration(days: 7 * d)),
            uid: 'SERIES-1',
            calendarId: 'personal',
          ),
      ]);
      expect(groups.length, 5);
      for (final g in groups) {
        expect(g.sources.length, 2);
        expect(
          g.sources.map((e) => e.startUtc).toSet().length,
          1,
          reason: 'в группе только копии одного вхождения',
        );
      }
    });

    test('ежедневная серия с общим UID остаётся по дням', () {
      final groups = engine.group([
        for (var d = 0; d < 7; d++)
          ev(id: 'daily:$d', title: 'Daily', start: t.add(Duration(days: d)), uid: 'DAILY'),
      ]);
      expect(groups.length, 7);
    });
  });
}
