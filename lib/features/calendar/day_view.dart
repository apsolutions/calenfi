import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/window_class.dart';
import 'calendar_state.dart';
import 'time_grid.dart';

/// Дневной вид (FR-V1) с плавным листанием свайпом: каждый день — отдельная
/// страница [PageView], сдвигается анимированно, не рывком.
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  static const _center = 100000;
  late final DateTime _anchor;
  late final PageController _controller;
  bool _suppress = false;

  @override
  void initState() {
    super.initState();
    final f = ref.read(focusedDateProvider);
    _anchor = DateTime(f.year, f.month, f.day);
    _controller = PageController(initialPage: _center);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int page) =>
      _anchor.add(Duration(days: page - _center));
  int _pageForDate(DateTime d) =>
      _center + DateTime(d.year, d.month, d.day).difference(_anchor).inDays;

  @override
  Widget build(BuildContext context) {
    // Внешние смены даты (кнопка «Сегодня») — листаем контроллер к нужной странице.
    ref.listen(focusedDateProvider, (_, next) {
      if (_suppress || !_controller.hasClients) return;
      final target = _pageForDate(next);
      if ((_controller.page?.round() ?? _center) != target) {
        _controller.jumpToPage(target);
      }
    });

    return PageView.builder(
      controller: _controller,
      onPageChanged: (page) {
        _suppress = true;
        ref.read(focusedDateProvider.notifier).state = _dateForPage(page);
        _suppress = false;
      },
      itemBuilder: (_, page) => _DayPage(day: _dateForPage(page)),
    );
  }
}

/// Одна страница дневного вида: компактная шапка + сетка событий этого дня.
class _DayPage extends ConsumerWidget {
  const _DayPage({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(dayEventsProvider(day));
    final colorsAsync = ref.watch(calendarColorsProvider);

    // На телефоне отдельная строка с днём недели и числом съедала 57 точек
    // высоты, повторяя дату, которая и так стоит в шапке экрана. Оставляем её
    // только там, где места много (планшет, десктоп).
    final wide = windowClassOf(context) != WindowClass.compact;

    return Column(
      children: [
        if (wide) ...[
          DayColumnHeader(day: day),
          const Divider(height: 1),
        ],
        Expanded(
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка: $e')),
            data: (events) => TimeGrid(
              days: [day],
              events: events,
              colors: colorsAsync.value ?? const {},
            ),
          ),
        ),
      ],
    );
  }
}

/// Высота строки с днями над сеткой — общая для дня и недели.
const double kDayHeaderHeight = 30;

/// День над колонкой сетки одной строкой: «ПН 28».
///
/// Раньше день недели стоял над числом в кружке, и шапка съедала 56 точек
/// высоты ради двух коротких слов. В одну строку она занимает 30. Сегодняшнее
/// число подсвечено плашкой, день недели берётся из активной локали.
class DayHeaderCell extends StatelessWidget {
  const DayHeaderCell({
    super.key,
    required this.day,
    this.weekdayKey,
    this.numberKey,
  });

  final DateTime day;
  final Key? weekdayKey;
  final Key? numberKey;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final weekday = DateFormat.E(locale).format(day).toUpperCase();
    final today = DateTime.now();
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final colors = Theme.of(context).colorScheme;

    // Колонка недели на телефоне — около 50 точек: длинное сокращение дня
    // (THU, DONNERSTAG → DO.) ужимаем, а не обрезаем.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekday,
            key: weekdayKey,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: isToday ? colors.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: isToday
                ? BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Text(
              '${day.day}',
              key: numberKey,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isToday ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок единственной колонки дневного вида.
///
/// Геометрия совпадает с недельной шапкой: пустой участок слева выровнен по
/// временным меткам [TimeGrid], а дата остаётся по центру доступной ширины на
/// телефоне и десктопе.
class DayColumnHeader extends StatelessWidget {
  const DayColumnHeader({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Semantics(
      header: true,
      label: DateFormat.yMMMMEEEEd(locale).format(day),
      child: SizedBox(
        height: kDayHeaderHeight,
        child: Row(
          children: [
            const SizedBox(width: kGutterWidth),
            Expanded(
              child: Center(
                child: DayHeaderCell(
                  key: const ValueKey('day-column-cell'),
                  day: day,
                  weekdayKey: const ValueKey('day-column-weekday'),
                  numberKey: const ValueKey('day-column-number'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
