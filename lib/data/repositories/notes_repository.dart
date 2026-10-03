import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/merged_event.dart';
import '../../services/dedup_engine.dart';
import '../local/db/database.dart';

/// Личные заметки к встречам: повестка, что спросить, что подготовить.
///
/// Заметка живёт только в локальной базе Calenfi и никуда не отправляется:
/// ни в событие у провайдера, ни участникам. Синхронизация её не трогает —
/// таблица отдельная, а не колонка события, которую pull перезаписывает.
///
/// Встречу узнаём по нескольким ключам сразу, чтобы заметка не терялась:
///  • id каждой копии склейки (`id:`) — переживает перенос встречи;
///  • iCalendar UID + начало (`uid:`) — одна и та же встреча в разных
///    календарях и после переподключения аккаунта;
///  • название + время (`key:`) — запасной, если у провайдера нет UID.
/// Запись идёт под все ключи; при чтении берётся самая свежая.
class NotesRepository {
  NotesRepository(this._db);
  final AppDatabase _db;

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

  String _placeholders(int n) => List.filled(n, '?').join(',');

  /// Текст заметки к встрече или null.
  Future<String?> read(MergedEvent m) async {
    final keys = keysFor(m);
    final rows = await _db.customSelect(
      'SELECT body FROM event_notes WHERE note_key IN (${_placeholders(keys.length)}) '
      'ORDER BY updated_utc DESC LIMIT 1',
      variables: [for (final k in keys) Variable.withString(k)],
      readsFrom: const {},
    ).get();
    return rows.isEmpty ? null : rows.single.read<String>('body');
  }

  /// Сохранить заметку; пустой текст удаляет её.
  Future<void> write(MergedEvent m, String body) async {
    final keys = keysFor(m);
    final text = body.trimRight();
    await _db.transaction(() async {
      if (text.trim().isEmpty) {
        await _db.customStatement(
          'DELETE FROM event_notes WHERE note_key IN (${_placeholders(keys.length)})',
          keys,
        );
      } else {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        for (final k in keys) {
          await _db.customStatement(
            'INSERT INTO event_notes(note_key, body, updated_utc) VALUES (?, ?, ?) '
            'ON CONFLICT(note_key) DO UPDATE SET body = excluded.body, '
            'updated_utc = excluded.updated_utc',
            [k, text, now],
          );
        }
      }
    });
    _changed();
  }

  /// Все ключи, у которых есть заметка — для значка на блоке встречи.
  Stream<Set<String>> watchKeys() async* {
    yield await _allKeys();
    await for (final _ in _changes.stream) {
      yield await _allKeys();
    }
  }

  Future<Set<String>> _allKeys() async {
    final rows = await _db
        .customSelect('SELECT note_key FROM event_notes', readsFrom: const {})
        .get();
    return {for (final r in rows) r.read<String>('note_key')};
  }

  /// «Заметки изменились» — на весь процесс: экран карточки и сетка
  /// держат разные экземпляры репозитория.
  static final _changes = StreamController<void>.broadcast();
  void _changed() => _changes.add(null);

  /// Есть ли заметка у встречи, по набору ключей из [watchKeys].
  static bool hasNote(MergedEvent m, Set<String> keys) =>
      keys.isNotEmpty && keysFor(m).any(keys.contains);
}
