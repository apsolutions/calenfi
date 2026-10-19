import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'a', provider: ProviderType.google,
          displayName: 'A', email: 'a@x.com',
        ));
    await db.into(db.calendars).insert(CalendarsCompanion.insert(
          id: 'c', accountId: 'a', name: 'Cal', color: 0xFF000000,
        ));
    final start = DateTime.utc(2026, 6, 11, 10);
    await db.into(db.events).insert(EventsCompanion.insert(
          id: 'ok', calendarId: 'c', accountId: 'a', title: 'Confirmed',
          startUtc: start, endUtc: start.add(const Duration(hours: 1)),
        ));
    await db.into(db.events).insert(EventsCompanion.insert(
          id: 'cx', calendarId: 'c', accountId: 'a', title: 'Cancelled',
          startUtc: start, endUtc: start.add(const Duration(hours: 1)),
          status: const Value(EventStatus.cancelled),
        ));
  }

  group('watchEventsInRange (FR-V12)', () {
    final from = DateTime.utc(2026, 6, 11);
    final to = DateTime.utc(2026, 6, 12);

    test('по умолчанию отменённые скрыты', () async {
      await seed();
      final rows = await db.watchEventsInRange(from, to).first;
      expect(rows.map((e) => e.id), ['ok']);
    });

    test('includeCancelled=true показывает отменённые', () async {
      await seed();
      final rows = await db
          .watchEventsInRange(from, to, includeCancelled: true)
          .first;
      expect(rows.map((e) => e.id).toSet(), {'ok', 'cx'});
    });

    for (final response in ResponseStatus.values) {
      for (final includeCancelled in [false, true]) {
        test('$response visibility with includeCancelled=$includeCancelled',
            () async {
          await seed();
          await (db.update(db.events)..where((e) => e.id.equals('ok')))
              .write(EventsCompanion(myResponse: Value(response)));
          final visible = includeCancelled ||
              (response != ResponseStatus.tentative &&
                  response != ResponseStatus.declined);
          final expected = {if (visible) 'ok', if (includeCancelled) 'cx'};
          final rows = await db.watchEventsInRange(from, to,
              includeCancelled: includeCancelled).first;
          final owned = await db.watchEventsWithOwnersInRange(from, to,
              includeCancelled: includeCancelled).first;
          expect(rows.map((e) => e.id).toSet(), expected);
          expect(owned.map((e) => e.event.id).toSet(), expected);
        });
      }
    }

    test('события вне диапазона не попадают', () async {
      await seed();
      final rows = await db
          .watchEventsInRange(
              DateTime.utc(2026, 7, 1), DateTime.utc(2026, 7, 2))
          .first;
      expect(rows, isEmpty);
    });

    test('события скрытого календаря не показываются', () async {
      await seed();
      await (db.update(db.calendars)..where((c) => c.id.equals('c')))
          .write(const CalendarsCompanion(visible: Value(false)));
      final rows = await db.watchEventsInRange(from, to).first;
      expect(rows, isEmpty);
    });
  });
}
