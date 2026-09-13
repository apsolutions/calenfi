// Регрессия: после создания повторяющейся серии в базе оставался локальный
// «мастер». Провайдер возвращает его на create, но при чтении отдаёт только
// развёрнутые вхождения — строка застревала dirty, рисовалась в сетке лишней
// встречей рядом с первым вхождением, и перетаскивание попадало по ней,
// молча сдвигая всю серию.

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository events;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    events = EventRepository(db);
  });

  tearDown(() async => db.close());

  CalendarEvent master({String id = 'acc:series', String providerId = 'series'}) =>
      CalendarEvent(
        id: id,
        calendarId: 'acc|primary',
        title: 'Тренировка',
        startUtc: DateTime.utc(2026, 9, 13, 11),
        endUtc: DateTime.utc(2026, 9, 13, 12),
        source: EventSource(
          accountId: 'acc',
          calendarId: 'acc|primary',
          providerEventId: providerId,
        ),
      );

  CalendarEvent occurrence(String stamp) => CalendarEvent(
    id: 'acc:series_$stamp',
    calendarId: 'acc|primary',
    title: 'Тренировка',
    startUtc: DateTime.utc(2026, 9, 13, 11),
    endUtc: DateTime.utc(2026, 9, 13, 12),
    recurrenceId: 'series',
    source: EventSource(
      accountId: 'acc',
      calendarId: 'acc|primary',
      providerEventId: 'series_$stamp',
    ),
  );

  test('локальный мастер удаляется, когда в базе есть вхождения серии', () async {
    await events.putLocalDirty(master());
    await events.putLocalClean(occurrence('20260913T110000Z'));

    expect(await events.cleanupOrphanSeriesMasters(), 1);
    expect(await events.getById('acc:series'), isNull);
    expect(await events.getById('acc:series_20260913T110000Z'), isNotNull);
  });

  test('мастер с незавершённым заданием Outbox остаётся', () async {
    await events.putLocalDirty(master());
    await events.putLocalClean(occurrence('20260913T110000Z'));
    await events.enqueue('update', 'acc:series');

    expect(await events.cleanupOrphanSeriesMasters(), 0);
    expect(await events.getById('acc:series'), isNotNull);
  });

  test('обычное непросинхронизированное событие не трогаем', () async {
    await events.putLocalDirty(master(id: 'acc:solo', providerId: 'solo'));

    expect(await events.cleanupOrphanSeriesMasters(), 0);
    expect(await events.getById('acc:solo'), isNotNull);
  });

  test('вхождения серии остаются на месте', () async {
    await events.putLocalDirty(occurrence('20260913T110000Z'));
    await events.putLocalClean(occurrence('20260920T110000Z'));

    expect(await events.cleanupOrphanSeriesMasters(), 0);
    expect(await events.getById('acc:series_20260913T110000Z'), isNotNull);
  });
}
