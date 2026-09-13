import 'dart:async';

import 'package:flutter/gestures.dart'
    show
        PointerDeviceKind,
        PanGestureRecognizer,
        LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/merged_event.dart';
import '../../l10n/app_localizations.dart';
import '../event_editor/event_editor_screen.dart';
import 'calendar_state.dart'
    show calendarClockProvider, moveModeProvider, commitDelayProvider;
import 'event_block.dart';
import 'event_details_sheet.dart';
import 'pending_edits.dart';
import 'recurrence_scope_dialog.dart';
import 'week_view.dart' show eventsForDay;

const double kHourHeight = 72; // крупнее: получасовые события читаемы (30мин=36px)
const double kGutterWidth = 54;
const int kSnapMinutes = 15; // квантизация (FR-E5)

/// Цвета линий сетки (видимые на тёмном фоне).
const Color kHourLineColor = Color(0x24FFFFFF); // ~14% белого
const Color kColumnLineColor = Color(0x33FFFFFF); // ~20% белого

/// Ресайз кромок события: ТОЛЬКО мышь/стилус. Трекпад намеренно исключён —
/// двухпальцевый скролл на macOS приходит как vertical-drag и, начавшись над
/// узкой (8px) кромкой, тянул размер вместо прокрутки. Трекпадом длительность
/// меняется через редактор события.
const Set<PointerDeviceKind> _kEdgeResize = {
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
};

double _snapPxToMinutes(double px) {
  final raw = px / kHourHeight * 60;
  return (raw / kSnapMinutes).round() * kSnapMinutes.toDouble();
}

DateTime _snapTime(DateTime t) {
  final total = t.hour * 60 + t.minute;
  final snapped = (total / kSnapMinutes).round() * kSnapMinutes;
  return DateTime(t.year, t.month, t.day).add(Duration(minutes: snapped));
}

/// Временная сетка (виды День/Неделя): перенос событий, изменение длительности,
/// тап по пустому месту → создание события (FR-E1, FR-E5).
class TimeGrid extends ConsumerStatefulWidget {
  const TimeGrid({
    super.key,
    required this.days,
    required this.events,
    required this.colors,
  });

  final List<DateTime> days;
  final List<MergedEvent> events;
  final Map<String, int> colors;

  @override
  ConsumerState<TimeGrid> createState() => _TimeGridState();
}

enum _DragMode { move, resize, resizeTop }

class _DragState {
  _DragState(this.id, this.mode);
  final String id;
  final _DragMode mode;
  double dx = 0;
  double dy = 0;
}

class _DrawSelection {
  _DrawSelection(this.start) : current = start;
  final Offset start;
  Offset current;
}

class _TimeGridState extends ConsumerState<TimeGrid> {
  late final ScrollController _scroll;
  _DragState? _drag;
  _DrawSelection? _draw;

  /// Ожидающие отправки изменения (id события → дедлайн отсчёта). Читается из
  /// [pendingEditsProvider] в [build]; используется в [_buildEvents] для рендера
  /// пунктира + бейджа с обратным отсчётом.
  Map<String, PendingEdit> _pending = const {};

  /// Односекундный тикер обратного отсчёта — работает только пока есть ожидающие
  /// изменения (иначе выключен, чтобы зря не перерисовывать).
  Timer? _countdown;

