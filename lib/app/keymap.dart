import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calendar/calendar_state.dart';
import '../features/calendar/pending_edits.dart';
import '../features/event_editor/event_editor_screen.dart';
import 'providers.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Клавиатурные привязки Calenfi — единый файл (по аналогии с keymap в mc).
/// Чтобы перепривязать клавишу — правьте только карту [kCalenfiKeymap] ниже.
/// ─────────────────────────────────────────────────────────────────────────

// --- Намерения (intents) ---
class NewEventIntent extends Intent {
  const NewEventIntent();
}

class TodayIntent extends Intent {
  const TodayIntent();
}

class PrevPeriodIntent extends Intent {
  const PrevPeriodIntent();
}

class NextPeriodIntent extends Intent {
  const NextPeriodIntent();
}

class SetViewIntent extends Intent {
  const SetViewIntent(this.mode);
  final CalendarViewMode mode;
}

class SyncIntent extends Intent {
  const SyncIntent();
}

class ToggleCancelledIntent extends Intent {
  const ToggleCancelledIntent();
}

/// Единая карта привязок. Здесь и только здесь меняются горячие клавиши.
const Map<ShortcutActivator, Intent> kCalenfiKeymap = {
  SingleActivator(LogicalKeyboardKey.keyN): NewEventIntent(),
  SingleActivator(LogicalKeyboardKey.keyT): TodayIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft): PrevPeriodIntent(),
  SingleActivator(LogicalKeyboardKey.arrowRight): NextPeriodIntent(),
  SingleActivator(LogicalKeyboardKey.digit1): SetViewIntent(CalendarViewMode.day),
  SingleActivator(LogicalKeyboardKey.digit2): SetViewIntent(CalendarViewMode.week),
  SingleActivator(LogicalKeyboardKey.digit3): SetViewIntent(CalendarViewMode.month),
  SingleActivator(LogicalKeyboardKey.keyR): SyncIntent(),
  SingleActivator(LogicalKeyboardKey.keyR, control: true): SyncIntent(),
  SingleActivator(LogicalKeyboardKey.keyH): ToggleCancelledIntent(),
};

/// Подсказки для UI (например, тултипы) — описание привязок одним местом.
const Map<String, String> kKeymapHints = {
  'N': 'Новое событие',
  'T': 'Сегодня',
  '← / →': 'Предыдущий / следующий период',
  '1 / 2 / 3': 'День / Неделя / Месяц',
  'R': 'Синхронизировать',
  'H': 'Показать удалённые',
  'Esc': 'Закрыть модалку',
};

/// Фокус сейчас в поле ввода текста (поиск, форма)?
///
/// Привязки без модификаторов — это обычные буквы, цифры и стрелки. Пока
/// человек печатает, они принадлежат полю: «r» в поиске должна стать буквой,
/// а не запускать синхронизацию, стрелки — двигать курсор, а не листать неделю.
bool isEditingText() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText ||
      ctx.findAncestorStateOfType<EditableTextState>() != null;
}

/// Действие глобальной привязки: выключено, пока фокус в поле ввода. Выключенное
/// действие не поглощает клавишу, и она доходит до текстового поля.
class _KeymapAction<T extends Intent> extends Action<T> {
  _KeymapAction(this._onInvoke);
  final void Function(T intent) _onInvoke;

  @override
  bool isEnabled(T intent) => !isEditingText();

  @override
  Object? invoke(T intent) {
    _onInvoke(intent);
    return null;
  }
}

/// Оборачивает дерево виджетов глобальными привязками + действиями.
class CalenfiKeymap extends ConsumerWidget {
  const CalenfiKeymap({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: kCalenfiKeymap,
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewEventIntent: _KeymapAction<NewEventIntent>((_) {
            EventEditor.open(context,
                initialDay: ref.read(focusedDateProvider));
          }),
          TodayIntent: _KeymapAction<TodayIntent>((_) => goToday(ref)),
          PrevPeriodIntent:
              _KeymapAction<PrevPeriodIntent>((_) => shiftFocused(ref, -1)),
          NextPeriodIntent:
              _KeymapAction<NextPeriodIntent>((_) => shiftFocused(ref, 1)),
          SetViewIntent: _KeymapAction<SetViewIntent>((i) {
            ref.read(viewModeProvider.notifier).state = i.mode;
          }),
          SyncIntent: _KeymapAction<SyncIntent>((_) {
            // Сначала флашим отложенные правки в Outbox, потом синк (иначе
            // уходит только первое перенесённое событие). См. _SyncStatus.
            ref.read(pendingEditsProvider.notifier).applyAll().then(
                (_) => ref.read(syncTriggerProvider)());
          }),
          ToggleCancelledIntent: _KeymapAction<ToggleCancelledIntent>((_) {
            final cur = ref.read(showCancelledProvider);
            ref.read(showCancelledProvider.notifier).state = !cur;
          }),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}
