import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../domain/models/enums.dart';
import '../../services/diag_log.dart';
import '../providers/calendar/google/google_token.dart';
import '../repositories/account_repository.dart';
import '../repositories/notes_repository.dart';

/// Синхронизация личных заметок к встречам между устройствами через Google
/// Tasks.
///
/// Каждая заметка — задача в отдельном списке [listTitle] Google-аккаунта
/// пользователя. Google Tasks личные: участники встреч и владельцы других
/// календарей их не видят. В задаче: заголовок «встреча · дата», текст
/// заметки и служебная строка с ключами встречи, по которым её узнаёт Calenfi
/// на другом устройстве. Текст можно править и прямо в Google Tasks.
///
/// Конфликт решает время: побеждает более поздняя правка.
class NotesSync {
  NotesSync({
    required this.notes,
    required this.accounts,
    Dio? dio,
    GoogleToken? Function(String email)? tokenFor,
  })  : _dio = dio ?? Dio(),
        _tokenFor = tokenFor ?? GoogleToken.loadForTasks {
    _dio.options
      ..validateStatus = ((s) => s != null && s < 500)
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30);
  }

  final NotesRepository notes;
  final AccountRepository accounts;
  final Dio _dio;
  final GoogleToken? Function(String email) _tokenFor;

  static const listTitle = 'Calenfi · заметки к встречам';
  static const _api = 'https://tasks.googleapis.com/tasks/v1';
  static const _marker = '\n\n⸻\ncalenfi-note ';

  /// Идущая синхронизация: повторный вызов присоединяется к ней.
  static Future<NotesSyncResult>? _inFlight;
  static String? _listId;

  /// Забыть найденный список (тесты, смена аккаунта).
  static void resetCache() => _listId = null;

  /// Через какой Google-аккаунт идёт синхронизация, или null — заметки
  /// живут только на этом устройстве (нет входа в Google с доступом к задачам).
  Future<({String email, GoogleToken token})?> channel() async {
    final google = (await accounts.allAccounts())
        .where((a) => a.provider == ProviderType.google)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final a in google) {
      final t = _tokenFor(a.email);
      if (t != null) return (email: a.email, token: t);
    }
    return null;
  }

  Future<NotesSyncResult> sync() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<NotesSyncResult> _run() async {
    final ch = await channel();
    if (ch == null) return const NotesSyncResult.localOnly();
    try {
      final headers = {'Authorization': 'Bearer ${await ch.token.accessTokenValid(_dio)}'};
      final listId = _listId ??= await _ensureList(headers);
      final remote = await _pullAll(listId, headers);
      var pulled = 0, pushed = 0;

      // 1) Входящие правки и удаления.
      final local = await notes.all(includeDeleted: true);
      final byTask = {for (final n in local) if (n.taskId != null) n.taskId!: n};
      for (final n in local) {
        final id = n.taskId;
        if (id == null || remote.containsKey(id)) continue;
        // Задачу удалили в Google Tasks или на другом устройстве.
        if (n.dirty && !n.deleted) {
          await notes.save(_copy(n, taskId: null, taskUpdated: null));
        } else {
          await notes.remove(n.id);
          pulled++;
        }
      }
      for (final t in remote.values) {
        final mine = byTask[t.id] ??
            local.where((n) => n.taskId == null && n.keys.any(t.keys.contains)).firstOrNull;
        if (mine == null) {
          await notes.save(MeetingNote(
            id: t.noteId,
            keys: t.keys,
            title: t.meetingTitle,
            startUtc: t.meetingStart,
            body: t.body,
            updatedUtc: t.updated,
            taskId: t.id,
            taskUpdated: t.updatedRaw,
            dirty: false,
          ));
          pulled++;
          continue;
        }
        final remoteChanged = mine.taskUpdated != t.updatedRaw;
        final remoteWins = mine.dirty ? t.updated.isAfter(mine.updatedUtc) : remoteChanged;
        if (remoteWins) {
          await notes.save(MeetingNote(
            id: mine.id,
            keys: {...mine.keys, ...t.keys},
            title: t.meetingTitle.isEmpty ? mine.title : t.meetingTitle,
            startUtc: t.meetingStart.millisecondsSinceEpoch == 0 ? mine.startUtc : t.meetingStart,
            body: t.body,
            updatedUtc: t.updated,
            taskId: t.id,
            taskUpdated: t.updatedRaw,
            dirty: false,
          ));
          pulled++;
        } else if (mine.taskId == null) {
          // Та же встреча уже есть в задачах: привязываем и отправим свою правку.
          await notes.save(_copy(mine, taskId: t.id, taskUpdated: t.updatedRaw));
        }
      }

      // 2) Свои правки.
      for (final n in await notes.all(includeDeleted: true)) {
        if (!n.dirty) continue;
        if (n.deleted) {
          if (n.taskId != null) {
            await _dio.delete('$_api/lists/$listId/tasks/${n.taskId}',
                options: Options(headers: headers));
          }
          await notes.remove(n.id);
          pushed++;
          continue;
        }
        final payload = {
          'title': _taskTitle(n),
          'notes': '${n.body}$_marker${jsonEncode({'id': n.id, 'start': n.startUtc.millisecondsSinceEpoch, 'keys': n.keys.toList()})}',
        };
        final Response<dynamic> r = n.taskId == null
            ? await _dio.post('$_api/lists/$listId/tasks',
                data: payload, options: Options(headers: headers))
            : await _dio.patch('$_api/lists/$listId/tasks/${n.taskId}',
                data: payload, options: Options(headers: headers));
        if (r.statusCode == 404 && n.taskId != null) {
          // Задачу удалили между чтением и записью — создадим заново в следующий раз.
          await notes.save(_copy(n, taskId: null, taskUpdated: null));
          continue;
        }
        if (r.statusCode != 200) {
          throw NotesSyncException('Google Tasks ответил ${r.statusCode}: ${r.data}');
        }
        final m = r.data as Map;
        await notes.save(MeetingNote(
          id: n.id,
          keys: n.keys,
          title: n.title,
          startUtc: n.startUtc,
          body: n.body,
          updatedUtc: n.updatedUtc,
          taskId: m['id'] as String,
          taskUpdated: m['updated'] as String?,
          dirty: false,
        ));
        pushed++;
      }
      if (pulled + pushed > 0) {
        DiagLog.instance.add('notes', 'заметки: получено $pulled, отправлено $pushed (${ch.email})');
      }
      return NotesSyncResult(email: ch.email, pulled: pulled, pushed: pushed);
    } on Object catch (e, st) {
      _listId = null;
      DiagLog.instance.error('notes', 'синхронизация заметок через ${ch.email} не удалась', e, st);
      return NotesSyncResult(email: ch.email, error: e);
    }
  }

  MeetingNote _copy(MeetingNote n, {required String? taskId, required String? taskUpdated}) =>
      MeetingNote(
        id: n.id,
        keys: n.keys,
        title: n.title,
        startUtc: n.startUtc,
        body: n.body,
        updatedUtc: n.updatedUtc,
        taskId: taskId,
        taskUpdated: taskUpdated,
        dirty: n.dirty,
        deleted: n.deleted,
      );

  static String _taskTitle(MeetingNote n) {
    if (n.startUtc.millisecondsSinceEpoch == 0) return n.title;
    final d = n.startUtc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.title} · ${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<String> _ensureList(Map<String, String> headers) async {
    String? page;
    do {
      final r = await _dio.get('$_api/users/@me/lists',
          queryParameters: {'maxResults': 100, 'pageToken': ?page},
          options: Options(headers: headers));
      if (r.statusCode != 200) {
        throw NotesSyncException('Google Tasks: список списков, HTTP ${r.statusCode}: ${r.data}');
      }
      for (final l in (r.data['items'] as List? ?? const [])) {
        if ((l as Map)['title'] == listTitle) return l['id'] as String;
      }
      page = r.data['nextPageToken'] as String?;
    } while (page != null);
    final r = await _dio.post('$_api/users/@me/lists',
        data: {'title': listTitle}, options: Options(headers: headers));
    if (r.statusCode != 200) {
      throw NotesSyncException('Google Tasks: создать список, HTTP ${r.statusCode}: ${r.data}');
    }
    DiagLog.instance.add('notes', 'создан список Google Tasks «$listTitle»');
    return (r.data as Map)['id'] as String;
  }

  Future<Map<String, _RemoteNote>> _pullAll(String listId, Map<String, String> headers) async {
    final out = <String, _RemoteNote>{};
    String? page;
    do {
      final r = await _dio.get('$_api/lists/$listId/tasks',
          queryParameters: {
            'maxResults': 100,
            'showCompleted': true,
            'showHidden': true,
            'pageToken': ?page,
          },
          options: Options(headers: headers));
      if (r.statusCode != 200) {
        throw NotesSyncException('Google Tasks: задачи, HTTP ${r.statusCode}: ${r.data}');
      }
      for (final t in (r.data['items'] as List? ?? const [])) {
        final note = _RemoteNote.parse(t as Map);
        if (note != null) out[note.id] = note;
      }
      page = r.data['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  /// Разбор текста задачи: заметка и служебная строка с ключами.
  static ({String body, Map<String, dynamic>? meta}) splitNotes(String notes) {
    final i = notes.lastIndexOf(_marker);
    if (i < 0) return (body: notes, meta: null);
    try {
      final meta = jsonDecode(notes.substring(i + _marker.length).trim());
      return (body: notes.substring(0, i), meta: meta is Map<String, dynamic> ? meta : null);
    } on FormatException {
      return (body: notes, meta: null);
    }
  }
}

class _RemoteNote {
  _RemoteNote({
    required this.id,
    required this.noteId,
    required this.keys,
    required this.body,
    required this.meetingTitle,
    required this.meetingStart,
    required this.updated,
    required this.updatedRaw,
  });

  final String id;
  final String noteId;
  final Set<String> keys;
  final String body;
  final String meetingTitle;
  final DateTime meetingStart;
  final DateTime updated;
  final String updatedRaw;

  /// null — задача добавлена в список руками, без ключей встречи: не наша.
  static _RemoteNote? parse(Map t) {
    if (t['deleted'] == true) return null;
    final split = NotesSync.splitNotes((t['notes'] as String?) ?? '');
    final meta = split.meta;
    if (meta == null) return null;
    final keys = {for (final k in (meta['keys'] as List? ?? const [])) k.toString()};
    if (keys.isEmpty) return null;
    final title = (t['title'] as String?) ?? '';
    final cut = title.lastIndexOf(' · ');
    final raw = (t['updated'] as String?) ?? '';
    return _RemoteNote(
      id: t['id'] as String,
      noteId: (meta['id'] as String?) ?? t['id'] as String,
      keys: keys,
      body: split.body,
      meetingTitle: cut > 0 ? title.substring(0, cut) : title,
      meetingStart: DateTime.fromMillisecondsSinceEpoch((meta['start'] as num?)?.toInt() ?? 0, isUtc: true),
      updated: DateTime.tryParse(raw)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedRaw: raw,
    );
  }
}

class NotesSyncResult {
  const NotesSyncResult({this.email, this.pulled = 0, this.pushed = 0, this.error});
  const NotesSyncResult.localOnly()
      : email = null,
        pulled = 0,
        pushed = 0,
        error = null;

  /// Через какой Google-аккаунт; null — синхронизации нет.
  final String? email;
  final int pulled;
  final int pushed;
  final Object? error;
  bool get ok => error == null;
}

class NotesSyncException implements Exception {
  NotesSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}
