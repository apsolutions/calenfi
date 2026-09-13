// Перетаскивание вхождения повторяющейся серии обязано спросить, что менять:
// это вхождение или всю серию. Молчаливый выбор за пользователя рассылает
// участникам изменения не на то, что он правил.

import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_block.dart';
import 'package:calenfi/features/calendar/pending_edits.dart';
import 'package:calenfi/features/calendar/time_grid.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _FakeSyncEngine implements SyncEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class _RecordingPendingEdits extends PendingEditsNotifier {
  _RecordingPendingEdits() : super(_FakeEventRepository(), _FakeSyncEngine());

  final staged = <CalendarEvent>[];
  final scopes = <RecurrenceScope>[];

  @override
  Future<void> stage(CalendarEvent updated, Duration delay,
      {String op = 'update',
      CalendarEvent? original,
      RecurrenceScope scope = RecurrenceScope.thisOnly}) async {
    staged.add(updated);
    scopes.add(scope);
  }
}

void main() {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final start = DateTime(today.year, today.month, today.day, 10);

  MergedEvent merged({required bool recurring}) {
    final e = CalendarEvent(
      id: 'e1',
      calendarId: 'c1',
      title: 'Тренировка',
      startUtc: start.toUtc(),
      endUtc: start.add(const Duration(hours: 1)).toUtc(),
      recurrenceId: recurring ? 'series' : null,
      source: const EventSource(
        accountId: 'a1',
        calendarId: 'c1',
        providerEventId: 'series_20260913T110000Z',
      ),
    );
    return MergedEvent(groupId: 'g1', primary: e, sources: [e]);
  }

  Widget harness(_RecordingPendingEdits pending, MergedEvent event) =>
      ProviderScope(
        overrides: [
          moveModeProvider.overrideWith((ref) => true),
          commitDelayProvider.overrideWith((ref) => const Duration(minutes: 2)),
          pendingEditsProvider.overrideWith((ref) => pending),
        ],
        child: MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 700,
              child: TimeGrid(days: [day], events: [event], colors: const {}),
            ),
          ),
        ),
      );

  Future<void> dragBody(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(EventBlock));
    await tester.pump();
    final from = tester.getCenter(find.byType(EventBlock));
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 40));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('перенос вхождения спрашивает область и передаёт её дальше',
      (tester) async {
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(pending, merged(recurring: true)));
    await tester.pump();

    await dragBody(tester);
    tester.takeException();

    final l10n = await L10n.delegate.load(const Locale('ru'));
    expect(find.text(l10n.detRecurringWhatEdit), findsOneWidget,
        reason: 'перед отправкой правки должен появиться выбор области');
    expect(pending.staged, isEmpty, reason: 'до выбора ничего не уходит');

    await tester.tap(find.text(l10n.detEditWholeSeries));
    await tester.pumpAndSettle();

    expect(pending.scopes, [RecurrenceScope.all]);
    expect(pending.staged.single.startUtc, isNot(start.toUtc()));
  });

  testWidgets('отказ от выбора не отправляет правку', (tester) async {
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(pending, merged(recurring: true)));
    await tester.pump();

    await dragBody(tester);
    tester.takeException();

    final l10n = await L10n.delegate.load(const Locale('ru'));
    await tester.tap(find.text(l10n.detCancel));
    await tester.pumpAndSettle();

    expect(pending.staged, isEmpty);
  });

  testWidgets('обычное событие переносится без лишнего вопроса',
      (tester) async {
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(pending, merged(recurring: false)));
    await tester.pump();

    await dragBody(tester);
    tester.takeException();

    final l10n = await L10n.delegate.load(const Locale('ru'));
    expect(find.text(l10n.detRecurringWhatEdit), findsNothing);
    expect(pending.scopes, [RecurrenceScope.thisOnly]);
  });
}
