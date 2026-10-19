import 'package:calenfi/app/providers.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_block.dart';
import 'package:calenfi/features/calendar/month_view.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final response in ResponseStatus.values) {
    for (final month in [false, true]) {
      testWidgets('$response strikethrough in month=$month', (tester) async {
        final start = DateTime(2026, 10, 1, 10);
        final event = CalendarEvent(
          id: 'event',
          calendarId: 'calendar',
          title: 'Invitation',
          startUtc: start.toUtc(),
          endUtc: start.add(const Duration(hours: 1)).toUtc(),
          myResponse: response,
          source: const EventSource(accountId: 'a', calendarId: 'calendar'),
        );
        final merged = MergedEvent(
            groupId: event.id, primary: event, sources: [event]);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            noteKeysProvider.overrideWith((ref) => Stream.value(<String>{})),
            focusedDateProvider.overrideWith((ref) => start),
            mergedEventsProvider.overrideWith((ref) => Stream.value([merged])),
            calendarColorsProvider.overrideWith((ref) => Stream.value({})),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Scaffold(
              body: month
                  ? const MonthView()
                  : SizedBox(
                      width: 200,
                      height: 100,
                      child: EventBlock(event: merged, color: Colors.blue)),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final title = tester.widget<Text>(find.text('Invitation'));
        expect(
          title.style?.decoration,
          response == ResponseStatus.tentative ||
                  response == ResponseStatus.declined
              ? TextDecoration.lineThrough
              : null,
        );
        expect(event.isCancelled, isFalse);
      });
    }
  }
}
