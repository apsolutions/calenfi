import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/mappers/event_mapper.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  const mapper = EventMapper();

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Event> insertAndRead(EventsCompanion c) async {
    await db.into(db.events).insert(c);
    return (db.select(
      db.events,
    )..where((e) => e.id.equals(c.id.value))).getSingle();
  }

  group('EventMapper — автодетект видеовстречи (FR-M1)', () {
    test(
      'конференция распознаётся из описания, если не сохранена явно',
      () async {
        final row = await insertAndRead(
          EventsCompanion.insert(
            id: '1',
            calendarId: 'c',
            accountId: 'a',
            title: 'Созвон',
            startUtc: DateTime.utc(2026, 6, 11, 10),
            endUtc: DateTime.utc(2026, 6, 11, 11),
            description: const Value(
              'Подключайтесь: https://us06web.zoom.us/j/84538569211',
            ),
          ),
        );
        final e = mapper.toDomain(row);
        expect(e.conference, isNotNull);
        expect(e.conference!.type, ConferenceType.zoom);
        expect(e.conference!.joinUrl, contains('zoom.us/j/84538569211'));
      },
    );

    test('без ссылки конференция отсутствует', () async {
      final row = await insertAndRead(
        EventsCompanion.insert(
          id: '2',
          calendarId: 'c',
          accountId: 'a',
          title: 'Без ссылки',
          startUtc: DateTime.utc(2026, 6, 11, 10),
          endUtc: DateTime.utc(2026, 6, 11, 11),
        ),
      );
      expect(mapper.toDomain(row).conference, isNull);
    });
  });

  test('конференция сохраняет выбранную учётную запись при round-trip', () async {
    final event = CalendarEvent(
      id: 'telemost-pending',
      calendarId: 'yandex-calendar',
      title: 'Созвон',
      startUtc: DateTime.utc(2026, 9, 2, 10),
      endUtc: DateTime.utc(2026, 9, 2, 11),
      conference: const Conference.pending(
        ConferenceType.telemost,
        accountId: 'acc-yandex',
      ),
      source: const EventSource(
        accountId: 'acc-yandex',
        calendarId: 'yandex-calendar',
      ),
    );

    final row = await insertAndRead(mapper.toCompanion(event));
    final decoded = mapper.toDomain(row);
    expect(decoded.conference?.type, ConferenceType.telemost);
    expect(decoded.conference?.accountId, 'acc-yandex');
    expect(decoded.conference?.isReady, isFalse);
  });
}
