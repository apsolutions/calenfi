import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/merged_event.dart';
import '../../services/dedup_engine.dart';
import '../local/db/database.dart';

/// Одна личная заметка к встрече.
class MeetingNote {
  const MeetingNote({
    required this.id,
    required this.keys,
    required this.title,
    required this.startUtc,
    required this.body,
    required this.updatedUtc,
    this.taskId,
    this.taskUpdated,
    this.dirty = true,
    this.deleted = false,
  });

  final String id;

  /// По каким ключам узнаём встречу (см. [NotesRepository.keysFor]).
  final Set<String> keys;

  /// Название и начало встречи — для заголовка задачи в Google Tasks.
  final String title;
  final DateTime startUtc;
  final String body;

  /// Время последней правки (локальной или пришедшей из Google Tasks).
  final DateTime updatedUtc;

  /// Задача в Google Tasks, если заметка уже туда отправлена, и её `updated`.
  final String? taskId;
  final String? taskUpdated;

  /// Есть правка, которую ещё не отправили в Google Tasks.
  final bool dirty;

  /// Удалена локально, удаление ещё не отправлено.
  final bool deleted;
}

/// Личные заметки к встречам: повестка, что спросить, что подготовить.
///
/// Заметка никогда не попадает в событие у провайдера и участникам не видна:
/// она лежит в отдельной таблице, которую адаптеры календарей не трогают.
/// Между устройствами её переносит [NotesSync] через приватный список Google
/// Tasks пользователя.
///
/// Встречу узнаём по нескольким ключам сразу, чтобы заметка не терялась:
///  • id каждой копии склейки (`id:`) — переживает перенос встречи;
///  • UID провайдера + начало (`uid:`);
///  • название + время (`key:`) — запасной и общий для всех устройств.
class NotesRepository {
  NotesRepository(this._db);
  final AppDatabase _db;
  bool _migrated = false;

  static List<String> keysFor(MergedEvent m) => {
        for (final e in m.sources) ..._keysOf(e),
        ..._keysOf(m.primary),
      }.toList();

  static Iterable<String> _keysOf(CalendarEvent e) sync* {
    yield 'id:${e.id}';
    final uid = e.providerUid;
    final start = e.startUtc.toUtc().millisecondsSinceEpoch;
    if (uid != null && uid.isNotEmpty) yield 'uid:$uid|$start';
    final end = e.endUtc.toUtc().millisecondsSinceEpoch;
    yield 'key:${DedupEngine.normalizeTitle(e.title)}|$start|$end';
  }

  /// «Заметки изменились» — на весь процесс: карточка, сетка и синхронизация
  /// держат разные экземпляры репозитория.
  static final _changes = StreamController<void>.broadcast();

  /// Правка сделана здесь (а не пришла из Google Tasks): пора отправлять.
  static final _localEdits = StreamController<void>.broadcast();
  static Stream<void> get localEdits => _localEdits.stream;

  // ───────────────────────── чтение ─────────────────────────

  Future<List<MeetingNote>> all({bool includeDeleted = false}) async {
    await _migrateOnce();
    final rows = await _db
        .customSelect(
          'SELECT * FROM meeting_notes'
          '${includeDeleted ? '' : ' WHERE deleted = 0'}',
          readsFrom: const {},
        )
        .get();
    return [for (final r in rows) _fromRow(r)];
  }

  MeetingNote _fromRow(QueryRow r) => MeetingNote(
        id: r.read<String>('id'),
        keys: r.read<String>('note_keys').split('\n').where((k) => k.isNotEmpty).toSet(),
        title: r.read<String>('title'),
        startUtc: DateTime.fromMillisecondsSinceEpoch(r.read<int>('start_utc'), isUtc: true),
        body: r.read<String>('body'),
        updatedUtc: DateTime.fromMillisecondsSinceEpoch(r.read<int>('updated_utc'), isUtc: true),
        taskId: r.readNullable<String>('task_id'),
        taskUpdated: r.readNullable<String>('task_updated'),
        dirty: r.read<int>('dirty') != 0,
        deleted: r.read<int>('deleted') != 0,
      );

  Future<MeetingNote?> find(MergedEvent m) async {
    final keys = keysFor(m).toSet();
    MeetingNote? best;
    for (final n in await all()) {
      if (!n.keys.any(keys.contains)) continue;
      if (best == null || n.updatedUtc.isAfter(best.updatedUtc)) best = n;
    }
    return best;
  }

  /// Текст заметки к встрече или null.
  Future<String?> read(MergedEvent m) async => (await find(m))?.body;

  // ───────────────────────── запись ─────────────────────────

