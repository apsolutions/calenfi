import 'dart:async';

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/event_editor/event_editor_screen.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEditor(
    WidgetTester tester, {
    required double width,
    required bool useLongNames,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final calendar = Calendar(
      id: 'calendar-layout-test',
      accountId: 'account-layout-test',
      name: useLongNames
          ? 'Очень длинное название рабочего календаря'
          : 'Рабочий',
      color: 0xff336699,
    );
    final account = Account(
      id: 'account-layout-test',
      provider: ProviderType.graph,
      displayName: 'Layout test',
      email: useLongNames
          ? 'very-long-conference-account-name@example.test'
          : 'work@example.test',
    );
    final start = DateTime.utc(2026, 9, 2, 12);
    final event = CalendarEvent(
      id: 'event-layout-test',
      calendarId: calendar.id,
      title: 'Встреча',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      conference: Conference.pending(
        ConferenceType.teams,
        accountId: account.id,
      ),
      source: EventSource(accountId: account.id, calendarId: calendar.id),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarsListProvider.overrideWith(
            (ref) => Stream<List<Calendar>>.value([calendar]),
          ),
          accountsStreamProvider.overrideWith(
            (ref) => Stream<List<Account>>.value([account]),
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

  Future<void> revealEditorField(WidgetTester tester, Finder field) async {
    final editorScroll = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      field,
      160,
      scrollable: editorScroll.first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'мобильные поля календаря и видеовстречи не переносят заголовки',
    (tester) async {
      await pumpEditor(tester, width: 360, useLongNames: true);

      final headerTitle = find.byKey(
        const ValueKey('event-editor-header-title'),
      );
      expect(headerTitle, findsOneWidget);
      final headerText = tester.widget<Text>(headerTitle);
      expect(headerText.maxLines, 1);
      expect(headerText.softWrap, isFalse);
      expect(headerText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);

      final calendarLabel = find.byKey(
        const ValueKey('event-editor-calendar-label'),
      );
      final calendarDropdown = find.byKey(
        const ValueKey('event-editor-calendar-dropdown'),
      );
      final conferenceLabel = find.byKey(
        const ValueKey('event-editor-conference-label'),
      );
      final conferenceDropdown = find.byKey(
        const ValueKey('event-editor-conference-dropdown'),
      );

      await revealEditorField(tester, calendarLabel);
      expect(calendarLabel, findsOneWidget);
      final calendarText = tester.widget<Text>(calendarLabel);
      expect(calendarText.maxLines, 1);
      expect(calendarText.softWrap, isFalse);
      expect(calendarText.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(calendarLabel).height, lessThan(30));

      expect(
        tester.getTopLeft(calendarDropdown).dy,
        greaterThan(tester.getTopLeft(calendarLabel).dy),
      );

      await revealEditorField(tester, conferenceLabel);
      expect(conferenceLabel, findsOneWidget);
      final conferenceText = tester.widget<Text>(conferenceLabel);
      expect(conferenceText.maxLines, 1);
      expect(conferenceText.softWrap, isFalse);
      expect(conferenceText.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(conferenceLabel).height, lessThan(30));
      expect(
        tester.getTopLeft(conferenceDropdown).dy,
        greaterThan(tester.getTopLeft(conferenceLabel).dy),
      );
      expect(
        tester.getBottomLeft(conferenceDropdown).dy -
            tester.getTopLeft(conferenceLabel).dy,
        lessThan(90),
        reason: 'поле видеовстречи должно оставаться компактным',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop сохраняет горизонтальную разметку полей', (
    tester,
  ) async {
    // 480 dp — фактическая ширина desktop-диалога.
    await pumpEditor(tester, width: 480, useLongNames: false);
    expect(tester.takeException(), isNull);

    final calendarLabel = find.byKey(
      const ValueKey('event-editor-calendar-label'),
    );
    final calendarDropdown = find.byKey(
      const ValueKey('event-editor-calendar-dropdown'),
    );
    final conferenceLabel = find.byKey(
      const ValueKey('event-editor-conference-label'),
    );
    final conferenceDropdown = find.byKey(
      const ValueKey('event-editor-conference-dropdown'),
    );

    await revealEditorField(tester, calendarLabel);
    expect(
      tester.getCenter(calendarLabel).dy,
      closeTo(tester.getCenter(calendarDropdown).dy, 1),
    );

    await revealEditorField(tester, conferenceLabel);
    expect(
      tester.getCenter(conferenceLabel).dy,
      closeTo(tester.getCenter(conferenceDropdown).dy, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('загрузка календарей не меняет календарь редактируемого события', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calendars = StreamController<List<Calendar>>();
    addTearDown(calendars.close);

    const yandexAccount = Account(
      id: 'account-yandex',
      provider: ProviderType.caldav,
      displayName: 'Yandex 360',
      email: 'ki@apsolutions.ru',
      config: AccountConfig(caldavHost: 'caldav.yandex.ru'),
    );
    const otherAccount = Account(
      id: 'account-other',
      provider: ProviderType.graph,
      displayName: 'Other',
      email: 'other@example.test',
    );
    const otherCalendar = Calendar(
      id: 'calendar-first',
      accountId: 'account-other',
      name: 'Первый',
      color: 0xff336699,
    );
    const selectedCalendar = Calendar(
      id: 'calendar-selected',
      accountId: 'account-yandex',
      name: 'Выбранный',
      color: 0xff669933,
    );
    final start = DateTime.utc(2026, 9, 2, 12);
    final event = CalendarEvent(
      id: 'event-delayed-calendars',
      calendarId: selectedCalendar.id,
      title: 'Встреча',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      conference: const Conference.pending(
        ConferenceType.telemost,
        accountId: 'account-yandex',
      ),
      source: const EventSource(
        accountId: 'account-yandex',
        calendarId: 'calendar-selected',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarsListProvider.overrideWith((ref) => calendars.stream),
          accountsStreamProvider.overrideWith(
            (ref) => Stream<List<Account>>.value(
              const [yandexAccount, otherAccount],
            ),
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
    await tester.pump();

    calendars.add(const [otherCalendar, selectedCalendar]);
    await tester.pumpAndSettle();

    final calendarDropdown = find.byKey(
      const ValueKey('event-editor-calendar-dropdown'),
    );
    await revealEditorField(tester, calendarDropdown);
    expect(
      tester.widget<DropdownButton<String>>(calendarDropdown).value,
      selectedCalendar.id,
    );

    final conferenceDropdown = find.byKey(
      const ValueKey('event-editor-conference-dropdown'),
    );
    await revealEditorField(tester, conferenceDropdown);
    expect(
      tester.widget<DropdownButton<String?>>(conferenceDropdown).value,
      'telemost|${yandexAccount.id}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('внешняя ссылка Telemost видна, но не становится native-опцией', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const account = Account(
      id: 'account-yandex',
      provider: ProviderType.caldav,
      displayName: 'Yandex 360',
      email: 'ki@apsolutions.ru',
      config: AccountConfig(caldavHost: 'caldav.yandex.ru'),
    );
    const calendar = Calendar(
      id: 'calendar-yandex',
      accountId: 'account-yandex',
      name: 'Рабочий',
      color: 0xff336699,
    );
    final start = DateTime.utc(2026, 9, 2, 12);
    final event = CalendarEvent(
      id: 'event-external-telemost',
      calendarId: calendar.id,
      title: 'Внешняя встреча',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      conference: const Conference(
        type: ConferenceType.telemost,
        joinUrl: 'https://telemost.yandex.ru/j/external-meeting',
      ),
      source: const EventSource(
        accountId: 'account-yandex',
        calendarId: 'calendar-yandex',
      ),
    );

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

    final conferenceDropdown = find.byKey(
      const ValueKey('event-editor-conference-dropdown'),
    );
    await revealEditorField(tester, conferenceDropdown);
    expect(
      tester.widget<DropdownButton<String?>>(conferenceDropdown).value,
      'telemost|',
    );
    expect(tester.takeException(), isNull);
  });
}
