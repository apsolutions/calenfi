import '../models/account.dart';
import '../models/calendar.dart';
import '../models/calendar_event.dart';
import '../models/enums.dart';
import 'provider_capabilities.dart';

/// Диапазон дат для выборки событий.
class DateRange {
  const DateRange(this.startUtc, this.endUtc);
  final DateTime startUtc;
  final DateTime endUtc;
}

/// Результат аутентификации адаптера.
class AuthResult {
  const AuthResult({required this.success, this.account, this.error});
  final bool success;
  final Account? account;
  final String? error;
}

/// Результат инкрементального синка (FR-S2).
class SyncResult {
  const SyncResult({
    required this.upserts,
    required this.deletedIds,
    required this.newSyncState,
    this.fullWindow,
  });

  final List<CalendarEvent> upserts;

  /// Провайдерные id удалённых/отменённых событий (tombstones, FR-V12).
  final List<String> deletedIds;

  /// Новое состояние синка для сохранения в Calendar.syncState.
  final String? newSyncState;

  /// Если задано — [upserts] это ПОЛНЫЙ актуальный набор событий за это окно,
  /// и движок может удалить локальные события в окне, которых тут нет (события,
  /// удалённые/перенесённые в источнике). См. SyncEngine._pullCalendar.
  final DateRange? fullWindow;
}

/// Единый интерфейс источника календарей (docs/architecture.md §6).
///
/// Конкретные адаптеры (Google, Graph, CalDAV, EWS) скрывают различия
/// протоколов. UI и ядро работают только с этим интерфейсом.
abstract class CalendarProvider {
  ProviderType get type;
  ProviderCapabilities get caps;

  // --- авторизация ---
  Future<AuthResult> authenticate(AccountConfig cfg);
  Future<void> refreshAuth(Account acc);

  // --- структура ---
  Future<List<Calendar>> listCalendars(Account acc);

  // --- чтение ---
  Future<List<CalendarEvent>> fetchEvents(
    Account acc,
    Calendar cal,
    DateRange range,
  );

  /// Инкрементальная синхронизация по сохранённому [syncState].
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? syncState,
  );

  // --- запись (CRUD) ---
  Future<CalendarEvent> createEvent(Account acc, Calendar cal, CalendarEvent e);

  /// Правка события. Для экземпляра повторяющейся серии [scope] решает, куда
  /// уходит изменение: в один экземпляр (исключение серии) или в мастер, то
  /// есть во все вхождения сразу.
  ///
  /// [originalStartUtc] — начало экземпляра ДО правки. По нему адаптер
  /// вычисляет сдвиг для мастера: перенос одного вхождения на 15 минут должен
  /// сдвинуть всю серию на 15 минут, а не переставить её на дату этого
  /// вхождения. Для [RecurrenceScope.thisOnly] не нужен.
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  });
  Future<void> deleteEvent(Account acc, CalendarEvent e, RecurrenceScope scope);

  // --- приглашения ---
  Future<void> respondToInvite(Account acc, CalendarEvent e, ResponseStatus r);
}
