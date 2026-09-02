import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/merged_event.dart';
import '../../domain/providers/calendar_provider.dart';

/// Виды календаря (FR-V1/V2).
enum CalendarViewMode { day, week, month, quarter, year }

/// Текущий выбранный вид.
final viewModeProvider =
    StateProvider<CalendarViewMode>((_) => CalendarViewMode.week);

/// Дата, вокруг которой строится текущий вид.
final focusedDateProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Источник wall-clock времени. Отдельный provider нужен, чтобы lifecycle и
/// границы минуты/суток проверялись детерминированно в тестах.
final calendarClockSourceProvider =
    Provider<DateTime Function()>((_) => DateTime.now);

/// Задержка до следующей точной границы минуты.
///
/// В отличие от [Timer.periodic], каждый следующий тик считается заново от
/// wall clock: задержка обработки кадра или sleep не накапливают дрейф.
@visibleForTesting
Duration calendarClockDelay(DateTime now) {
  final elapsed = Duration(
    seconds: now.second,
    milliseconds: now.millisecond,
    microseconds: now.microsecond,
  );
  return const Duration(minutes: 1) - elapsed;
}

bool _sameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Единые часы календаря: один минутный таймер на весь ProviderScope, а не по
/// таймеру на каждую страницу временной сетки.
///
/// Пока приложение скрыто/приостановлено, таймер выключен. На resume часы
/// читаются немедленно и подписчики получают новый кадр до запуска следующего
/// выровненного one-shot таймера.
class CalendarClockNotifier extends StateNotifier<DateTime>
    with WidgetsBindingObserver {
  CalendarClockNotifier({
    required DateTime Function() now,
    required this.onDayChanged,
  })  : _now = now,
        super(now()) {
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextTick();
  }

  final DateTime Function() _now;
  final void Function(DateTime previous, DateTime current) onDayChanged;
  Timer? _timer;

  static bool _runsIn(AppLifecycleState? lifecycle) =>
      lifecycle == null ||
      lifecycle == AppLifecycleState.resumed ||
      lifecycle == AppLifecycleState.inactive;

  void _scheduleNextTick() {
    _timer?.cancel();
    _timer = null;
    if (!_runsIn(WidgetsBinding.instance.lifecycleState)) return;
    _timer = Timer(calendarClockDelay(_now()), _tick);
  }

  void _tick() {
    _timer = null;
    _refresh();
    _scheduleNextTick();
  }

  void _refresh() {
    final previous = state;
    final current = _now();
    state = current;
    if (!_sameLocalDay(previous, current)) {
      onDayChanged(previous, current);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_runsIn(state)) {
      // Не ждём очередного тика после sleep/background: repaint с актуальным
      // wall-clock временем должен быть запланирован сразу на resume.
      _refresh();
      _scheduleNextTick();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

/// Текущее локальное время, общее для индикатора, заголовка и смены суток.
final calendarClockProvider =
    StateNotifierProvider<CalendarClockNotifier, DateTime>((ref) {
  return CalendarClockNotifier(
    now: ref.watch(calendarClockSourceProvider),
    onDayChanged: (previous, current) {
      final focused = ref.read(focusedDateProvider);
      // Автоматически продолжаем следовать за «сегодня» только если перед
      // полуночью пользователь действительно смотрел текущий день. Просмотр
      // истории/будущего не должен внезапно перескакивать.
      if (_sameLocalDay(focused, previous)) {
        ref.read(focusedDateProvider.notifier).state =
            DateTime(current.year, current.month, current.day);
      }
    },
  );
});

/// Тумблер «показать удалённые/отменённые» (FR-V12).
final showCancelledProvider = StateProvider<bool>((_) => false);

/// Показывать ли месячный вид (на телефоне он тесный — можно скрыть, FR-C12).
final showMonthViewProvider = StateProvider<bool>((_) => true);

/// «Combine identical events» — склейка дублей (FR-C11/FR-D8).
final combineProvider = StateProvider<bool>((_) => true);

/// Задержка перед отправкой изменения события (перенос/ресайз) на сервер.
/// В течение неё событие показывается «ожидающим» (пунктир + обратный отсчёт +
/// галочка «применить сейчас»), таймер сбрасывается при каждом новом изменении.
/// **0 → отправляем сразу**, без ожидающего UI. По умолчанию — 2 минуты.
final commitDelayProvider =
    StateProvider<Duration>((_) => const Duration(minutes: 2));

/// Мобильная платформа (телефон/планшет). На десктопе ложных нажатий нет, поэтому
/// «закреп» там не нужен, а перетаскивание/ресайз включены по умолчанию.
bool get isMobilePlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Режим переноса встреч. Быстрый переключатель в топ-баре.
///   • false («закреплено») — встречи закреплены: тап открывает детали, а
///     протяжка по сетке РИСУЕТ новое событие даже поверх занятого времени.
///   • true («откреплено») — встречи тянутся перетаскиванием (перенос) и
///     меняют длительность ресайзом; тап по-прежнему открывает детали.
///
/// Дефолт зависит от платформы: на **мобиле** — «закреплено» (защита от ложных
/// касаний, тумблер доступен), на **десктопе** — «откреплено» (тумблер скрыт,
/// см. [calendar_screen]).
final moveModeProvider = StateProvider<bool>((_) => !isMobilePlatform);

/// Сдвиг видимого периода на [dir] (±1) с учётом текущего вида.
void shiftFocused(WidgetRef ref, int dir) {
  final mode = ref.read(viewModeProvider);
  final d = ref.read(focusedDateProvider);
  ref.read(focusedDateProvider.notifier).state = switch (mode) {
    CalendarViewMode.day => d.add(Duration(days: dir)),
    CalendarViewMode.week => d.add(Duration(days: 7 * dir)),
    _ => DateTime(d.year, d.month + dir, 1),
  };
}

/// Перейти к сегодняшнему дню.
void goToday(WidgetRef ref) {
  final n = DateTime.now();
  ref.read(focusedDateProvider.notifier).state = DateTime(n.year, n.month, n.day);
}

/// Понедельник недели, содержащей [focusedDate] (начало недели — Пн, FR-C7).
DateTime weekStart(DateTime focusedDate) {
  final d = DateTime(focusedDate.year, focusedDate.month, focusedDate.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Сетка месяца: 6 недель, начиная с понедельника недели 1-го числа.
DateTime monthGridStart(DateTime focused) =>
    weekStart(DateTime(focused.year, focused.month, 1));

/// Видимый диапазон под текущий вид.
final visibleRangeProvider = Provider<DateRange>((ref) {
  final mode = ref.watch(viewModeProvider);
  final f = ref.watch(focusedDateProvider);
  switch (mode) {
    case CalendarViewMode.day:
      final s = DateTime(f.year, f.month, f.day);
      return DateRange(s.toUtc(), s.add(const Duration(days: 1)).toUtc());
    case CalendarViewMode.week:
      final s = weekStart(f);
      return DateRange(s.toUtc(), s.add(const Duration(days: 7)).toUtc());
    case CalendarViewMode.month:
    default:
      final s = monthGridStart(f);
      return DateRange(s.toUtc(), s.add(const Duration(days: 42)).toUtc());
  }
});

/// Карта цветов календарей (id → ARGB).
final calendarColorsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(accountRepositoryProvider).watchCalendars().map(
        (cals) => {for (final c in cals) c.id: c.effectiveColor},
      );
});

/// Список календарей (для настроек/тумблеров видимости).
final calendarsListProvider = StreamProvider<List<Calendar>>((ref) {
  return ref.watch(accountRepositoryProvider).watchCalendars();
});

/// Краткая инфа о календаре для отображения источника события (FR-V10).
class CalendarInfo {
  const CalendarInfo({
    required this.name,
    required this.color,
    required this.accountName,
    required this.readOnly,
  });
  final String name;
  final int color;
  final String accountName;
  final bool readOnly;
}

/// Карта `calendarId → CalendarInfo` (имя календаря + имя аккаунта + цвет).
/// Нужна, чтобы в карточке события показать, из какого календаря оно вытянуто.
final calendarInfoProvider = Provider<Map<String, CalendarInfo>>((ref) {
  final cals = ref.watch(calendarsListProvider).value ?? const <Calendar>[];
  final accts = ref.watch(accountsStreamProvider).value ?? const [];
  final acctName = {for (final a in accts) a.id: a.displayName};
  return {
    for (final c in cals)
      c.id: CalendarInfo(
        name: c.effectiveName,
        color: c.effectiveColor,
        accountName: acctName[c.accountId] ?? '',
        readOnly: c.readOnly,
      ),
  };
});

/// Склеенные события конкретного дня (для плавного PageView дневного вида).
/// Каждая страница свайпа подписывается на свой день независимо.
final dayEventsProvider =
    StreamProvider.family<List<MergedEvent>, DateTime>((ref, day) {
  final repo = ref.watch(eventRepositoryProvider);
  final start = DateTime(day.year, day.month, day.day);
  final range =
      DateRange(start.toUtc(), start.add(const Duration(days: 1)).toUtc());
  final includeCancelled = ref.watch(showCancelledProvider);
  final combine = ref.watch(combineProvider);
  return repo.watchMerged(range,
      includeCancelled: includeCancelled, combine: combine);
});

/// Склеенные события видимого диапазона (реактивно, FR-V4/FR-D1).
final mergedEventsProvider = StreamProvider<List<MergedEvent>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  final range = ref.watch(visibleRangeProvider);
  final includeCancelled = ref.watch(showCancelledProvider);
  final combine = ref.watch(combineProvider);
  return repo.watchMerged(range,
      includeCancelled: includeCancelled, combine: combine);
});
