import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/time_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _disposeClock(
  WidgetTester tester,
  ProviderContainer container, {
  bool unmountWidget = false,
}) async {
  // Test binding проверяет незавершённые Timer до addTearDown, поэтому clock
  // нужно остановить и уничтожить прямо в теле testWidgets.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  if (unmountWidget) await tester.pumpWidget(const SizedBox.shrink());
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  container.dispose();
  // Восстанавливаем глобальный binding уже после удаления clock observer:
  // новый таймер при этом создать некому.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('следующий тик выравнивается по границе минуты без дрейфа', () {
    expect(
      calendarClockDelay(DateTime(2026, 9, 2, 10, 15, 42, 500)),
      const Duration(seconds: 17, milliseconds: 500),
    );
    expect(
      calendarClockDelay(DateTime(2026, 9, 2, 10, 16)),
      const Duration(minutes: 1),
    );
  });

  testWidgets('resume немедленно перерисовывает линию актуальным временем', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 2, 10, 5);
    final container = ProviderContainer(
      overrides: [calendarClockSourceProvider.overrideWithValue(() => now)],
    );
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 900,
                height: 700,
                child: TimeGrid(
                  days: [DateTime(2026, 9, 2)],
                  events: const [],
                  colors: const {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('10:05'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 9, 2, 14, 47);
      await tester.pump(const Duration(minutes: 5));
      expect(
        container.read(calendarClockProvider),
        DateTime(2026, 9, 2, 10, 5),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        container.read(calendarClockProvider),
        DateTime(2026, 9, 2, 14, 47),
      );
      await tester.pump();
      expect(find.text('14:47'), findsOneWidget);
      expect(find.text('10:05'), findsNothing);
    } finally {
      await _disposeClock(tester, container, unmountWidget: true);
    }
  });

  testWidgets('минутный one-shot срабатывает точно и заново выравнивается', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 2, 10, 15, 42, 500);
    final container = ProviderContainer(
      overrides: [calendarClockSourceProvider.overrideWithValue(() => now)],
    );
    try {
      expect(
        container.read(calendarClockProvider),
        DateTime(2026, 9, 2, 10, 15, 42, 500),
      );
      now = DateTime(2026, 9, 2, 10, 16);

      await tester.pump(const Duration(seconds: 17, milliseconds: 499));
      expect(
        container.read(calendarClockProvider),
        DateTime(2026, 9, 2, 10, 15, 42, 500),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        container.read(calendarClockProvider),
        DateTime(2026, 9, 2, 10, 16),
      );
    } finally {
      await _disposeClock(tester, container);
    }
  });

  testWidgets('смена суток ведёт только фокус, который был на сегодня', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 2, 23, 59, 50);
    final container = ProviderContainer(
      overrides: [calendarClockSourceProvider.overrideWithValue(() => now)],
    );
    try {
      container.read(focusedDateProvider.notifier).state = DateTime(2026, 9, 2);
      container.read(calendarClockProvider);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 9, 3, 8, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(container.read(focusedDateProvider), DateTime(2026, 9, 3));

      container.read(focusedDateProvider.notifier).state = DateTime(2026, 8, 15);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 9, 4, 8, 30);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(
        container.read(focusedDateProvider),
        DateTime(2026, 8, 15),
        reason: 'просмотр истории нельзя сбрасывать на сегодня',
      );
    } finally {
      await _disposeClock(tester, container);
    }
  });
}
