import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_details_sheet.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ссылка на встречу копируется на Android без hover', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final clipboardCalls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    try {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
        return null;
      });

      const expectedUrl = 'https://meet.example.test/s23-copy';
      final start = DateTime.utc(2026, 9, 1, 12);
      final event = CalendarEvent(
        id: 'event-s23',
        calendarId: 'calendar-s23',
        title: 'Мобильная встреча',
        startUtc: start,
        endUtc: start.add(const Duration(hours: 1)),
        conference: const Conference(
          type: ConferenceType.meet,
          joinUrl: expectedUrl,
        ),
        source: const EventSource(
          accountId: 'account-s23',
          calendarId: 'calendar-s23',
        ),
      );
      final merged = MergedEvent(
        groupId: 'group-s23',
        primary: event,
        sources: [event],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarInfoProvider.overrideWith(
              (ref) => const <String, CalendarInfo>{},
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showEventDetails(context, merged),
                  child: const Text('Открыть встречу'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть встречу'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'карточка не должна переполняться на ширине S23',
      );

      final copy = find.byKey(const ValueKey('meeting-link-copy'));
      expect(copy, findsOneWidget);
      expect(
        copy.hitTestable(),
        findsOneWidget,
        reason: 'на Android кнопка должна быть доступна без hover',
      );
      expect(tester.widget<IconButton>(copy).onPressed, isNotNull);
      expect(tester.getSize(copy).shortestSide, greaterThanOrEqualTo(48));

      await tester.tap(copy);
      await tester.pump();

      final clipboardCall = clipboardCalls.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(clipboardCall.arguments, <String, dynamic>{'text': expectedUrl});
      expect(find.text('Ссылка на встречу скопирована'), findsOneWidget);
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      try {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          await tester.binding.setSurfaceSize(null);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });
}
