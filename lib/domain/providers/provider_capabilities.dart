import '../models/enums.dart';

/// Возможности конкретного адаптера (docs/architecture.md §6).
///
/// UI и use cases включают фичи по этим флагам, а НЕ по типу провайдера —
/// так ограничения адаптеров из матрицы ФТ §6
/// выражаются данными, а не ветвлениями `if (provider == ...)`.
class ProviderCapabilities {
  const ProviderCapabilities({
    required this.crud,
    required this.incrementalSync,
    required this.rsvp,
    required this.createNativeConference,
    required this.serverReminders,
    required this.attendees,
  });

  final bool crud;
  final bool incrementalSync;
  final bool rsvp;
  final bool createNativeConference;
  final bool serverReminders;
  final bool attendees;

  static const google = ProviderCapabilities(
    crud: true,
    incrementalSync: true,
    rsvp: true,
    createNativeConference: true, // Google Meet
    serverReminders: true,
    attendees: true,
  );

  static const graph = ProviderCapabilities(
    crud: true,
    incrementalSync: true,
    rsvp: true,
    createNativeConference: true, // Teams
    serverReminders: true,
    attendees: true,
  );

  static const caldav = ProviderCapabilities(
    crud: true,
    incrementalSync: true,
    rsvp: true, // Requires server-side CalDAV Scheduling.
    createNativeConference: false,
    serverReminders: true, // VALARM
    attendees: false, // FR-E9 — позже
  );

  static const ews = ProviderCapabilities(
    crud: true,
    incrementalSync: true,
    rsvp: true, // EWS Accept/Decline/TentativelyAcceptItem
    createNativeConference: false,
    serverReminders: true,
    attendees: true,
  );

  /// Возможности по типу провайдера — единая точка, чтобы UI гейтил операции
  /// по флагам, а не по `if (provider == ...)`.
  static ProviderCapabilities forProvider(ProviderType p) => switch (p) {
        ProviderType.google => google,
        ProviderType.graph => graph,
        ProviderType.caldav => caldav,
        ProviderType.ews => ews,
      };
}
