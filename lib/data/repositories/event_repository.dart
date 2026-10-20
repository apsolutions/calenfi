import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:collection/collection.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/enums.dart';
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
        .watchEventsWithOwnersInRange(
          range.startUtc,
          range.endUtc,
          includeCancelled: includeCancelled,
        )
        .map((rows) {
          final domain = [for (final r in rows) _mapper.toDomain(r.event)];
          final ownership = <String, CopyOwnership>{
            for (final r in rows)
              r.calendar.id: CopyOwnership(
                accountEmail: r.account?.email ?? '',
                calendarName: r.calendar.name,
                isPrimary: r.calendar.isPrimary,
                readOnly: r.calendar.readOnly,
              ),
          };
          return _dedup.group(domain, combine: combine, ownership: ownership);
        });
  }

  /// Per-event delivery state, independent of unrelated account refreshes.
  Stream<({bool dirty, bool failed})?> watchWriteState(String id) => _db.customSelect(
    'SELECT e.dirty, COALESCE(MAX(o.retry_count), 0) AS retries '
    'FROM events e LEFT JOIN outbox o ON o.event_id = e.id '
    'WHERE e.id = ? GROUP BY e.id',
    variables: [Variable.withString(id)],
    readsFrom: {_db.events, _db.outbox},
  ).watch().map((rows) => rows.isEmpty ? null : (
    dirty: rows.single.read<bool>('dirty'),
    failed: rows.single.read<int>('retries') > 0,
  ));

  Future<CalendarEvent?> getById(String id) async {
    final row = await (_db.select(
      _db.events,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapper.toDomain(row);
  }

  /// References held by an editor/timer survive server-assigned identity changes.
  /// Keep exact getById semantics for callers checking whether the old row exists.
  Future<String> resolveEventId(String id) async {
    final row = await _db
        .customSelect(
          'SELECT a.event_id FROM event_id_aliases a JOIN events e ON e.id = a.event_id '
          'WHERE a.old_id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row?.read<String>('event_id') ?? id;
  }

  Future<CalendarEvent?> getByReference(String id) =>
      _db.transaction(() async => getById(await resolveEventId(id)));

  Future<void> _rememberIdentity(String oldId, String newId) async {
    await _db.customStatement(
      'UPDATE event_id_aliases SET event_id = ? WHERE event_id = ?',
      [newId, oldId],
    );
    await _db.customStatement(
      'INSERT OR REPLACE INTO event_id_aliases(old_id, event_id) VALUES (?, ?)',
      [oldId, newId],
    );
    await _db.customStatement(
      'DELETE FROM event_id_aliases WHERE NOT EXISTS '
      '(SELECT 1 FROM events WHERE events.id = event_id_aliases.event_id)',
    );
  }

  Future<void> _putLocal(CalendarEvent event, {required bool dirty}) =>
      _db.transaction(() async {
        final id = await resolveEventId(event.id);
        if (id != event.id) {
          final current = await getById(id);
          event = event.withLocalId(id).copyWith(source: current!.source);
        }
        await _db
            .into(_db.events)
            .insertOnConflictUpdate(_mapper.toCompanion(event, dirty: dirty));
      });

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
      // Read protection at commit time, not before the network await. Staged
      // edits have no outbox entry yet, but must also survive refresh.
      protectedIds = {
        ...protectedIds,
        ...(await pendingOutbox()).map((o) => o.eventId),
        ...(await (_db.select(
          _db.events,
        )..where((e) => e.dirty.equals(true))).get()).map((e) => e.id),
      };
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
  Future<void> putLocalDirty(CalendarEvent e) => _putLocal(e, dirty: true);

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
      await _rememberIdentity(oldId, updated.id);
      await (_db.update(_db.outbox)..where((o) => o.eventId.equals(oldId)))
          .write(OutboxCompanion(eventId: Value(updated.id)));
      await (_db.delete(_db.events)..where((e) => e.id.equals(oldId))).go();
    });
  }

  /// Записать событие как ЧИСТОЕ (dirty=false) — безусловно перезаписывает
  /// строку. Нужно для отмены отложенной правки: возвращаем исходное состояние
  /// (совпадает с облаком, т.к. на сервер ещё не отправляли), чтобы синк его не
  /// пушил и не откатывал обратно.
  Future<void> putLocalClean(CalendarEvent e) => _putLocal(e, dirty: false);

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
  ]) => _db.transaction(() async {
    eventId = await resolveEventId(eventId);
    final row = await (_db.select(
      _db.events,
    )..where((e) => e.id.equals(eventId))).getSingleOrNull();
    return _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            op: op,
            eventId: eventId,
            // Each operation owns its content and recurrence scope. Reading the
            // latest row for every queued operation can apply an instance edit to
            // an entire series, or upload a staged (not yet committed) drag.
            payloadJson: Value(
              jsonEncode({...payload, if (row != null) 'event': row.toJson()}),
            ),
            createdAt: DateTime.now().toUtc(),
          ),
        );
  });

  /// The local edit and durable outgoing operation must become visible together.
  Future<void> saveAndEnqueue(
    CalendarEvent event,
    String op, [
    Map<String, dynamic> payload = const {},
  ]) => _db.transaction(() async {
    await putLocalDirty(event);
    await enqueue(op, event.id, payload);
  });

  /// Re-read after preflight and save atomically: an edit or deletion may have
  /// happened while the server capabilities were being checked.
  Future<int> queueInviteResponse(
    CalendarEvent reference,
    ResponseStatus response,
  ) => _db.transaction(() async {
    final current = await getByReference(reference.id);
    if (current == null || current.isCancelled) {
      throw StateError('Приглашение удалено или отменено');
    }
    await putLocalDirty(current.copyWith(myResponse: response));
    return enqueue('rsvp', current.id, {
      'resp': response.index,
      'previousResponse': current.myResponse.index,
    });
  });

  CalendarEvent eventForOperation(OutboxData item, CalendarEvent current) {
    final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final snapshot = payload['event'];
    // Old queues remain readable after an upgrade.
    if (snapshot is! Map<String, dynamic>) return current;
    return _mapper
        .toDomain(Event.fromJson(snapshot))
        .withLocalId(current.id)
        .copyWith(source: current.source);
  }

  Map<String, Object?> _content(CalendarEvent event) => {
    for (final entry in _mapper.toCompanion(event).toColumns(false).entries)
      if (!const {
        'id',
        'provider_event_id',
        'etag',
        'dirty',
      }.contains(entry.key))
        entry.key: (entry.value as Variable).value,
  };

  /// Acknowledge exactly one uploaded version, retaining later committed or
  /// staged edits. Identity/ETag and the remaining queue move atomically.
  Future<void> acknowledgeWrite(
    OutboxData item,
    CalendarEvent sent,
    CalendarEvent saved,
  ) => _db.transaction(() async {
    final current = await getById(sent.id);
    if (current != null) {
      final remaining =
          await (_db.select(_db.outbox)..where(
                (o) =>
                    o.eventId.equals(sent.id) & o.id.isBiggerThanValue(item.id),
              ))
              .get();
      final newer =
          remaining.isNotEmpty ||
          !const DeepCollectionEquality().equals(
            _content(current),
            _content(sent),
          );
      final local = newer
          ? current.withLocalId(saved.id).copyWith(source: saved.source)
          : saved;
      await _db
          .into(_db.events)
          .insertOnConflictUpdate(_mapper.toCompanion(local, dirty: newer));
      if (sent.id != saved.id) {
        await _rememberIdentity(sent.id, saved.id);
        await (_db.update(_db.outbox)..where((o) => o.eventId.equals(sent.id)))
            .write(OutboxCompanion(eventId: Value(saved.id)));
        await hardDelete(sent.id);
      }
    }
    await removeOutbox(item.id);
  });

  /// A reply rejected before it can be sent is not a retryable write. Restore
  /// its optimistic response when still current, without overwriting later edits.
  /// The following pull restores server fields for legacy jobs without a baseline.
  Future<void> rejectUnsupportedReply(
    OutboxData item,
    CalendarEvent sent,
  ) async {
    final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final previous = payload['previousResponse'];
    final response =
        previous is int &&
            previous >= 0 &&
            previous < ResponseStatus.values.length
        ? ResponseStatus.values[previous]
        : ResponseStatus.needsAction;
    await acknowledgeWrite(item, sent, sent.copyWith(myResponse: response));
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
