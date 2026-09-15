import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/merged_event.dart';
import '../../domain/providers/calendar_provider.dart';
import '../../services/dedup_engine.dart';
import '../local/db/database.dart';
import '../mappers/event_mapper.dart';

/// Доступ к событиям в локальной БД + дедуп для UI (docs/architecture.md §3/§10).
class EventRepository {
  EventRepository(
    this._db, {
    this._mapper = const EventMapper(),
    this._dedup = const DedupEngine(),
  });

  final AppDatabase _db;
  final EventMapper _mapper;
  final DedupEngine _dedup;

  /// Реактивный поток склеенных событий в диапазоне (FR-V4, FR-D1).
  Stream<List<MergedEvent>> watchMerged(
    DateRange range, {
    bool includeCancelled = false,
    bool combine = true,
  }) {
    return _db
        .watchEventsInRange(
          range.startUtc,
          range.endUtc,
          includeCancelled: includeCancelled,
        )
        .map((rows) {
          final domain = rows.map(_mapper.toDomain).toList();
          return _dedup.group(domain, combine: combine);
        });
  }

  Future<CalendarEvent?> getById(String id) async {
    final row = await (_db.select(
      _db.events,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapper.toDomain(row);
  }

  /// Удаляет «призраки-дубли»: локальные UUID-копии (id без ':'), оставшиеся
  /// `dirty` после НЕудавшейся реконсиляции создания, когда на сервере уже есть
  /// их двойник — реальный synced-event с тем же календарём и временем (id с
  /// ':', не dirty). Pending-создание с оставшимся Outbox защищено явно: после
  /// 412 серверный двойник уже может существовать. Возвращает число удалённых.
  Future<int> cleanupGhostDuplicates() {
    return _db.customUpdate(
      "DELETE FROM events WHERE instr(id, ':') = 0 AND dirty = 1 "
      "AND NOT EXISTS (SELECT 1 FROM outbox o WHERE o.event_id = events.id) "
      "AND EXISTS ("
      "SELECT 1 FROM events t WHERE t.calendar_id = events.calendar_id "
      "AND t.start_utc = events.start_utc AND t.end_utc = events.end_utc "
      "AND instr(t.id, ':') > 0 AND t.dirty = 0 AND t.id <> events.id)",
      updates: {_db.events},
    );
  }

  /// Удаляет локальных «мастеров» повторяющихся серий, оставшихся после
  /// создания серии.
  ///
  /// Провайдер на create возвращает МАСТЕР (id без суффикса вхождения), но
  /// отдаёт при чтении только развёрнутые вхождения: Google — `singleEvents`,
  /// Graph/EWS — calendarView, CalDAV разворачиваем мы сами. Такая строка
  /// остаётся `dirty`, переживает reconcile и рисуется в сетке как ещё одна
  /// встреча рядом с первым вхождением; хуже того, перетаскивание попадает
  /// именно по ней и правит СЕРИЮ вместо вхождения.
  ///
  /// Признак призрака — не сам факт RRULE (у такой строки он часто пуст), а
  /// наличие в базе вхождений, ссылающихся на её provider-id. Записи с живым
  /// заданием Outbox не трогаем: их правка ещё не доехала.
  Future<int> cleanupOrphanSeriesMasters() {
    return _db.customUpdate(
      'DELETE FROM events WHERE dirty = 1 AND recurrence_id IS NULL '
      'AND provider_event_id IS NOT NULL '
      "AND NOT EXISTS (SELECT 1 FROM outbox o WHERE o.event_id = events.id) "
      'AND EXISTS ('
      'SELECT 1 FROM events i WHERE i.account_id = events.account_id '
      'AND i.recurrence_id = events.provider_event_id AND i.id <> events.id)',
      updates: {_db.events},
    );
  }

  /// Поиск событий по названию, участнику (email/имя внутри attendees_json) или
  /// id. Возвращает до [limit] совпадений; сортировку (дата/релевантность) делает
  /// UI. Wildcard-символы из запроса вычищаем, чтобы `%`/`_` не ломали LIKE.
  Future<List<CalendarEvent>> search(String query, {int limit = 50}) async {
    final safe = query.trim().replaceAll('%', '').replaceAll('_', '');
    if (safe.isEmpty) return const [];
    final like = '%$safe%';
    final rows =
        await (_db.select(_db.events)
              ..where(
                (e) =>
                    (e.title.like(like) |
                        e.id.like(like) |
                        e.attendeesJson.like(like)) &
                    e.deletedRemotely.equals(false),
              )
              ..limit(limit))
            .get();
    return rows.map(_mapper.toDomain).toList();
  }

  /// Upsert из синка (FR-S2). Помечает не-dirty (пришло из источника).
  Future<void> upsertAll(List<CalendarEvent> events) async {
    await _db.batch((b) {
      for (final e in events) {
        b.insert(
          _db.events,
          _mapper.toCompanion(e),
          onConflict: DoUpdate((_) => _mapper.toCompanion(e)),
        );
      }
    });
  }

  /// Атомарно применяет результат синка одного календаря: upsert новых,
  /// tombstone удалённых и сверка окна — **в одной транзакции**, чтобы
  /// реактивный поток не показывал промежуточное состояние (события не мигали).
  Future<void> applyPull({
    required String calendarId,
    required List<CalendarEvent> upserts,
    required List<String> deletedProviderIds,
    Set<String> protectedIds = const {},
    DateTime? windowStart,
    DateTime? windowEnd,
    Set<String> keepIds = const {},
  }) async {
    await _db.transaction(() async {
      if (upserts.isNotEmpty) {
        // Пока для id остаётся задание Outbox, локальное содержимое — источник
        // истины: push мог получить 412/timeout, а remote upsert иначе тихо
        // заменил бы правку пользователя clean-версией. Concurrency metadata
        // при этом освежаем ниже. Если локальной строки ещё нет, remote событие
        // всё равно нужно вставить.
        final existingProtectedIds = <String>{};
        if (protectedIds.isNotEmpty) {
          final rows = await (_db.select(
            _db.events,
          )..where((e) => e.id.isIn(protectedIds.toList()))).get();
          existingProtectedIds.addAll(rows.map((e) => e.id));
        }
        final remoteUpserts = <CalendarEvent>[];
        for (final e in upserts) {
          if (!existingProtectedIds.contains(e.id)) {
            remoteUpserts.add(e);
            continue;
          }

          // Содержимое/dirty/deletedRemotely оставляем локальными, но ETag и
          // реальный href обязаны освежиться: после 412 именно remote ETag
          // позволит следующему retry отправить локальную правку с актуальным
          // If-Match вместо пяти одинаковых конфликтов.
          final etag = e.source.etag;
          final providerEventId = e.source.providerEventId;
          if (etag != null || providerEventId != null) {
            await (_db.update(
              _db.events,
            )..where((row) => row.id.equals(e.id))).write(
              EventsCompanion(
                etag: etag == null ? const Value.absent() : Value(etag),
                providerEventId: providerEventId == null
                    ? const Value.absent()
                    : Value(providerEventId),
              ),
            );
          }
        }
        await _db.batch((b) {
          for (final e in remoteUpserts) {
            b.insert(
              _db.events,
              _mapper.toCompanion(e),
              onConflict: DoUpdate((_) => _mapper.toCompanion(e)),
            );
          }
        });
      }
      if (deletedProviderIds.isNotEmpty) {
        await (_db.update(_db.events)..where((e) {
              var predicate =
                  e.calendarId.equals(calendarId) &
                  e.providerEventId.isIn(deletedProviderIds);
              if (protectedIds.isNotEmpty) {
                predicate = predicate & e.id.isNotIn(protectedIds.toList());
              }
              return predicate;
            }))
            .write(const EventsCompanion(deletedRemotely: Value(true)));
      }
      if (windowStart != null && windowEnd != null) {
        final q = _db.delete(_db.events)
          ..where(
            (e) =>
                e.calendarId.equals(calendarId) &
                e.dirty.equals(false) &
                e.startUtc.isBiggerOrEqualValue(windowStart) &
                e.startUtc.isSmallerThanValue(windowEnd),
          );
        final retainedIds = {...keepIds, ...protectedIds};
        if (retainedIds.isNotEmpty) {
          q.where((e) => e.id.isNotIn(retainedIds.toList()));
        }
        await q.go();
      }
    });
  }

  /// Локальная (оптимистичная) запись правки пользователя (FR-S4).
  Future<void> putLocalDirty(CalendarEvent e) => _db
      .into(_db.events)
      .insertOnConflictUpdate(_mapper.toCompanion(e, dirty: true));

  /// Атомарно меняет локальный id после create/update в провайдере
  /// и перенацеливает ВСЮ оставшуюся цепочку Outbox. Без этого
  /// второй `update`/последующий `delete` всё ещё ссылался бы на
  /// старый id и был бы ошибочно удалён как «сирота».
  Future<void> rekeyLocalDirtyAndOutbox(
    String oldId,
    CalendarEvent updated,
  ) async {
    await _db.transaction(() async {
      await _db
          .into(_db.events)
          .insertOnConflictUpdate(_mapper.toCompanion(updated, dirty: true));
      if (oldId == updated.id) return;
      await (_db.update(_db.outbox)..where((o) => o.eventId.equals(oldId)))
          .write(OutboxCompanion(eventId: Value(updated.id)));
      await (_db.delete(_db.events)..where((e) => e.id.equals(oldId))).go();
    });
  }

  /// Записать событие как ЧИСТОЕ (dirty=false) — безусловно перезаписывает
  /// строку. Нужно для отмены отложенной правки: возвращаем исходное состояние
  /// (совпадает с облаком, т.к. на сервер ещё не отправляли), чтобы синк его не
  /// пушил и не откатывал обратно.
  Future<void> putLocalClean(CalendarEvent e) => _db
      .into(_db.events)
      .insertOnConflictUpdate(_mapper.toCompanion(e, dirty: false));

  /// Пометить события как удалённые в источнике (tombstone, FR-V12).
  Future<void> markDeleted(String calendarId, List<String> providerIds) async {
    if (providerIds.isEmpty) return;
    await (_db.update(_db.events)..where(
          (e) =>
              e.calendarId.equals(calendarId) &
              e.providerEventId.isIn(providerIds),
        ))
        .write(const EventsCompanion(deletedRemotely: Value(true)));
  }

  Future<void> hardDelete(String id) =>
      (_db.delete(_db.events)..where((e) => e.id.equals(id))).go();

  /// Сверка окна: удаляет события календаря в [startUtc, endUtc), которых нет в
  /// [keepIds] (т.е. удалённые/перенесённые в источнике). НЕ трогает локальные
  /// несинхронизированные правки (dirty). Возвращает число удалённых.
  Future<int> reconcileWindow(
    String calendarId,
    DateTime startUtc,
    DateTime endUtc,
    Set<String> keepIds,
  ) {
    final q = _db.delete(_db.events)
      ..where(
        (e) =>
            e.calendarId.equals(calendarId) &
            e.dirty.equals(false) &
            e.startUtc.isBiggerOrEqualValue(startUtc) &
            e.startUtc.isSmallerThanValue(endUtc),
      );
    if (keepIds.isNotEmpty) {
      q.where((e) => e.id.isNotIn(keepIds.toList()));
    }
    return q.go();
  }

  // --- Outbox (FR-S6) ---

  /// Ставит задание в Outbox и возвращает его id.
  Future<int> enqueue(
    String op,
    String eventId, [
    Map<String, dynamic> payload = const {},
  ]) {
    return _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            op: op,
            eventId: eventId,
            payloadJson: Value(jsonEncode(payload)),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<List<OutboxData>> pendingOutbox() => (_db.select(
    _db.outbox,
  )..orderBy([(o) => OrderingTerm(expression: o.id)])).get();

  Future<void> removeOutbox(int id) =>
      (_db.delete(_db.outbox)..where((o) => o.id.equals(id))).go();

  Future<void> bumpRetry(int id, int retry) =>
      (_db.update(_db.outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(retryCount: Value(retry)),
      );

  /// Сбрасывает счётчик попыток у ВСЕХ заданий Outbox — вызывается при РУЧНОМ
  /// синке, чтобы задания, «сгоревшие» из-за временной проблемы (протухший
  /// пароль и т.п.), получили новый шанс после её устранения. Фоновый синк это
  /// НЕ делает — иначе он бы вечно долбил заведомо битые задания.
  Future<void> resetOutboxRetries() =>
      _db.update(_db.outbox).write(const OutboxCompanion(retryCount: Value(0)));
}
