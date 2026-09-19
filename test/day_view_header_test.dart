import 'dart:async';

import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/day_view.dart';
import 'package:calenfi/features/calendar/time_grid.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2024, 5, 15); // Wednesday / среда

  Future<void> pumpHeader(
    WidgetTester tester, {
    required Locale locale,
    required double width,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(body: DayColumnHeader(day: day)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('day header localizes weekday for Russian and English', (
    tester,
  ) async {
    await pumpHeader(tester, locale: const Locale('ru'), width: 320);
    expect(find.byKey(const ValueKey('day-column-weekday')), findsOneWidget);
    expect(find.text('СР'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpHeader(tester, locale: const Locale('en'), width: 320);
    expect(find.text('WED'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('day header stays aligned with the time-grid column', (
    tester,
  ) async {
    for (final width in [280.0, 1000.0]) {
      await pumpHeader(tester, locale: const Locale('en'), width: width);

      final weekday = find.byKey(const ValueKey('day-column-weekday'));
      final expectedColumnCenter = kGutterWidth + (width - kGutterWidth) / 2;
      expect(tester.getCenter(weekday).dx, closeTo(expectedColumnCenter, 0.1));
      expect(tester.getSize(find.byType(DayColumnHeader)).height, 56);
      expect(tester.takeException(), isNull);
    }
  });

  Future<void> pumpDayView(WidgetTester tester, Size size) async {
    // Именно view, а не setSurfaceSize: MediaQuery берёт размер из
    // FlutterView, и с setSurfaceSize экран остаётся «широким» (800),
    // из-за чего проверка телефонной раскладки была бы ложной.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedDateProvider.overrideWith((ref) => day),
          dayEventsProvider.overrideWith(
            (ref, _) => Stream<List<MergedEvent>>.value(const []),
          ),
          calendarColorsProvider.overrideWith(
            (ref) => Stream<Map<String, int>>.value(const {}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: DayView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('DayView places the header above its event grid', (tester) async {
    await pumpDayView(tester, const Size(900, 700));

    final header = find.byType(DayColumnHeader);
    final grid = find.byType(TimeGrid);
    expect(header, findsOneWidget);
    expect(grid, findsOneWidget);
    expect(
      tester.getBottomLeft(header).dy,
      lessThan(tester.getTopLeft(grid).dy),
    );
    expect(tester.takeException(), isNull);
  });

  // Жалоба: «ПН, 21 на телефоне занимает целую строчку, пропадает куча места».
  // Дата уже есть в шапке экрана, поэтому на узком экране строки быть не должно.
  testWidgets('на телефоне отдельной строки с датой нет', (tester) async {
    await pumpDayView(tester, const Size(360, 700));

    expect(find.byType(DayColumnHeader), findsNothing);
    final grid = find.byType(TimeGrid);
    expect(grid, findsOneWidget);
    expect(tester.getTopLeft(grid).dy, 0);
    expect(tester.takeException(), isNull);
  });
}
