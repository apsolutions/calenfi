// Жалобы по мобильной шапке: «ПН, 21 занимает целую строчку, пропадает куча
// места», «в левом углу "ПН, 2…" абсолютно бесполезно», плюс правила: тап по
// дню показывает неделю, тап по месяцу — месяц, а тап по дню в месячной сетке
// на телефоне открывает дневной вид.

import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_screen.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/month_view.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 21); // понедельник

  ProviderContainer? container;

  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    // MediaQuery читает размер FlutterView, а не surfaceSize (иначе ширина
    // осталась бы 800 и телефонная ветка кода не проверялась бы).
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedDateProvider.overrideWith((ref) => day),
          mergedEventsProvider.overrideWith(
            (ref) => Stream<List<MergedEvent>>.value(const []),
          ),
          calendarColorsProvider.overrideWith(
            (ref) => Stream<Map<String, int>>.value(const {}),
          ),
        ],
        child: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Scaffold(body: child),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('строка периода показывает день, месяц и год целиком',
      (tester) async {
    await pump(tester, const PeriodLine(), const Size(360, 200));

    expect(find.text('пн, 21'), findsOneWidget);
    expect(find.textContaining('сентябрь'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('тап по дню открывает неделю, тап по месяцу — месяц',
      (tester) async {
    await pump(tester, const PeriodLine(), const Size(360, 200));

    await tester.tap(find.byKey(const ValueKey('period-line-day')));
    await tester.pumpAndSettle();
    expect(container!.read(viewModeProvider), CalendarViewMode.week);

    await tester.tap(find.byKey(const ValueKey('period-line-month')));
    await tester.pumpAndSettle();
    expect(container!.read(viewModeProvider), CalendarViewMode.month);
  });

  testWidgets('в месячной сетке тап по дню на телефоне открывает день',
      (tester) async {
    await pump(tester, const MonthView(), const Size(360, 700));

    await tester.tap(find.text('23').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(container!.read(viewModeProvider), CalendarViewMode.day);
    expect(container!.read(focusedDateProvider).day, 23);
  });

  testWidgets('на широком экране месячная сетка остаётся месячной',
      (tester) async {
    await pump(tester, const MonthView(), const Size(1000, 800));
    container!.read(viewModeProvider.notifier).state = CalendarViewMode.month;

    await tester.tap(find.text('23').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(container!.read(viewModeProvider), CalendarViewMode.month);
    expect(container!.read(focusedDateProvider).day, 23);
  });
}
