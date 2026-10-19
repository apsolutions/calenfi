import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../data/repositories/event_repository.dart';
import '../../sync/sync_engine.dart';
import '../models/calendar_event.dart';
import '../models/enums.dart';

/// Действия пользователя над событиями (FR-E, FR-R).
///
/// Пишем оптимистично в локальную БД + кладём в Outbox; затем дёргаем синк,
/// который досылает изменения в источник (docs/architecture.md §7).
class EventActions {
  EventActions(this._events, this._sync);

  final EventRepository _events;
  final SyncEngine _sync;
  static const _uuid = Uuid();

  Future<void> create(CalendarEvent draft) async {
    final e = draft.id.isEmpty ? draft.withId(_uuid.v4()) : draft;
    await _events.saveAndEnqueue(e, 'create');
    _kickSync(e);
  }

  /// Правка события. Для вхождения повторяющейся серии [scope] решает, куда
  /// уйдёт изменение, а [original] (состояние ДО правки) даёт адаптеру время
  /// вхождения, по которому считается сдвиг серии.
  Future<void> update(
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    CalendarEvent? original,
  }) async {
    await _events.saveAndEnqueue(e, 'update', {
      'scope': scope.index,
      if (original != null)
        'origStart': original.startUtc.toUtc().millisecondsSinceEpoch,
    });
    _kickSync(e);
  }

  Future<void> delete(
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.all,
  }) async {
    await _events.saveAndEnqueue(e.copyWith(deletedRemotely: true), 'delete', {
      'scope': scope.index,
    });
    _kickSync(e);
  }

  Future<void> rsvp(CalendarEvent e, ResponseStatus r) async {
    await _events.saveAndEnqueue(e.copyWith(myResponse: r), 'rsvp', {
      'resp': r.index,
    });
    _kickSync(e);
  }

  /// Сразу пушим изменение — синкаем именно аккаунт этого события (не все).
  /// fire-and-forget: UI уже обновлён оптимистично.
  void _kickSync(CalendarEvent e) {
    final accId = e.source.accountId.isNotEmpty
        ? e.source.accountId
        : e.calendarId.split('|').first; // для только что созданного события
    if (accId.isNotEmpty) {
      _sync.syncAccountById(accId);
    } else {
      _sync.syncAll();
    }
  }
}

final eventActionsProvider = Provider<EventActions>((ref) {
  return EventActions(
    ref.watch(eventRepositoryProvider),
    ref.watch(syncEngineProvider),
  );
});
