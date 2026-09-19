import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/merged_event.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_state.dart';
import 'event_details_sheet.dart';

/// Месячный вид (FR-V1): сетка 6×7, в каждой ячейке — день и чипсы событий.
class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusedDateProvider);
    final gridStart = monthGridStart(focused);
    final days = List.generate(42, (i) => gridStart.add(Duration(days: i)));
    final eventsAsync = ref.watch(mergedEventsProvider);
    final colorsAsync = ref.watch(calendarColorsProvider);
    final colors = colorsAsync.value ?? const {};

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(L10n.of(context).uiError('$e'))),
      data: (events) {
        final byDay = <String, List<MergedEvent>>{};
        for (final e in events) {
          final d = e.primary.startUtc.toLocal();
          byDay.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(e);
        }
        return Column(
          children: [
            _weekdayHeader(context),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.85,
                ),
                itemCount: 42,
                itemBuilder: (context, i) {
                  final d = days[i];
                  final key = '${d.year}-${d.month}-${d.day}';
                  final dayEvents = (byDay[key] ?? [])
                    ..sort((a, b) => a.primary.startUtc.compareTo(b.primary.startUtc));
                  return _MonthCell(
                    day: d,
                    inMonth: d.month == focused.month,
                    events: dayEvents,
                    colors: colors,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _weekdayHeader(BuildContext context) {
    const ru = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (final d in ru)
            Expanded(
              child: Center(
                  child: Text(d,
                      style: const TextStyle(fontSize: 11, color: Colors.grey))),
            ),
        ],
      ),
    );
  }
}

class _MonthCell extends ConsumerWidget {
  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.events,
    required this.colors,
  });

  final DateTime day;
  final bool inMonth;
  final List<MergedEvent> events;
  final Map<String, int> colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    // Тап по свободному месту ячейки — это выбор дня. На телефоне в месячной
    // сетке видно только пару чипсов, поэтому там сразу открываем дневной вид;
    // на широком экране месяц информативен, и вид не меняем.
    final narrow = MediaQuery.of(context).size.width < 600;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ref.read(focusedDateProvider.notifier).state =
            DateTime(day.year, day.month, day.day);
        if (narrow) {
          ref.read(viewModeProvider.notifier).state = CalendarViewMode.day;
        }
      },
      child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        // Считаем, сколько чипсов реально влезает по высоте ячейки, чтобы не
        // ловить полосатый RenderFlex overflow на мелких ячейках телефона.
        child: LayoutBuilder(
          builder: (context, c) {
            const headerH = 24.0; // кружок дня + отступ
            const chipH = 15.0; // высота одного чипса (текст+паддинг+маргин)
            final avail = c.maxHeight - headerH;
            var fit = avail <= 0 ? 0 : (avail ~/ chipH);
            // если событий больше, чем помещается, резервируем строку под «+N»
            final showMore = events.length > fit;
            final visible = showMore && fit > 0 ? fit - 1 : fit;
            final shown = events.take(visible < 0 ? 0 : visible).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    child: Text('${day.day}',
                        style: TextStyle(
                            fontSize: 11,
                            color: isToday
                                ? Colors.white
                                : (inMonth ? null : Colors.grey))),
                  ),
                ),
                const SizedBox(height: 2),
                for (final e in shown) _chip(context, e),
                if (showMore)
                  Text('+${events.length - shown.length}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _chip(BuildContext context, MergedEvent e) {
    final color = Color(
        e.primary.colorOverride ?? colors[e.primary.calendarId] ?? 0xFF888888);
    final cancelled = e.primary.isCancelled;
    return GestureDetector(
      onTap: () => showEventDetails(context, e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          e.primary.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 9,
              decoration: cancelled ? TextDecoration.lineThrough : null),
        ),
      ),
    );
  }
}
