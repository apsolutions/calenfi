import 'dart:async';
import 'package:calenfi/features/calendar/event_write_status.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('card distinguishes waiting, failed and confirmed delivery', (
    tester,
  ) async {
    final states = StreamController<({bool dirty, bool failed})?>();
    addTearDown(states.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventWriteStateProvider('event').overrideWith((ref) => states.stream),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(body: EventWriteStatus(eventId: 'event')),
        ),
      ),
    );
    expect(find.text('Синхронизировано с сервером'), findsNothing);
    states.add((dirty: true, failed: false));
    await tester.pumpAndSettle();
    expect(find.text('Изменение ещё не подтверждено сервером'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    states.add((dirty: true, failed: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Изменение не отправлено.'), findsOneWidget);
    states.add((dirty: false, failed: false));
    await tester.pumpAndSettle();
    expect(find.text('Синхронизировано с сервером'), findsOneWidget);
    expect(find.textContaining('Изменение не отправлено.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
