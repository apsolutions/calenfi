import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../app/providers.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/merged_event.dart';
import '../../domain/providers/calendar_provider.dart';
import '../calendar/calendar_state.dart';

/// Имя нативного `AppWidgetProvider` (android/.../AgendaWidgetProvider.kt).
const _kProvider = 'AgendaWidgetProvider';

/// Ключи в SharedPreferences `HomeWidgetPreferences`, которые читает нативный
/// `AgendaRemoteViewsService`.
const _kJson = 'agenda_json';
const _kDate = 'agenda_date';
const _kUpdated = 'agenda_updated';
const _kUpdatedEpoch = 'agenda_updated_epoch_ms';

/// Виджет может перелистывать дни нативно без запуска Flutter в пределах
/// сохранённого горизонта. Он совпадает с будущим окном CalDAV sync.
@visibleForTesting
const agendaWidgetFutureCacheDays = 366;

/// Сервис домашнего виджета «agenda на сегодня» (Android App Widget).
///
/// Flutter не рисует в системный виджет напрямую: мы кладём снимок повестки в
/// SharedPreferences через `home_widget`, а нативный RemoteViews-список его
/// отображает. См. [[calenfi-android-build]] и docs/architecture.md.
class AgendaWidgetService {
  const AgendaWidgetService._();

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Сериализует повестку дня и просит систему перерисовать виджет.
  static Future<void> push({
    required List<MergedEvent> events,
    required Map<String, int> calendarColors,
    required DateTime now,
  }) async {
    if (!_supported) return; // на desktop плагина нет — тихо выходим
    final items = _buildItems(events, calendarColors);
    await HomeWidget.saveWidgetData<String>(_kJson, jsonEncode(items));
    await HomeWidget.saveWidgetData<String>(_kDate, _formatDate(now));
    await HomeWidget.saveWidgetData<String>(_kUpdated, _formatTime(now));
    await HomeWidget.saveWidgetData<int>(
      _kUpdatedEpoch,
      now.millisecondsSinceEpoch,
    );
    await HomeWidget.updateWidget(androidName: _kProvider);
  }

  static List<Map<String, dynamic>> _buildItems(
    List<MergedEvent> events,
    Map<String, int> colors,
  ) {
    final list = events.map((m) => m.primary).toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) {
          return a.allDay ? -1 : 1; // весь день — сверху
        }
        return a.startUtc.compareTo(b.startUtc);
      });
    return [
      for (final e in list)
        {
          // Native RemoteViews фильтрует [start_ms, end_ms) по текущему
          // локальному дню и форматирует время уже в актуальной timezone.
          'start_ms': e.startUtc.millisecondsSinceEpoch,
          'end_ms': e.endUtc.millisecondsSinceEpoch,
          'all_day': e.allDay,
          // All-day границы — календарные даты, а не моменты времени. Native
          // сравнивает их с LocalDate, не применяя текущий UTC offset.
          if (e.allDay) 'start_date': _formatFloatingDate(e.startUtc),
          if (e.allDay) 'end_date': _formatFloatingDate(e.endUtc),
          'time': e.allDay ? 'весь день' : _formatTime(e.startUtc.toLocal()),
          'title': e.title.isEmpty ? '(без названия)' : e.title,
          'location': e.location ?? '',
          'sub': _sub(e),
          'color': colors[e.calendarId] ?? 0xFF8AB4F8,
          'cancelled': e.status == EventStatus.cancelled || e.deletedRemotely,
        },
    ];
  }

  static String _sub(CalendarEvent e) {
    final parts = <String>[];
    if (!e.allDay) {
      parts.add(
        '${_formatTime(e.startUtc.toLocal())}–${_formatTime(e.endUtc.toLocal())}',
      );
    }
    if ((e.location ?? '').trim().isNotEmpty) parts.add(e.location!.trim());
    return parts.join('  ·  ');
  }

  static String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _formatFloatingDate(DateTime d) {
    final utc = d.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static const _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', //
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  static const _weekdays = [
    'Понедельник', 'Вторник', 'Среда', 'Четверг', //
    'Пятница', 'Суббота', 'Воскресенье',
  ];

  static String _formatDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
}

/// Тестовая обёртка над schema 2 payload домашнего виджета.
@visibleForTesting
List<Map<String, dynamic>> buildAgendaWidgetItemsForTest(
  List<MergedEvent> events,
  Map<String, int> colors,
) => AgendaWidgetService._buildItems(events, colors);

/// Кэш: вчерашний буфер для смены timezone + сегодня + год вперёд.
/// Нативный widget выбирает из него только текущий локальный день.
final _agendaSnapshotRangeProvider = Provider<DateRange>((ref) {
  final n = DateTime.now();
  final start = DateTime(n.year, n.month, n.day - 1);
  final end = DateTime(
    n.year,
    n.month,
    n.day + agendaWidgetFutureCacheDays + 1,
  );
  return DateRange(start.toUtc(), end.toUtc());
});

/// Склеенные события для нативного дневного кэша, независимо от вида UI.
final agendaSnapshotProvider = StreamProvider<List<MergedEvent>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchMerged(
    ref.watch(_agendaSnapshotRangeProvider),
    combine: true,
  );
});

/// Держит домашний виджет в синхроне с локальной БД, пока приложение открыто.
///
/// Подписывается на повестку дня и палитру календарей; на любое изменение
/// перерисовывает виджет. Вызывать через `ref.watch` в корне приложения.
final agendaWidgetSyncProvider = Provider<void>((ref) {
  void pushNow() {
    final events = ref.read(agendaSnapshotProvider).valueOrNull;
    if (events == null) return;
    final colors = ref.read(calendarColorsProvider).valueOrNull ?? const {};
    AgendaWidgetService.push(
      events: events,
      calendarColors: colors,
      now: DateTime.now(),
    );
  }

  ref.listen(
    agendaSnapshotProvider,
    (_, _) => pushNow(),
    fireImmediately: true,
  );
  ref.listen(calendarColorsProvider, (_, _) => pushNow());
});