  /// Сохранить заметку; пустой текст удаляет её.
  Future<void> write(MergedEvent m, String body) async {
    final text = body.trimRight();
    final existing = await find(m);
    final now = DateTime.now().toUtc();
    if (text.trim().isEmpty) {
      if (existing == null) return;
      if (existing.taskId == null) {
        await _delete(existing.id);
      } else {
        await save(MeetingNote(
          id: existing.id,
          keys: existing.keys,
          title: existing.title,
          startUtc: existing.startUtc,
          body: '',
          updatedUtc: now,
          taskId: existing.taskId,
          taskUpdated: existing.taskUpdated,
          deleted: true,
        ));
      }
    } else {
      await save(MeetingNote(
        id: existing?.id ?? const Uuid().v4(),
        keys: {...?existing?.keys, ...keysFor(m)},
        title: m.primary.title,
        startUtc: m.primary.startUtc.toUtc(),
        body: text,
        updatedUtc: now,
        taskId: existing?.taskId,
        taskUpdated: existing?.taskUpdated,
      ));
    }
    _localEdits.add(null);
  }

  /// Записать заметку как есть (для синхронизации).
  Future<void> save(MeetingNote n) async {
    await _migrateOnce();
    await _db.customStatement(
      'INSERT INTO meeting_notes(id, note_keys, title, start_utc, body, updated_utc, '
      'task_id, task_updated, dirty, deleted) VALUES (?,?,?,?,?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET note_keys = excluded.note_keys, '
      'title = excluded.title, start_utc = excluded.start_utc, body = excluded.body, '
      'updated_utc = excluded.updated_utc, task_id = excluded.task_id, '
      'task_updated = excluded.task_updated, dirty = excluded.dirty, '
      'deleted = excluded.deleted',
      [
        n.id,
        n.keys.join('\n'),
        n.title,
        n.startUtc.millisecondsSinceEpoch,
        n.body,
        n.updatedUtc.millisecondsSinceEpoch,
        n.taskId,
        n.taskUpdated,
        n.dirty ? 1 : 0,
        n.deleted ? 1 : 0,
      ],
    );
    _changes.add(null);
  }

  Future<void> remove(String id) => _delete(id);

  Future<void> _delete(String id) async {
    await _db.customStatement('DELETE FROM meeting_notes WHERE id = ?', [id]);
    _changes.add(null);
  }

  // ───────────────────────── значок в сетке ─────────────────────────

  /// Все ключи, у которых есть заметка — для значка на блоке встречи.
  Stream<Set<String>> watchKeys() async* {
    yield await _allKeys();
    await for (final _ in _changes.stream) {
      yield await _allKeys();
    }
  }

  Future<Set<String>> _allKeys() async =>
      {for (final n in await all()) ...n.keys};

  /// Есть ли заметка у встречи, по набору ключей из [watchKeys].
  static bool hasNote(MergedEvent m, Set<String> keys) =>
      keys.isNotEmpty && keysFor(m).any(keys.contains);

  // ───────────────────────── перенос из 0.3.18 ─────────────────────────

  /// В 0.3.18 заметка лежала строками «ключ → текст» в `event_notes`.
  /// Один раз собираем их в заметки: строки с одинаковым текстом и временем
  /// записывались вместе — это одна заметка.
  Future<void> _migrateOnce() async {
    if (_migrated) return;
    _migrated = true;
    final has = await _db
        .customSelect('SELECT COUNT(*) AS c FROM meeting_notes', readsFrom: const {})
        .getSingle();
    if (has.read<int>('c') > 0) return;
    final rows = await _db
        .customSelect('SELECT note_key, body, updated_utc FROM event_notes', readsFrom: const {})
        .get();
    final groups = <String, List<QueryRow>>{};
    for (final r in rows) {
      (groups['${r.read<int>('updated_utc')}\u0000${r.read<String>('body')}'] ??= []).add(r);
    }
    for (final g in groups.values) {
      final keys = {for (final r in g) r.read<String>('note_key')};
      var title = '';
      var start = 0;
      for (final k in keys) {
        if (!k.startsWith('key:')) continue;
        final parts = k.substring(4).split('|');
        if (parts.length >= 3) {
          title = parts.sublist(0, parts.length - 2).join('|');
          start = int.tryParse(parts[parts.length - 2]) ?? 0;
        }
      }
      await save(MeetingNote(
        id: const Uuid().v4(),
        keys: keys,
        title: title,
        startUtc: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
        body: g.first.read<String>('body'),
        updatedUtc: DateTime.fromMillisecondsSinceEpoch(g.first.read<int>('updated_utc'), isUtc: true),
      ));
    }
  }
}
