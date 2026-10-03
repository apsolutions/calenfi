// «Поле notes при создании встречи и my notes при просмотре — два разных
// поля, а должно быть одно». Поле «Заметки» редактора — это личная заметка;
// описание события (оно уходит участникам) редактор не показывает и не меняет.

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/local/db/database_provider.dart';
import 'package:calenfi/data/repositories/notes_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_details_sheet.dart';
import 'package:calenfi/features/event_editor/event_editor_screen.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 10, 2, 14);
  const cal = Calendar(id: 'c1', accountId: 'a1', name: 'Рабочий', color: 0xff336699);
  const account = Account(id: 'a1', provider: ProviderType.graph, displayName: 'W', email: 'me@example.test');
  final event = CalendarEvent(
    id: 'a1:e1',
    calendarId: 'c1',
    title: 'Собеседование',
    startUtc: start,
    endUtc: start.add(const Duration(hours: 1)),
    description: 'Ссылка на Teams для участников',
    source: const EventSource(accountId: 'a1', calendarId: 'c1'),
  );
  final merged = MergedEvent(groupId: event.id, primary: event, sources: [event]);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        calendarsListProvider.overrideWith((ref) => Stream.value(const [cal])),
        calendarInfoProvider.overrideWith((ref) => const {}),
        accountsStreamProvider.overrideWith((ref) => Stream.value(const [account])),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: home),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('в редакторе поле «Заметки» показывает личную заметку, а не описание',
      (tester) async {
    await tester.runAsync(() => NotesRepository(db).write(merged, 'Спросить про опыт с LLM'));
    await pump(tester, EventEditorScreen(existing: event));

    final field = tester.widget<TextField>(find.byKey(const ValueKey('editor-private-notes')));
    expect(field.controller!.text, 'Спросить про опыт с LLM');
    expect(find.text('Ссылка на Teams для участников'), findsNothing);
  });

  testWidgets('в карточке встречи нет поля для правки, заметка только видна',
      (tester) async {
    await tester.runAsync(() => NotesRepository(db).write(merged, 'Повестка'));
    await pump(tester, Builder(builder: (context) {
      return TextButton(onPressed: () => showEventDetails(context, merged), child: const Text('open'));
    }));
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('private-note-view')), findsOneWidget);
    expect(find.text('Повестка'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
