// Регрессионные тесты жестов календарной сетки (баг был на macOS):
// двухпальцевый скролл трекпада приходит как pan/drag и РАНЬШЕ случайно
// переносил/ресайзил события и рисовал новые. После фикса:
//   • перенос тела события мышью — обычный click-drag (PanGestureRecognizer,
//     только mouse/stylus); трекпадом — ТОЛЬКО long-press-drag;
//   • ресайз-кромки (верх/низ 8px) — только mouse/stylus;
//   • протяжка-создание по пустому месту — pan только mouse/stylus,
//     трекпад — long-press.
// Наблюдаемый эффект переноса/ресайза: _commitDrag стейджит правку через
// pendingEditsProvider.notifier.stage(...) — подменяем нотификатор фейком,
// который записывает вызовы stage().
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/event_block.dart';
import 'package:calenfi/features/calendar/pending_edits.dart';
import 'package:calenfi/features/calendar/time_grid.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rec extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);
}

bool _hasDialog(_Rec o) =>
    o.pushed.any((r) => r.runtimeType.toString().contains('Dialog'));
bool _hasSheet(_Rec o) =>
    o.pushed.any((r) => r.runtimeType.toString().contains('ModalBottomSheet'));

/// Репозиторий/движок синка не должны понадобиться: фейковый нотификатор
/// перехватывает stage() до обращения к ним.
class _FakeEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'EventRepository не должен вызываться в этом тесте: ${invocation.memberName}');
}

class _FakeSyncEngine implements SyncEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'SyncEngine не должен вызываться в этом тесте: ${invocation.memberName}');
}

/// Записывает вызовы stage() вместо реальной работы (БД/Outbox/таймеры).
class _RecordingPendingEdits extends PendingEditsNotifier {
  _RecordingPendingEdits() : super(_FakeEventRepository(), _FakeSyncEngine());

  final staged = <CalendarEvent>[];
  final stagedScopes = <RecurrenceScope>[];

  @override
  Future<void> stage(CalendarEvent updated, Duration delay,
      {String op = 'update',
      CalendarEvent? original,
      RecurrenceScope scope = RecurrenceScope.thisOnly}) async {
    staged.add(updated);
    stagedScopes.add(scope);
  }
}