  /// Прямоугольники событий текущего кадра (в координатах Stack) для роутинга
  /// тапа в закреплённом режиме: там сами блоки — [IgnorePointer], а тап по
  /// событию открывает детали через слой создания (единый обработчик жестов).
  final List<({Rect rect, MergedEvent ev})> _hits = [];

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _initialOffset());
  }

  /// Рабочее окно — с 10:00 (раньше встреч обычно нет). После 16:00 подскролливаем
  /// вниз, чтобы текущее время оставалось в зоне видимости.
  double _initialOffset() {
    final now = ref.read(calendarClockProvider);
    final nowH = now.hour + now.minute / 60;
    final topHour = nowH > 16 ? (nowH - 4).clamp(10.0, 18.0) : 10.0;
    return topHour * kHourHeight;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Включает/выключает 1-сек тикер отсчёта в зависимости от наличия ожидающих.
  void _syncCountdownTicker(bool hasPending) {
    if (hasPending && _countdown == null) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!hasPending && _countdown != null) {
      _countdown!.cancel();
      _countdown = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Режим переноса: встречи откреплены и тянутся перетаскиванием. Иначе —
    // закреплены, а протяжка по сетке рисует новое событие (в т.ч. поверх них).
    final moveMode = ref.watch(moveModeProvider);
    final now = ref.watch(calendarClockProvider);
    _pending = ref.watch(pendingEditsProvider);
    _syncCountdownTicker(_pending.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final colW = (constraints.maxWidth - kGutterWidth) / widget.days.length;
        return SingleChildScrollView(
          controller: _scroll,
          child: SizedBox(
            height: 24 * kHourHeight,
            width: constraints.maxWidth,
            child: Stack(
              children: [
                // В режиме переноса слой создания — ПОД событиями (создаём только
                // на пустом месте, а по событиям идёт перетаскивание сверху).
                if (moveMode) _createLayer(colW),
                // часовые линии
                for (int h = 1; h < 24; h++)
                  Positioned(
                    top: h * kHourHeight,
                    left: kGutterWidth,
                    right: 0,
                    child: const Divider(height: 1, color: kHourLineColor),
                  ),
                // вертикальные разделители колонок
                for (int i = 0; i <= widget.days.length; i++)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: kGutterWidth + i * colW,
                    child: const ColoredBox(
                        color: kColumnLineColor, child: SizedBox(width: 1)),
                  ),
                // метки часов
                for (int h = 1; h < 24; h++)
                  Positioned(
                    top: h * kHourHeight - 6,
                    left: 0,
                    width: kGutterWidth - 6,
                    child: Text('${h.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                // события
                ..._buildEvents(colW, moveMode),
                // Превью создаваемого диапазона — ВСЕГДА в дереве (пустышка, когда
                // не рисуем), чтобы появление превью не сдвигало индексы детей и
                // не пересоздавало слой создания посреди жеста (иначе onPanEnd
                // теряется и событие не создаётся).
                _buildDrawPreview(colW),
                // линия текущего времени
                ..._buildNowLine(colW, now),
                // В закреплённом режиме слой создания — ПОВЕРХ всего: рисуем
                // новое событие даже поверх встреч/блокеров (тап проходит к ним
                // насквозь — слой прозрачен для хит-теста тапа).
                if (!moveMode) _createLayer(colW),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Длинное/all-day событие (напр. «Busy» 04:45–18:30) — не должно занимать
  /// колонку и сжимать реальные встречи; рисуем фоновой полосой.
  static bool _isBackground(MergedEvent e) =>
      e.primary.allDay ||
      e.primary.endUtc.difference(e.primary.startUtc).inMinutes >= 6 * 60;

  /// Слой создания события протяжкой (FR-E1) — в закреплённом режиме это
  /// ЕДИНСТВЕННЫЙ обработчик жестов сетки (блоки событий под ним — [IgnorePointer]),
  /// поэтому протяжка-создание работает и НАД занятым временем, не конкурируя с
  /// тапом блока. Тап роутится в детали события под точкой ([_handleTap]);
  /// long-press (тач) / click-drag (мышь/трекпад) рисуют диапазон. Кладётся
  /// ПОВЕРХ сетки в закреплённом режиме или ПОД событиями — в режиме переноса.
  Widget _createLayer(double colW) {
    return Positioned.fill(
      // Стабильный ключ: слой создания матчится по ключу, а не по индексу в
      // Stack, поэтому вставка/удаление превью не пересоздаёт его распознаватель
      // жестов посреди протяжки (иначе onPanEnd не срабатывает).
      key: const ValueKey('create-layer'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Тап (любое устройство) → детали события под точкой (блоки —
          // IgnorePointer, поэтому их InkWell тут не участвует).
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (d) => _handleTap(d.localPosition),
          ),
          // Touch: long-press + drag (чтобы не конфликтовать со скроллом).
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {PointerDeviceKind.touch},
            onLongPressStart: (d) =>
                setState(() => _draw = _DrawSelection(d.localPosition)),
            onLongPressMoveUpdate: (d) =>
                setState(() => _draw?.current = d.localPosition),
            onLongPressEnd: (_) => _commitDraw(colW),
            onLongPressCancel: () => setState(() => _draw = null),
          ),
          // Десктоп: click-drag по сетке → выделение диапазона. ТОЛЬКО мышь и
          // стилус: на трекпаде MacBook двухпальцевый скролл приходит как pan и
          // раньше рисовал событие вместо прокрутки. Трекпадом создаём тапом
          // (дефолтные 30 мин) либо long-press-протяжкой (ветка touch выше).
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
            },
            onPanStart: (d) =>
                setState(() => _draw = _DrawSelection(d.localPosition)),
            onPanUpdate: (d) =>
                setState(() => _draw?.current = d.localPosition),
            onPanEnd: (_) => _commitDraw(colW),
            onPanCancel: () => setState(() => _draw = null),
          ),
          // Трекпад/тач: long-press + протяжка по пустому месту → выделение
          // диапазона (не конфликтует со скроллом). Мгновенный скролл его не
          // запускает. Ветка выше (touch) остаётся для телефонов.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            supportedDevices: const {PointerDeviceKind.trackpad},
            onLongPressStart: (d) =>
                setState(() => _draw = _DrawSelection(d.localPosition)),
            onLongPressMoveUpdate: (d) =>
                setState(() => _draw?.current = d.localPosition),
            onLongPressEnd: (_) => _commitDraw(colW),
            onLongPressCancel: () => setState(() => _draw = null),
          ),
        ],
      ),
    );
  }

  /// Тап по слою создания → открыть детали события, чей прямоугольник накрывает
  /// точку (блоки сверху приоритетнее фоновых полос — идём с конца [_hits]).
  void _handleTap(Offset p) {
    for (final h in _hits.reversed) {
      if (h.rect.contains(p)) {
        showEventDetails(context, h.ev);
        return;
      }
    }
  }

  List<Widget> _buildEvents(double colW, bool moveMode) {
    _hits.clear(); // прямоугольники для роутинга тапа (пересобираются каждый кадр)
    final bands = <Widget>[]; // фоновые полосы (длинные события) — позади
    final blocks = <Widget>[]; // обычные встречи — поверх
    for (var di = 0; di < widget.days.length; di++) {
      final day = widget.days[di];
      final dayEvents = eventsForDay(widget.events, day);
      final background = dayEvents.where(_isBackground).toList();
      final timed = dayEvents.where((e) => !_isBackground(e)).toList();

      for (final me in background) {
        final left = kGutterWidth + di * colW;
        final top = _topFor(me.primary);
        final height = _heightFor(me.primary);
        _hits.add((rect: Rect.fromLTWH(left, top, colW, height), ev: me));
        // В закреплённом режиме полоса не ловит указатель — тапом рулит слой
        // создания (иначе он бы не мог начать протяжку поверх полосы).
        bands.add(Positioned(
          left: left,
          width: colW,
          top: top,
          height: height,
          child: moveMode
              ? _BackgroundBand(merged: me, color: Color(_colorOf(me)))
              : IgnorePointer(
                  child: _BackgroundBand(merged: me, color: Color(_colorOf(me)))),
        ));
      }

      final lanes = _assignLanes(timed);
      for (final p in lanes) {
        final e = p.event.primary;
        final isDragging = _drag?.id == e.id;
        final laneW = colW / p.laneCount;
        var left = kGutterWidth + di * colW + p.laneIndex * laneW;
        var top = _topFor(e);
        var height = _heightFor(e);

        // Прямоугольник для роутинга тапа — по БАЗОВЫМ координатам (в закреплённом
        // режиме drag-смещения нет; в режиме переноса тапом рулит сам блок).
        _hits.add((rect: Rect.fromLTWH(left, top, laneW, height), ev: p.event));

        if (isDragging && _drag!.mode == _DragMode.move) {
          left += _drag!.dx;
          top += _drag!.dy;
        } else if (isDragging && _drag!.mode == _DragMode.resize) {
          height = (height + _drag!.dy).clamp(kHourHeight * 0.25, 24 * kHourHeight);
        } else if (isDragging && _drag!.mode == _DragMode.resizeTop) {
          // Верхняя кромка: двигаем начало — top вниз/вверх, высота обратно.
          final d = _drag!.dy.clamp(-top, height - kHourHeight * 0.25);
          top += d;
          height -= d;
        }

        final pend = _pending[e.id];
        final Widget block = _DraggableEvent(
          merged: p.event,
          color: Color(_colorOf(p.event)),
          editMode: moveMode,
          onMoveStart: () {
            HapticFeedback.selectionClick();
            setState(() => _drag = _DragState(e.id, _DragMode.move));
          },
          // Перенос перетаскиванием: копим смещение по инкрементальным дельтам.
          onMoveDelta: (delta) => setState(() {
            _drag?.dx += delta.dx;
            _drag?.dy += delta.dy;
          }),
          onResizeStart: () =>
              setState(() => _drag = _DragState(e.id, _DragMode.resize)),
          onResizeUpdate: (dy) => setState(() => _drag?.dy += dy),
          onResizeTopStart: () =>
              setState(() => _drag = _DragState(e.id, _DragMode.resizeTop)),
          onResizeTopUpdate: (dy) => setState(() => _drag?.dy += dy),
          onEnd: () => _commitDrag(e, colW, di),
          onCancel: () => setState(() => _drag = null),
        );
        blocks.add(Positioned(
          left: left,
          top: top,
          width: laneW,
          height: height,
          // Ожидающее изменение: поверх блока — пунктир-точки + бейдж с обратным
          // отсчётом и галочкой «применить сейчас».
          child: pend == null
              ? block
              : Stack(children: [
                  Positioned.fill(child: block),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _PendingDotsPainter(Color(_colorOf(p.event))),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 1,
                    right: 2,
                    child: _PendingBadge(
                      deadline: pend.deadline,
                      onCancel: () => ref
                          .read(pendingEditsProvider.notifier)
                          .cancel(e.id),
                    ),
                  ),
                ]),
        ));
      }
    }
    return [...bands, ...blocks];
  }

  List<Widget> _buildNowLine(double colW, DateTime now) {
    final top = (now.hour * 60 + now.minute) / 60 * kHourHeight;
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final widgets = <Widget>[
      // подпись текущего времени в гаттере (FR-V6)
      Positioned(
        top: top - 7,
        left: 0,
        width: kGutterWidth - 4,
        child: Text(hm,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFE53935),
                fontWeight: FontWeight.bold)),
      ),
      // тонкая полоса во всю ширину календаря (все дни)
      Positioned(
        top: top - 0.5,
        left: kGutterWidth,
        right: 0,
        child: Container(
            height: 1, color: const Color(0xFFE53935).withValues(alpha: 0.45)),
      ),
    ];
    // на колонке сегодняшнего дня — жирнее + точка
    final di = widget.days.indexWhere((d) =>
        d.year == now.year && d.month == now.month && d.day == now.day);
    if (di >= 0) {
      widgets.add(Positioned(
        top: top - 3.5,
        left: kGutterWidth + di * colW,
        width: colW,
        child: Row(children: const [
          _NowDot(),
          Expanded(
              child: ColoredBox(
                  color: Color(0xFFE53935), child: SizedBox(height: 2.5))),
        ]),
      ));
    }
    return widgets;
  }

  Future<void> _commitDrag(CalendarEvent e, double colW, int dayIndex) async {
    final drag = _drag;
    if (drag == null) return;
    final start = e.startUtc.toLocal();
    final end = e.endUtc.toLocal();
    final duration = end.difference(start);

    // Задержка отправки: >0 → откладываем (пунктир + отсчёт + галочка, таймер
    // сбрасывается каждым новым изменением), 0 → отправляем сразу (как раньше).
    final delay = ref.read(commitDelayProvider);
    final pending = ref.read(pendingEditsProvider.notifier);

    /// Повторяющееся событие: спрашиваем, правим вхождение или всю серию.
    /// null — пользователь отменил, превью убираем и ничего не отправляем.
    Future<RecurrenceScope?> askScope() async {
      if (!e.isRecurring) return RecurrenceScope.thisOnly;
      if (!mounted) return null;
      return askRecurrenceEditScope(context);
    }

    if (drag.mode == _DragMode.move) {
      final dayDelta = (drag.dx / colW).round();
      final minDelta = _snapPxToMinutes(drag.dy);
      final newStart = _snapTime(start
          .add(Duration(days: dayDelta))
          .add(Duration(minutes: minDelta.round())));
      setState(() => _drag = null); // убрать превью переноса
      if (newStart == start) return; // фактического переноса нет
      final newEnd = newStart.add(duration);
      final updated =
          e.copyWith(startUtc: newStart.toUtc(), endUtc: newEnd.toUtc());
      final scope = await askScope();
      if (scope == null) return;
      if (delay > Duration.zero) {
        await pending.stage(updated, delay, original: e, scope: scope);
      } else {
        // Мгновенный режим — обязательное подтверждение переноса (FR-E3).
        // У повторяющегося события эту роль уже сыграл выбор области.
        if (!mounted) return;
        if (e.isRecurring || await _confirmMove(e.title, newStart, newEnd)) {
          await pending.stage(updated, Duration.zero, original: e, scope: scope);
        }
      }
    } else if (drag.mode == _DragMode.resizeTop) {
      // Верхняя кромка — двигаем начало, конец на месте.
      final minDelta = _snapPxToMinutes(drag.dy);
      var newStart = _snapTime(start.add(Duration(minutes: minDelta.round())));
      if (!newStart.isBefore(end)) {
        newStart = end.subtract(const Duration(minutes: kSnapMinutes));
      }
      setState(() => _drag = null);
      if (newStart != start) {
        final scope = await askScope();
        if (scope == null) return;
        await pending.stage(e.copyWith(startUtc: newStart.toUtc()), delay,
            original: e, scope: scope);
      }
    } else {
      final minDelta = _snapPxToMinutes(drag.dy);
      var newEnd = _snapTime(end.add(Duration(minutes: minDelta.round())));
      if (!newEnd.isAfter(start)) {
        newEnd = start.add(const Duration(minutes: kSnapMinutes));
      }
      setState(() => _drag = null);
      if (newEnd != end) {
        final scope = await askScope();
        if (scope == null) return;
        await pending.stage(e.copyWith(endUtc: newEnd.toUtc()), delay,
            original: e, scope: scope);
      }
    }
  }

  Future<bool> _confirmMove(
      String title, DateTime newStart, DateTime newEnd) async {
    final l10n = L10n.of(context);
    const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    String two(int v) => v.toString().padLeft(2, '0');
    String when(DateTime d) =>
        '${wd[d.weekday - 1]} ${two(d.day)}.${two(d.month)}, ${two(d.hour)}:${two(d.minute)}';
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.uiMoveEventTitle),
        content: Text(l10n.uiMoveEventBody(
            title.isEmpty ? l10n.uiNoTitle : title,
            '${when(newStart)} – ${two(newEnd.hour)}:${two(newEnd.minute)}')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.uiCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.uiMove)),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _buildDrawPreview(double colW) {
    final draw = _draw;
    // Постоянный слот в Stack: пустышка, пока диапазон не рисуется.
    if (draw == null || draw.start.dx < kGutterWidth) {
      return const SizedBox.shrink(key: ValueKey('draw-preview'));
    }
    final di = ((draw.start.dx - kGutterWidth) / colW)
        .floor()
        .clamp(0, widget.days.length - 1);
    final y1 = draw.start.dy < draw.current.dy ? draw.start.dy : draw.current.dy;
    final y2 = draw.start.dy < draw.current.dy ? draw.current.dy : draw.start.dy;
    final color = Theme.of(context).colorScheme.primary;
    return Positioned(
      key: const ValueKey('draw-preview'),
      left: kGutterWidth + di * colW,
      width: colW,
      top: y1,
      height: (y2 - y1).clamp(kHourHeight * 0.25, 24 * kHourHeight),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.topCenter,
        child: Text(_rangeLabel(di, y1, y2),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _rangeLabel(int di, double y1, double y2) {
    final s = _snapPxToMinutes(y1).round();
    var e = _snapPxToMinutes(y2).round();
    if (e - s < kSnapMinutes) e = s + 30;
    String fmt(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    return '${fmt(s)} – ${fmt(e)}';
  }

  void _commitDraw(double colW) {
    final draw = _draw;
    setState(() => _draw = null);
    if (draw == null || draw.start.dx < kGutterWidth) return;
    final di = ((draw.start.dx - kGutterWidth) / colW)
        .floor()
        .clamp(0, widget.days.length - 1);
    final day = widget.days[di];
    final y1 = draw.start.dy < draw.current.dy ? draw.start.dy : draw.current.dy;
    final y2 = draw.start.dy < draw.current.dy ? draw.current.dy : draw.start.dy;
    final startMin = _snapPxToMinutes(y1).round();
    var endMin = _snapPxToMinutes(y2).round();
    if (endMin - startMin < kSnapMinutes) endMin = startMin + 30;
    final base = DateTime(day.year, day.month, day.day);
    EventEditor.open(
      context,
      initialStart: base.add(Duration(minutes: startMin)),
      initialEnd: base.add(Duration(minutes: endMin)),
      initialDay: day,
    );
  }

  int _colorOf(MergedEvent e) =>
      e.primary.colorOverride ?? widget.colors[e.primary.calendarId] ?? 0xFF888888;

  double _topFor(CalendarEvent e) {
    final s = e.startUtc.toLocal();
    return (s.hour * 60 + s.minute) / 60 * kHourHeight;
  }

  double _heightFor(CalendarEvent e) {
    final mins =
        e.endUtc.difference(e.startUtc).inMinutes.clamp(20, 24 * 60);
    return mins / 60 * kHourHeight;
  }

  /// Кластерная раскладка пересечений (FR-V8). [events] отсортированы по началу.
  ///
  /// Связанный кластер пересекающихся событий делит ОДНО число колонок — иначе
  /// «широкие» ранние события наезжают на более поздние узкие.
  List<_Placed> _assignLanes(List<MergedEvent> events) {
    final result = <_Placed>[];
    var i = 0;
    while (i < events.length) {
      // 1) максимальный связный кластер по пересечению.
      final cluster = <MergedEvent>[events[i]];
      var clusterEnd = events[i].primary.endUtc;
      var j = i + 1;
      while (j < events.length &&
          events[j].primary.startUtc.isBefore(clusterEnd)) {
        cluster.add(events[j]);
        if (events[j].primary.endUtc.isAfter(clusterEnd)) {
          clusterEnd = events[j].primary.endUtc;
        }
        j++;
      }
      // 2) жадно по колонкам (низшая свободная).
      final colEnds = <DateTime>[];
      final placed = <_Placed>[];
      for (final e in cluster) {
        var col = 0;
        while (col < colEnds.length &&
            colEnds[col].isAfter(e.primary.startUtc)) {
          col++;
        }
        if (col == colEnds.length) {
          colEnds.add(e.primary.endUtc);
        } else {
          colEnds[col] = e.primary.endUtc;
        }
        placed.add(_Placed(event: e, laneIndex: col, laneCount: 1));
      }
      // 3) весь кластер делит одинаковое число колонок.
      for (final p in placed) {
        p.laneCount = colEnds.length;
        result.add(p);
      }
      i = j;
    }
    return result;
  }
}

/// Блок события в сетке.
///
///  • [editMode]=false («закреплено») — только тап открывает детали
///    (через InkWell внутри [EventBlock]); переноса нет, а рисование нового
///    события поверх делает слой создания над сеткой.
///  • [editMode]=true («откреплено») — перенос простым перетаскиванием тела и
///    ресайз нижней кромкой (мышь). Тап по-прежнему открывает детали.
class _DraggableEvent extends StatefulWidget {
  const _DraggableEvent({
    required this.merged,
    required this.color,
    required this.editMode,
    required this.onMoveStart,
    required this.onMoveDelta,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeTopStart,
    required this.onResizeTopUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final MergedEvent merged;
  final Color color;
  final bool editMode;
  final VoidCallback onMoveStart;
  final void Function(Offset delta) onMoveDelta;
  final VoidCallback onResizeStart;
  final void Function(double dy) onResizeUpdate;
  final VoidCallback onResizeTopStart;
  final void Function(double dy) onResizeTopUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  State<_DraggableEvent> createState() => _DraggableEventState();
}

class _DraggableEventState extends State<_DraggableEvent> {
  /// Накопленное смещение long-press-drag: он даёт offsetFromOrigin
  /// (кумулятивный от точки нажатия), а onMoveDelta ждёт инкремент.
  Offset _lastOffset = Offset.zero;

  MergedEvent get merged => widget.merged;
  Color get color => widget.color;
  bool get editMode => widget.editMode;

  @override
  Widget build(BuildContext context) {
    // Закреплено: блок НЕ ловит указатель — и тапом (детали), и протяжкой
    // (создание поверх) целиком рулит слой создания над сеткой. Иначе InkWell
    // блока перехватывал бы жест и не давал начать создание над занятым местом.
    if (!editMode) {
      return IgnorePointer(child: EventBlock(event: merged, color: color));
    }

    return Stack(
      children: [
        // Перенос тела события — по-разному для мыши и трекпада:
        //  • Мышь/стилус — обычный click-drag (мгновенно), как привыкли на
        //    десктопе. Колёсико мыши даёт scroll-события, а НЕ pan, поэтому
        //    прокрутка мышью встречу не тянет.
        //  • Трекпад — long-press-drag (подержать ~0.5с, потом тащить): иначе
        //    двухпальцевый скролл macOS (он приходит как pan) случайно таскал
        //    встречи. Скролл мгновенный — long-press не срабатывает, прокрутка
        //    штатно уходит в ScrollView.
        // Тап (InkWell внутри EventBlock) в обоих случаях открывает детали.
        // Оба распознавателя на ОДНОМ RawGestureDetector (без вложенности —
        // из-за неё мышью было тяжело зацепить событие): мышиный pan работает
        // так же отзывчиво, как раньше.
        Positioned.fill(
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              PanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(
                  supportedDevices: const {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                  },
                ),
                (r) {
                  r.onStart = (_) => widget.onMoveStart();
                  r.onUpdate = (d) => widget.onMoveDelta(d.delta);
                  r.onEnd = (_) => widget.onEnd();
                  r.onCancel = widget.onCancel;
                },
              ),
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  supportedDevices: const {PointerDeviceKind.trackpad},
                ),
                (r) {
                  r.onLongPressStart = (_) {
                    _lastOffset = Offset.zero;
                    widget.onMoveStart();
                  };
                  r.onLongPressMoveUpdate = (d) {
                    widget.onMoveDelta(d.offsetFromOrigin - _lastOffset);
                    _lastOffset = d.offsetFromOrigin;
                  };
                  r.onLongPressEnd = (_) => widget.onEnd();
                  r.onLongPressCancel = widget.onCancel;
                },
              ),
            },
            child: EventBlock(event: merged, color: color),
          ),
        ),
        // ресайз — верхняя кромка (мышь): двигает НАЧАЛО события.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            supportedDevices: _kEdgeResize,
            onVerticalDragStart: (_) => widget.onResizeTopStart(),
            onVerticalDragUpdate: (d) => widget.onResizeTopUpdate(d.delta.dy),
            onVerticalDragEnd: (_) => widget.onEnd(),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        // ресайз — нижняя кромка (мышь; на тач размер меняется через редактор)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 8,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            supportedDevices: _kEdgeResize,
            onVerticalDragStart: (_) => widget.onResizeStart(),
            onVerticalDragUpdate: (d) => widget.onResizeUpdate(d.delta.dy),
            onVerticalDragEnd: (_) => widget.onEnd(),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  width: 24,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Фоновая полоса для длинного/all-day события (напр. «Busy» на весь день).
/// Не занимает колонку; обычные встречи рисуются поверх.
class _BackgroundBand extends StatelessWidget {
  const _BackgroundBand({required this.merged, required this.color});
  final MergedEvent merged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => showEventDetails(context, merged),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border(left: BorderSide(color: color.withValues(alpha: 0.7), width: 3)),
        ),
        padding: const EdgeInsets.only(left: 6, top: 2),
        alignment: Alignment.topLeft,
        child: Text(merged.primary.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10, color: color.withValues(alpha: 0.85))),
      ),
    );
  }
}

