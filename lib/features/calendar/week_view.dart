import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/merged_event.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_state.dart';
import 'day_view.dart';
import 'time_grid.dart';

/// Недельный вид (FR-V1).
class WeekView extends ConsumerWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusedDateProvider);
    final start = weekStart(focused);
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final eventsAsync = ref.watch(mergedEventsProvider);
    final colorsAsync = ref.watch(calendarColorsProvider);

    return Column(
      children: [
        _WeekHeader(days: days),
        const Divider(height: 1),
        Expanded(
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(L10n.of(context).uiError('$e'))),
            data: (events) => TimeGrid(
              days: days,
              events: events,
              colors: colorsAsync.value ?? const {},
            ),
          ),
        ),
      ],
    );
  }
}

/// Шапка недели: семь дней одной строкой, «ПН 28 · ВТ 29 · …».
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.days});
  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kDayHeaderHeight,
      child: Row(
        children: [
          const SizedBox(width: kGutterWidth),
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Center(child: DayHeaderCell(day: d)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Утилита: события, начинающиеся в указанный день (по локальному времени).
List<MergedEvent> eventsForDay(List<MergedEvent> all, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return all.where((e) {
    final s = e.primary.startUtc.toLocal();
    return !s.isBefore(dayStart) && s.isBefore(dayEnd);
  }).toList()
    ..sort((a, b) => a.primary.startUtc.compareTo(b.primary.startUtc));
}
