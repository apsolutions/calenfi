// Жалоба: «у повторяющихся событий нельзя менять периодичность». У экземпляра
// серии строка «Повторять» была заблокирована, и правило менять было негде:
// оставалось удалить серию и завести заново. Теперь строка открывается и у
// экземпляра, а правка уходит всей серии (транспорт — в recurrence_scope_test
// и caldav_recurrence_update_test).

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/event_editor/event_editor_screen.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calendar = Calendar(
    id: 'acc-google|primary',
    accountId: 'acc-google',
    name: 'Основной',
    color: 0xff336699,
  );
  const account = Account(
    id: 'acc-google',
    provider: ProviderType.google,
    displayName: 'Google',
    email: 'me@example.com',
  );

  Future<void> pumpEditor(WidgetTester tester, CalendarEvent event) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarsListProvider.overrideWith(
            (ref) => Stream<List<Calendar>>.value(const [calendar]),
          ),
          accountsStreamProvider.overrideWith(
            (ref) => Stream<List<Account>>.value(const [account]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(body: EventEditorScreen(existing: event)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  CalendarEvent occurrence() => CalendarEvent(
        id: 'acc-google:master_20260921T090000Z',
        calendarId: calendar.id,
        title: 'Тренировка',
        startUtc: DateTime.utc(2026, 9, 21, 9),
        endUtc: DateTime.utc(2026, 9, 21, 10),
        recurrenceId: 'master',
        source: const EventSource(
          accountId: 'acc-google',
          calendarId: 'acc-google|primary',
          providerEventId: 'master_20260921T090000Z',
        ),
      );

  ListTile repeatTile(WidgetTester tester) => tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Повторять'),
          matching: find.byType(ListTile),
        ),
      );

  testWidgets('у экземпляра серии строка повторения открывается',
      (tester) async {
    await pumpEditor(tester, occurrence());

    final tile = repeatTile(tester);
    expect(tile.onTap, isNotNull);
    expect(tile.enabled, isTrue);
    // До правки правила вхождения у Google нет — поясняем, что оно у серии.
    expect(find.text('Экземпляр серии — правило у всей серии'), findsOneWidget);
  });

  testWidgets('диалог периодичности открывается из экземпляра', (tester) async {
    await pumpEditor(tester, occurrence());

    await tester.tap(find.text('Повторять'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Повторение'), findsOneWidget);
    expect(find.text('Завершить после'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Диалог ставился шириной ровно 380 точек и на экране 400 вылезал за край
  // (RenderFlex overflow), то есть менять правило на телефоне было нечем.
  testWidgets('диалог периодичности влезает в телефонный экран',
      (tester) async {
    await pumpEditor(tester, occurrence());

    await tester.tap(find.text('Повторять'));
    await tester.pumpAndSettle();
    // Год: добавляет строки «N-е число» / «N-й день недели», самые широкие.
    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final dialog = tester.getSize(find.byType(AlertDialog));
    expect(dialog.width, lessThanOrEqualTo(400));
  });
}