class _NowDot extends StatelessWidget {
  const _NowDot();
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      decoration:
          const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle));
}

class _Placed {
  _Placed({required this.event, required this.laneIndex, required this.laneCount});
  final MergedEvent event;
  final int laneIndex;
  int laneCount;
}

/// Пунктир-точки поверх ожидающего изменения (визуальный сигнал «ещё не
/// отправлено на сервер»).
class _PendingDotsPainter extends CustomPainter {
  _PendingDotsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    const gap = 6.0;
    for (var y = 4.0; y < size.height; y += gap) {
      for (var x = 4.0; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PendingDotsPainter old) => old.color != color;
}

/// Бейдж ожидающего изменения: обратный отсчёт до автоотправки + галочка
/// «применить сейчас». Перерисовывается раз в секунду тикером [_TimeGridState].
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.deadline, required this.onCancel});
  final DateTime deadline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final secs = deadline.difference(DateTime.now()).inSeconds.clamp(0, 24 * 3600);
    final mm = (secs ~/ 60).toString();
    final ss = (secs % 60).toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.only(left: 6, right: 1),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
        const SizedBox(width: 3),
        Text('$mm:$ss',
            style: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
        // Крестик «отменить» — вернуть исходное (в облако не отправлять).
        // Отправка всех правок — кнопкой «В облако» в верхней панели.
        InkWell(
          onTap: onCancel,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.cancel, size: 16, color: Colors.redAccent),
          ),
        ),
      ]),
    );
  }
}
