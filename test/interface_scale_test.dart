import 'dart:io';

import 'package:calenfi/app/interface_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scale persists and invalid settings fall back to 100%', () {
    final dir = Directory.systemTemp.createTempSync('calenfi-scale-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/scale');
    final notifier = InterfaceScaleNotifier(file: file);
    addTearDown(notifier.dispose);
    expect(notifier.state, 1);
    notifier.set(1.5);
    final restored = InterfaceScaleNotifier(file: file);
    addTearDown(restored.dispose);
    expect(restored.state, 1.5);
    expect(() => notifier.set(double.nan), throwsArgumentError);
    for (final invalid in ['broken', 'NaN', 'Infinity', '0', '3']) {
      file.writeAsStringSync(invalid);
      final invalidNotifier = InterfaceScaleNotifier(file: file);
      expect(invalidNotifier.state, 1);
      invalidNotifier.dispose();
    }
  });

  testWidgets('scale resizes layout, preserves state and maps input', (
    tester,
  ) async {
    final scale = ValueNotifier(1.0);
    addTearDown(scale.dispose);
    var taps = 0;
    var logicalWidth = 0.0;
    var delta = Offset.zero;
    final controller = TextEditingController(text: 'Draft');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: scale,
          builder: (context, value, _) =>
              InterfaceScale(scale: value, child: child!),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              logicalWidth = MediaQuery.sizeOf(context).width;
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => taps++,
                    onPanUpdate: (details) => delta += details.delta,
                    child: const SizedBox(
                      key: ValueKey('target'),
                      width: 100,
                      height: 50,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                  TextField(controller: controller),
                ],
              );
            },
          ),
        ),
      ),
    );
    final target = find.byKey(const ValueKey('target'));
    expect(logicalWidth, 800);
    scale.value = 2;
    await tester.pump();
    expect(logicalWidth, 400);
    final topLeft = tester.getTopLeft(target);
    final bottomRight = tester.getBottomRight(target);
    expect(bottomRight - topLeft, const Offset(200, 100));
    await tester.tap(target);
    expect(taps, 1);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await gesture.moveBy(const Offset(40, 0));
    delta = Offset.zero;
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    expect(delta.dx, closeTo(20, 0.1));
    expect(find.text('Draft'), findsOneWidget);
    scale.value = 1;
    await tester.pump();
    expect(logicalWidth, 800);
    expect(find.text('Draft'), findsOneWidget);
  });
}
