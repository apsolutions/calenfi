import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final wide = MediaQuery.of(context).size.width >= 600;

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

/// Заголовок единственной колонки дневного вида.
///
/// Геометрия совпадает с недельной шапкой: пустой участок слева выровнен по
/// временным меткам [TimeGrid], а дата остаётся по центру доступной ширины на
/// телефоне и десктопе. День недели берётся из активной локали приложения.
class DayColumnHeader extends StatelessWidget {
  const DayColumnHeader({super.key, required this.day});

  final DateTime day;

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

    return Semantics(
      header: true,
      label: DateFormat.yMMMMEEEEd(locale).format(day),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: kGutterWidth),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    key: const ValueKey('day-column-weekday'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday ? colors.primary : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isToday
                        ? colors.primary
                        : Colors.transparent,
                    child: Text(
                      '${day.day}',
                      key: const ValueKey('day-column-number'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday ? Colors.white : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
