// Жалоба: у строки чужого организатора стояло «you're the organizer», как
// будто организатор я: строка участника-организатора подписывалась фразой про
// мой собственный ответ.

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/local/db/database_provider.dart';
import 'package:calenfi/domain/models/attendee.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_details_sheet.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('организатор-другой человек не подписан «Вы организатор»', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final start = DateTime.utc(2026, 10, 6, 10);
    final e = CalendarEvent(
      id: 'acc-hse:x:1',
      calendarId: 'c',
      title: 'Сотрудничество',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      myResponse: ResponseStatus.needsAction,
      attendees: const [
        Attendee(email: 'org@example.test', displayName: 'Анна', response: ResponseStatus.organizer, isOrganizer: true),
        Attendee(email: 'me@example.test', displayName: 'Я'),
      ],
      source: const EventSource(accountId: 'acc-hse', calendarId: 'c'),
    );
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        calendarInfoProvider.overrideWith((ref) => const {}),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () => showEventDetails(context, MergedEvent(groupId: e.id, primary: e, sources: [e])),
          child: const Text('open')))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final l10n = L10n.of(tester.element(find.text('Анна')));
    expect(find.text(l10n.detResponseOrganizer), findsNothing);
    expect(find.text(l10n.detOrganizer), findsOneWidget);

    // Снять дерево и дождаться таймеров потоков базы.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
