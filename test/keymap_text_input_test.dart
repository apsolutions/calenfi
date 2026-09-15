// Жалоба: «при нажатии r в поиске происходит какая-то хуита». Глобальные
// привязки без модификаторов (R — синхронизация, H, 1/2/3, стрелки) ловили
// обычные клавиши, пока человек печатал в строке поиска.

import 'package:calenfi/app/keymap.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<(FocusNode, FocusNode)> pump(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    final field = FocusNode();
    final grid = FocusNode();
    addTearDown(field.dispose);
    addTearDown(grid.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: CalenfiKeymap(
            child: Column(children: [
              TextField(focusNode: field),
              Focus(
                focusNode: grid,
                child: const SizedBox(width: 100, height: 100),
              ),
            ]),
          ),
        ),
      ),
    ));
    return (field, grid);
  }

  testWidgets('клавиши в поле ввода не запускают привязки', (tester) async {
    final (field, _) = await pump(tester);
    field.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();

    expect(isEditingText(), isTrue);
    expect(container.read(showCancelledProvider), isFalse);
    expect(container.read(viewModeProvider), CalendarViewMode.week);
  });

  testWidgets('вне поля ввода привязки работают', (tester) async {
    final (_, grid) = await pump(tester);
    grid.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();

    expect(isEditingText(), isFalse);
    expect(container.read(showCancelledProvider), isTrue);
    expect(container.read(viewModeProvider), CalendarViewMode.month);
  });
}
