// «Надо синхронизировать между calenfi на разных устройствах, можно google
// задачи с id встречи в календаре и подтягивать их».

import 'dart:convert';
import 'dart:typed_data';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/notes/notes_sync.dart';
import 'package:calenfi/data/providers/calendar/google/google_token.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/notes_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/services/diag_log.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Google Tasks в миниатюре: списки и задачи в памяти.
class _FakeTasks implements HttpClientAdapter {
  final lists = <String, String>{}; // id → title
  final tasks = <String, Map<String, dynamic>>{}; // id → task
  var _seq = 0;

  String _now() => DateTime.now().toUtc().add(Duration(milliseconds: _seq)).toIso8601String();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.uri.path;
    final data = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
    if (path.endsWith('/users/@me/lists')) {
      if (o.method == 'POST') {
        final id = 'list${++_seq}';
        lists[id] = data['title'] as String;
        return _json({'id': id, 'title': lists[id]});
      }
      return _json({'items': [for (final e in lists.entries) {'id': e.key, 'title': e.value}]});
    }
    final m = RegExp(r'/lists/([^/]+)/tasks(?:/([^/]+))?$').firstMatch(path)!;
    final id = m.group(2);
    switch (o.method) {
      case 'GET':
        return _json({'items': tasks.values.toList()});
      case 'POST':
        final t = {...data, 'id': 'task${++_seq}', 'updated': _now()};
        tasks[t['id'] as String] = t;
        return _json(t);
      case 'PATCH':
        if (!tasks.containsKey(id)) return _json({'error': 'not found'}, 404);
        _seq++;
        tasks[id!] = {...tasks[id]!, ...data, 'updated': _now()};
        return _json(tasks[id]!);
      case 'DELETE':
        tasks.remove(id);
        return ResponseBody.fromString('', 204);
    }
    throw UnimplementedError(o.method);
  }

  ResponseBody _json(Object b, [int s = 200]) => ResponseBody.fromString(jsonEncode(b), s,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

class _Device {
  _Device(_FakeTasks cloud, {bool google = true}) {
    db = AppDatabase(NativeDatabase.memory());
    notes = NotesRepository(db);
    accounts = AccountRepository(db);
    sync = NotesSync(
      notes: notes,
      accounts: accounts,
      dio: Dio()..httpClientAdapter = cloud,
      tokenFor: (_) => google
          ? GoogleToken(
              clientId: 'c',
              clientSecret: 's',
              refreshToken: 'r',
              tokenUri: 'https://oauth2.googleapis.com/token',
              accessToken: 'a',
              expiry: DateTime.now().add(const Duration(hours: 1)),
              scopes: const [GoogleToken.tasksScope],
            )
          : null,
    );
  }
  late final AppDatabase db;
  late final NotesRepository notes;
  late final AccountRepository accounts;
  late final NotesSync sync;

  Future<void> init() => accounts.upsertAccount(const Account(
      id: 'acc-google', provider: ProviderType.google, displayName: 'G', email: 'me@example.test'));
}

void main() {
  final t = DateTime.utc(2026, 10, 2, 14);
  // Одна и та же встреча видна на устройствах под разными id копий: общий ключ
  // у них — название и время.
  MergedEvent meeting(String id) {
    final e = CalendarEvent(
      id: id,
      calendarId: 'c',
      title: 'Собеседование',
      startUtc: t,
      endUtc: t.add(const Duration(hours: 1)),
      source: const EventSource(accountId: 'a', calendarId: 'c'),
    );
    return MergedEvent(groupId: id, primary: e, sources: [e]);
  }

  late _FakeTasks cloud;
  late _Device a, b;

  setUp(() async {
    DiagLog.instance.clear();
    // Список Google Tasks кэшируется на процесс; у каждого теста свой «облачный» сервер.
    NotesSync.resetCache();
    cloud = _FakeTasks();
    a = _Device(cloud);
    b = _Device(cloud);
    await a.init();
    await b.init();
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('заметка с одного устройства появляется на другом', () async {
    await a.notes.write(meeting('acc-a:1'), 'Повестка: опыт с LLM');
    final pushed = await a.sync.sync();
    expect(pushed.pushed, 1);
    expect(cloud.lists.values, [NotesSync.listTitle]);
    final task = cloud.tasks.values.single;
    expect(task['title'], startsWith('Собеседование · '));
    expect(task['notes'], startsWith('Повестка: опыт с LLM'));

    await b.sync.sync();
    expect(await b.notes.read(meeting('acc-b:9')), 'Повестка: опыт с LLM');
  });

  test('правка и удаление доходят в обе стороны', () async {
    await a.notes.write(meeting('acc-a:1'), 'v1');
    await a.sync.sync();
    await b.sync.sync();

    await b.notes.write(meeting('acc-b:9'), 'v2 с телефона');
    await b.sync.sync();
    await a.sync.sync();
    expect(await a.notes.read(meeting('acc-a:1')), 'v2 с телефона');
    expect(cloud.tasks, hasLength(1), reason: 'правка, а не вторая задача');

    await a.notes.write(meeting('acc-a:1'), '');
    await a.sync.sync();
    expect(cloud.tasks, isEmpty);
    await b.sync.sync();
    expect(await b.notes.read(meeting('acc-b:9')), isNull);
  });

  test('текст, исправленный прямо в Google Tasks, приходит в Calenfi', () async {
    await a.notes.write(meeting('acc-a:1'), 'старый текст');
    await a.sync.sync();
    final id = cloud.tasks.keys.single;
    final split = NotesSync.splitNotes(cloud.tasks[id]!['notes'] as String);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    cloud.tasks[id] = {
      ...cloud.tasks[id]!,
      'notes': cloud.tasks[id]!['notes'].toString().replaceFirst(split.body, 'новый текст из Tasks'),
      'updated': DateTime.now().toUtc().add(const Duration(seconds: 1)).toIso8601String(),
    };
    await a.sync.sync();
    expect(await a.notes.read(meeting('acc-a:1')), 'новый текст из Tasks');
  });

  test('чужие задачи в списке не трогаем', () async {
    await a.sync.sync();
    final listId = cloud.lists.keys.single;
    cloud.tasks['manual'] = {'id': 'manual', 'title': 'Купить молоко', 'updated': DateTime.now().toUtc().toIso8601String()};
    await a.notes.write(meeting('acc-a:1'), 'заметка');
    await a.sync.sync();
    expect(cloud.tasks.containsKey('manual'), isTrue);
    expect(await a.notes.all(), hasLength(1));
    expect(listId, isNotEmpty);
  });

  test('без входа в Google с задачами заметки остаются только на устройстве', () async {
    final local = _Device(cloud, google: false);
    await local.init();
    await local.notes.write(meeting('acc-a:1'), 'только здесь');
    final r = await local.sync.sync();
    expect(r.email, isNull);
    expect(cloud.tasks, isEmpty);
    expect(await local.notes.read(meeting('acc-a:1')), 'только здесь');
    await local.db.close();
  });

  test('заметки 0.3.18 переносятся в новое хранилище', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('SELECT 1'); // открыть базу: создаются обе таблицы
    for (final k in ['id:acc-a:1', 'key:собеседование|${t.millisecondsSinceEpoch}|${t.add(const Duration(hours: 1)).millisecondsSinceEpoch}']) {
      await db.customStatement(
          'INSERT INTO event_notes(note_key, body, updated_utc) VALUES (?, ?, ?)', [k, 'старая заметка', 1000]);
    }
    final notes = NotesRepository(db);
    expect(await notes.read(meeting('acc-z:5')), 'старая заметка');
    final all = await notes.all();
    expect(all, hasLength(1));
    expect(all.single.title, 'собеседование');
    expect(all.single.dirty, isTrue, reason: 'уйдёт в Google Tasks при первой синхронизации');
    await db.close();
  });
}