void main() {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  final start = DateTime(today.year, today.month, today.day, 10); // 10:00 local
  final ev = CalendarEvent(
    id: 'e1',
    calendarId: 'c1',
    title: 'Существующая',
    startUtc: start.toUtc(),
    endUtc: start.add(const Duration(hours: 1)).toUtc(),
    source: const EventSource(accountId: 'a1', calendarId: 'c1'),
  );
  final me = MergedEvent(groupId: 'g1', primary: ev, sources: [ev]);

  Widget harness(_Rec obs, _RecordingPendingEdits pending,
          {bool moveMode = true}) =>
      ProviderScope(
        overrides: [
          moveModeProvider.overrideWith((ref) => moveMode),
          // Задержка > 0 → _commitDrag стейджит сразу, без диалога подтверждения.
          commitDelayProvider.overrideWith((ref) => const Duration(minutes: 2)),
          pendingEditsProvider.overrideWith((ref) => pending),
        ],
        child: MaterialApp(
          navigatorObservers: [obs],
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 700,
              child: TimeGrid(days: [day], events: [me], colors: const {}),
            ),
          ),
        ),
      );

  /// Центр ТЕЛА события (не кромок): блок высотой 72px, центр — в 36px от
  /// верха, безопасно вне 8px-кромок ресайза. Сначала доскролливаем до
  /// события — начальный оффсет сетки зависит от текущего времени.
  Future<Offset> bodyCenter(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(EventBlock));
    await tester.pump();
    return tester.getCenter(find.byType(EventBlock));
  }

  /// Протяжка вниз на [dy]px мелкими шагами (как двигается реальный указатель).
  /// Для kind=trackpad startGesture шлёт PointerPanZoom-события — ровно так
  /// macOS доставляет двухпальцевый скролл (суть регресса).
  Future<void> drag(WidgetTester tester, Offset from, PointerDeviceKind kind,
      {double dy = 72}) async {
    final g = await tester.startGesture(from, kind: kind);
    await tester.pump(const Duration(milliseconds: 40));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(Offset(0, dy / 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('трекпад-pan по телу события НЕ начинает перенос (регресс macOS)',
      (tester) async {
    final obs = _Rec();
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(obs, pending));
    await tester.pump();
    final center = await bodyCenter(tester);
    // Двухпальцевый скролл = мгновенный pan трекпадом: long-press не успевает,
    // PanGestureRecognizer тела события трекпад не поддерживает.
    await drag(tester, center, PointerDeviceKind.trackpad, dy: 120);
    tester.takeException();
    expect(pending.staged, isEmpty,
        reason: 'трекпад-pan не должен стейджить перенос события');
    expect(_hasDialog(obs), isFalse, reason: 'никаких диалогов подтверждения');
    expect(_hasSheet(obs), isFalse);
  });

  testWidgets('мышиный click-drag по телу события НАЧИНАЕТ перенос (контроль)',
      (tester) async {
    final obs = _Rec();
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(obs, pending));
    await tester.pump();
    final center = await bodyCenter(tester);
    await drag(tester, center, PointerDeviceKind.mouse, dy: 72); // 72px = 1 час
    await tester.pumpAndSettle();
    tester.takeException();
    expect(pending.staged, isNotEmpty,
        reason: 'мышиный drag тела должен стейджить перенос');
    expect(pending.staged.last.startUtc, isNot(ev.startUtc),
        reason: 'время начала должно измениться');
  });

  testWidgets('трекпад-pan по пустому месту НЕ рисует событие (регресс macOS)',
      (tester) async {
    final obs = _Rec();
    final pending = _RecordingPendingEdits();
    // Закреплённый режим — как в тесте создания: протяжка рисует событие.
    await tester.pumpWidget(harness(obs, pending, moveMode: false));
    await tester.pump();
    // ~пустое место в видимой области (событие 10:00 туда не попадает).
    await drag(tester, const Offset(400, 360), PointerDeviceKind.trackpad,
        dy: 120);
    tester.takeException();
    expect(_hasDialog(obs), isFalse,
        reason: 'трекпад-pan (скролл) не должен открывать редактор создания');
    expect(_hasSheet(obs), isFalse);
    expect(pending.staged, isEmpty);
  });

  testWidgets(
      'мышиный drag по пустому месту РИСУЕТ событие и в режиме переноса',
      (tester) async {
    // Пиннед-режим уже покрыт time_grid_create_test.dart («drag over EMPTY
    // space creates»); здесь — позитивный контроль в режиме переноса, где слой
    // создания лежит ПОД событиями: фильтры устройств не должны ломать
    // мышиное рисование. (Позитивный контроль трекпадного long-press-drag в
    // widget-тесте невозможен: framework запрещает down-события с
    // kind=trackpad, а panZoom long-press не слушает.)
    final obs = _Rec();
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(obs, pending)); // moveMode = true
    await tester.pump();
    // Пустое место чуть ниже блока события (между часовыми линиями: в режиме
    // переноса слой создания — ПОД сеткой, и точка ровно на Divider часа до
    // него не доходит).
    await tester.ensureVisible(find.byType(EventBlock));
    await tester.pump();
    final rect = tester.getRect(find.byType(EventBlock));
    await drag(tester, Offset(rect.center.dx, rect.bottom + 100),
        PointerDeviceKind.mouse, dy: 120);
    tester.takeException();
    expect(_hasDialog(obs), isTrue,
        reason: 'мышиная протяжка по пустому месту должна открыть редактор');
    expect(_hasSheet(obs), isFalse);
    expect(pending.staged, isEmpty, reason: 'перенос не должен стейджиться');
  });

  testWidgets('кромки ресайза: трекпад НЕ ресайзит, мышь — ресайзит',
      (tester) async {
    final obs = _Rec();
    final pending = _RecordingPendingEdits();
    await tester.pumpWidget(harness(obs, pending));
    await tester.pump();

    // Трекпад по нижней кромке (8px): раньше двухпальцевый скролл, начавшийся
    // над кромкой, тянул длительность. Теперь кромка — только mouse/stylus.
    await tester.ensureVisible(find.byType(EventBlock));
    await tester.pump();
    var rect = tester.getRect(find.byType(EventBlock));
    await drag(tester, Offset(rect.center.dx, rect.bottom - 4),
        PointerDeviceKind.trackpad, dy: 72);
    tester.takeException();
    expect(pending.staged, isEmpty,
        reason: 'трекпад по кромке не должен менять длительность');

    // Мышь по нижней кромке — штатный ресайз: конец сдвигается, начало нет.
    rect = tester.getRect(find.byType(EventBlock));
    await drag(tester, Offset(rect.center.dx, rect.bottom - 4),
        PointerDeviceKind.mouse, dy: 72);
    await tester.pumpAndSettle();
    tester.takeException();
    expect(pending.staged, isNotEmpty,
        reason: 'мышиный drag кромки должен стейджить ресайз');
    expect(pending.staged.last.startUtc, ev.startUtc,
        reason: 'ресайз нижней кромкой не трогает начало');
    expect(pending.staged.last.endUtc, isNot(ev.endUtc),
        reason: 'конец события должен сдвинуться');
  });
}
