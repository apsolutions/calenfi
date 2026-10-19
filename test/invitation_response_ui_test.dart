import 'dart:async';

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/local/db/database_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/domain/usecases/event_actions.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_details_sheet.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Actions extends EventActions {
  _Actions(super.events, super.sync);
  var result = Completer<void>();
  int calls = 0;
  @override
  Future<void> rsvp(CalendarEvent e, ResponseStatus r) {
    calls++;
    return result.future;
  }
}

void main() {
  for (final unsupported in [true, false]) {
    testWidgets(
      'preflight error is visible, sheet stays open, retry works ($unsupported)',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final sync = SyncEngine(
          registry: ProviderRegistry(),
          accounts: AccountRepository(db),
          events: EventRepository(db),
        );
        final actions = _Actions(EventRepository(db), sync);
        addTearDown(() async {
          sync.dispose();
          await db.close();
        });
        await tester.binding.setSurfaceSize(const Size(600, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const account = Account(
          id: 'a',
          provider: ProviderType.caldav,
          displayName: 'Test',
          email: 'me@example.org',
        );
        final event = CalendarEvent(
          id: 'a:invite',
          calendarId: 'c',
          title: 'Invitation',
          startUtc: DateTime.utc(2026, 10, 20, 10),
          endUtc: DateTime.utc(2026, 10, 20, 11),
          myResponse: ResponseStatus.needsAction,
          source: const EventSource(accountId: 'a', calendarId: 'c'),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              eventActionsProvider.overrideWithValue(actions),
              accountsStreamProvider.overrideWith(
                (ref) => Stream.value([account]),
              ),
              calendarInfoProvider.overrideWith((ref) => const {}),
            ],
            child: MaterialApp(
              locale: const Locale('ru'),
              localizationsDelegates: L10n.localizationsDelegates,
              supportedLocales: L10n.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showEventDetails(
                      context,
                      MergedEvent(
                        groupId: event.id,
                        primary: event,
                        sources: [event],
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        final l10n = L10n.of(tester.element(find.text('Invitation')));
        await tester.tap(find.text(l10n.detAccept));
        await tester.pump();
        expect(actions.calls, 1);
        expect(
          tester
              .widgetList<ChoiceChip>(find.byType(ChoiceChip))
              .every((chip) => chip.onSelected == null),
          isTrue,
        );
        actions.result.completeError(
          unsupported
              ? UnsupportedError('Сервер не поддерживает ответы')
              : StateError('technical network failure'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Invitation'), findsOneWidget);
        expect(
          find.text(
            unsupported
                ? 'Сервер не поддерживает ответы'
                : 'Не удалось проверить отправку ответа. Проверьте подключение и повторите.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        actions.result = Completer<void>();
        await tester.tap(find.text(l10n.detAccept));
        await tester.pump();
        actions.result.complete();
        await tester.pumpAndSettle();
        expect(actions.calls, 2);
        expect(find.text('Invitation'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
