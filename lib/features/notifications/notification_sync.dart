import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/merged_event.dart';
import '../../domain/providers/calendar_provider.dart';
import '../../services/notification_service.dart';
import '../calendar/calendar_state.dart';

/// Окно, на которое планируем напоминания (ближайшая неделя).
final _upcomingRangeProvider = Provider<DateRange>((ref) {
  final now = DateTime.now().toUtc();
  return DateRange(now, now.add(const Duration(days: 7)));
});

/// Ближайшие события (для планирования уведомлений, независимо от вида).
final upcomingEventsProvider = StreamProvider<List<MergedEvent>>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  return repo.watchMerged(ref.watch(_upcomingRangeProvider), combine: true);
});

/// Перепланирует локальные уведомления о начале встреч при любом изменении
/// ближайших событий или настроек календарей (FR-N). Watch'ить в корне App.
final notificationSyncProvider = Provider<void>((ref) {
  Future<void> reschedule() async {
    final events = ref.read(upcomingEventsProvider).valueOrNull;
    if (events == null) return;
    final cals = ref.read(calendarsListProvider).valueOrNull ?? const <Calendar>[];
    await NotificationService.instance.sync(
      events,
      {for (final c in cals) c.id: c},
      DateTime.now(),
    );
  }

  ref.listen(upcomingEventsProvider, (_, _) => reschedule(), fireImmediately: true);
  ref.listen(calendarsListProvider, (_, _) => reschedule());
});

/// Один раз перепланирует напоминания из текущего состояния базы — для
/// фоновой синхронизации, без запроса разрешения.
Future<void> rescheduleNotificationsOnce(ProviderContainer container) async {
  final events = await container.read(upcomingEventsProvider.future);
  final cals = await container.read(calendarsListProvider.future);
  await NotificationService.instance.sync(
    events,
    {for (final c in cals) c.id: c},
    DateTime.now(),
    askPermission: false,
  );
}
