// Calenfi Agent CLI (Linux/Arch).
//
// JSON-интерфейс над локальной БД Calenfi для LLM-агентов: чтение занятости и
// встреч, поиск свободных слотов, создание/изменение/удаление событий, RSVP.
//
// Все команды печатают JSON в stdout: {"ok": true, ...} или {"ok": false, "error": ...}.
// Записи (create/update/delete/rsvp) пишутся оптимистично в локальную БД и
// очередь Outbox; в источники они уедут при следующей синхронизации приложения.
//
// Использование: dart run calenfi:calenfi <command> [--flags]
// (или скомпилированный бинарь tools/calenfi <command> [--flags]).
// Подробности — docs/AGENT_API.md.

import 'dart:convert';
import 'dart:io';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/providers/conference/conference_provisioner.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/contact_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/attendee.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/conference.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/data/secure/secret_store.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _appId = 'io.github.karpovilia.calenfi';
const _uuid = Uuid();

Future<void> main(List<String> argv) async {
  if (argv.isEmpty || argv.first == '--help' || argv.first == 'help') {
    _printUsage();
    return;
  }
  final command = argv.first;
  final flags = _parseFlags(argv.skip(1).toList());

  // Секреты (пароли, OAuth-токены) — из системного keyring, тот же, что у
  // приложения: и здесь, и там бэкенд ходит в штатную утилиту ОС
  // (Linux — `secret-tool`, macOS — `security`). Каждый запуск CLI — отдельный
  // процесс, кэша между ними нет, поэтому keyring дёргаем ТОЛЬКО для команд,
  // которым секреты действительно нужны: иначе серия локальных create/delete
  // устраивает шквал запросов к связке ключей (и диалогов разблокировки).
  const needSecrets = {'sync', 'secret-set'};
  if (needSecrets.contains(command)) {
    await SecretStore.instance.warmUp();
  }

  final db = AppDatabase(NativeDatabase(File(_dbPath(flags['db']))));
  final events = EventRepository(db);
  final accounts = AccountRepository(db);
  final contacts = ContactRepository(db);
  final registry = ProviderRegistry();

  try {
    switch (command) {
      case 'agenda':
        await _agenda(events, flags);
      case 'busy':
        await _busy(events, flags);
      case 'freeslots':
        await _freeslots(events, flags);
      case 'create':
        await _create(events, accounts, flags);
        await _pushOutbox(events, accounts, registry);
      case 'update':
        await _update(events, flags);
        await _pushOutbox(events, accounts, registry);
      case 'delete':
        await _delete(events, flags);
        await _pushOutbox(events, accounts, registry);
      case 'rsvp':
        await _rsvp(events, flags);
        await _pushOutbox(events, accounts, registry);
      case 'accounts':
        await _accounts(accounts);
      case 'calendars':
        await _calendars(accounts);
      case 'sync':
        await _sync(events, accounts, registry, flags);
      case 'contacts':
        await _contacts(contacts);
      case 'contact-add':
        await _contactAdd(contacts, flags);
      case 'secret-set':
        // Положить секрет в хранилище (keyring/фолбэк): напр. ключи Zoom
        // ZOOM_ACCOUNT_ID / ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET.
        _require(flags, ['key', 'value']);
        await SecretStore.instance.write(flags['key']!, flags['value']!);
        _ok({'set': flags['key']});
      default:
        _fail('unknown command: $command');
    }
  } catch (e, st) {
    _fail('$e', stack: st.toString());
  } finally {
    await db.close();
  }
  // Одноразовый CLI: гарантированно выходим, не дожидаясь висящих ресурсов
  // (например broadcast-StreamController движка держал бы изолят живым).
  await stdout.flush();
  exit(exitCode);
}

// ───────────────────────── команды ─────────────────────────

/// Полная синхронизация (pull из источников + push Outbox) через тот же
/// [SyncEngine], что и приложение. `--account <id>` — синкнуть один аккаунт.
Future<void> _sync(EventRepository events, AccountRepository accounts,
    ProviderRegistry registry, Map<String, String> f) async {
  final engine =
      SyncEngine(registry: registry, accounts: accounts, events: events);
  try {
    final only = f['account'];
    if (only != null && only.isNotEmpty) {
      await engine.syncAccountById(only);
      final matches = (await accounts.allAccounts()).where((x) => x.id == only);
      final a = matches.isEmpty ? null : matches.first;
      _ok({
        'synced': only,
        'status': a?.status.name,
        'lastSync': a?.lastSyncUtc?.toIso8601String(),
        'error': a?.lastError,
      });
    } else {
      final reports = await engine.syncAll();
      _ok({
        'accounts': [
          for (final r in reports)
            {'id': r.accountId, 'ok': r.ok, if (!r.ok) 'error': '${r.error}'},
        ],
      });
    }
  } finally {
    engine.dispose();
  }
}

Future<void> _agenda(EventRepository repo, Map<String, String> f) async {
  final range = _range(f);
  final includeCancelled = f.containsKey('include-cancelled');
  final merged = await repo
      .watchMerged(range, includeCancelled: includeCancelled, combine: true)
      .first;
  merged.sort((a, b) => a.primary.startUtc.compareTo(b.primary.startUtc));
  _ok({
    'from': range.startUtc.toUtc().toIso8601String(),
    'to': range.endUtc.toUtc().toIso8601String(),
    'count': merged.length,
    'events': merged.map(_mergedJson).toList(),
  });
}

Future<void> _busy(EventRepository repo, Map<String, String> f) async {
  final range = _range(f);
  final merged = await repo.watchMerged(range, combine: true).first;
  final intervals = <_Interval>[];
  for (final m in merged) {
    final e = m.primary;
    if (e.isCancelled) continue;
    if (e.showAs == ShowAs.free) continue;
    if (e.myResponse == ResponseStatus.declined) continue;
    intervals.add(_Interval(e.startUtc.toUtc(), e.endUtc.toUtc(), e.title));
  }
  final busy = _mergeIntervals(intervals);
  _ok({
    'from': range.startUtc.toUtc().toIso8601String(),
    'to': range.endUtc.toUtc().toIso8601String(),
    'busy': busy
        .map((i) => {
              'start': i.start.toIso8601String(),
              'end': i.end.toIso8601String(),
            })
        .toList(),
    'sources': intervals
        .map((i) => {
              'start': i.start.toIso8601String(),
              'end': i.end.toIso8601String(),
              'title': i.title,
            })
        .toList(),
  });
}

Future<void> _freeslots(EventRepository repo, Map<String, String> f) async {
  final range = _range(f);
  final duration = Duration(minutes: int.parse(f['duration'] ?? '30'));
  final dayStart = int.parse(f['day-start'] ?? '10');
  final dayEnd = int.parse(f['day-end'] ?? '20');

  final merged = await repo.watchMerged(range, combine: true).first;
  final busy = _mergeIntervals([
    for (final m in merged)
      if (!m.primary.isCancelled &&
          m.primary.showAs != ShowAs.free &&
          m.primary.myResponse != ResponseStatus.declined)
        _Interval(m.primary.startUtc.toUtc(), m.primary.endUtc.toUtc(),
            m.primary.title)
  ]);

  final slots = <Map<String, String>>[];
  var day = DateTime(range.startUtc.toLocal().year,
      range.startUtc.toLocal().month, range.startUtc.toLocal().day);
  final lastDay = range.endUtc.toLocal();
  while (day.isBefore(lastDay)) {
    var cursor = DateTime(day.year, day.month, day.day, dayStart);
    final windowEnd = DateTime(day.year, day.month, day.day, dayEnd);
    while (cursor.add(duration).isBefore(windowEnd) ||
        cursor.add(duration).isAtSameMomentAs(windowEnd)) {
      final slotEnd = cursor.add(duration);
      final overlaps = busy.any((b) =>
          b.start.toLocal().isBefore(slotEnd) &&
          b.end.toLocal().isAfter(cursor));
      if (!overlaps) {
        slots.add({
          'start': cursor.toUtc().toIso8601String(),
          'end': slotEnd.toUtc().toIso8601String(),
        });
        cursor = slotEnd;
      } else {
        cursor = cursor.add(const Duration(minutes: 15));
      }
    }
    day = day.add(const Duration(days: 1));
  }
  _ok({
    'durationMinutes': duration.inMinutes,
    'workday': '$dayStart:00-$dayEnd:00',
    'count': slots.length,
    'slots': slots,
  });
}

Future<void> _create(EventRepository events, AccountRepository accounts,
    Map<String, String> f) async {
  _require(f, ['title', 'start']);
  if (f['all-day'] != 'true') _require(f, ['end']);
  final cals = await accounts.watchCalendars().first;
  if (cals.isEmpty) return _fail('no calendars; connect an account first');

  Calendar cal;
  if (f['calendar'] != null) {
    cal = cals.firstWhere((c) => c.id == f['calendar'],
        orElse: () => throw 'calendar not found: ${f['calendar']}');
  } else if (f['account'] != null) {
    final acc = (await accounts.allAccounts())
        .firstWhere((a) => a.email == f['account'] || a.id == f['account'],
            orElse: () => throw 'account not found: ${f['account']}');
    // Основной календарь аккаунта, а не первый попавшийся: иначе событие
    // молча уезжает в чужой подписной календарь того же аккаунта.
    final own = cals.where((c) => c.accountId == acc.id && !c.readOnly).toList();
    if (own.isEmpty) throw 'no writable calendar for account ${acc.email}';
    cal = own.firstWhere((c) => c.isPrimary,
        orElse: () => own.firstWhere(
            (c) => c.id.endsWith('|${acc.email}') || c.name == acc.email,
            orElse: () => own.first));
  } else {
    final writable = cals.where((c) => !c.readOnly).toList();
    if (writable.isEmpty) throw 'no writable calendars';
    cal = writable.firstWhere((c) => c.isPrimary, orElse: () => writable.first);
  }
  if (cal.readOnly) throw 'calendar is read-only: ${cal.id}';

  final id = _uuid.v4();
  // --all-day: --start/--end принимают дату (2026-09-22) или ISO; время
  // отбрасывается, конец — эксклюзивная полночь (как в редакторе приложения).
  // Если --end не задан, событие занимает один день.
  final allDay = f['all-day'] == 'true';
  final DateTime start;
  final DateTime end;
  if (allDay) {
    final s = DateTime.parse(f['start']!);
    final e = f['end'] != null ? DateTime.parse(f['end']!) : s;
    final s0 = DateTime(s.year, s.month, s.day);
    var e0 = DateTime(e.year, e.month, e.day);
    if (!e0.isAfter(s0)) e0 = DateTime(s0.year, s0.month, s0.day + 1);
    start = s0.toUtc();
    end = e0.toUtc();
  } else {
    start = DateTime.parse(f['start']!).toUtc();
    end = DateTime.parse(f['end']!).toUtc();
  }
  if (!end.isAfter(start)) throw 'end must be after start';
  final event = CalendarEvent(
    id: id,
    calendarId: cal.id,
    title: f['title']!,
    startUtc: start,
    endUtc: end,
    allDay: allDay,
    location: f['location'],
    description: f['description'],
    // Повторяющаяся серия: --rrule "FREQ=WEEKLY;BYDAY=WE;UNTIL=20270731T235959Z"
    recurrenceRule:
        (f['rrule'] ?? '').isNotEmpty ? f['rrule']!.toUpperCase() : null,
    attendees: [
      ..._parseAttendees(f['attendees']),
      // Переговорка (--room email) — ресурс-участник, комната подтверждает бронь.
      if ((f['room'] ?? '').isNotEmpty)
        Attendee(email: f['room']!, isResource: true),
    ],
    conference: _parseConference(f['conference']),
    myResponse: ResponseStatus.organizer,
    source: EventSource(
        accountId: cal.accountId, calendarId: cal.id, providerEventId: id),
  );
  await events.putLocalDirty(event);
  await events.enqueue('create', id);
  _ok({'created': _eventJson(event), 'note': 'queued; syncs when app runs'});
}

Future<void> _update(EventRepository events, Map<String, String> f) async {
  _require(f, ['id']);
  final e = await events.getById(f['id']!);
  if (e == null) return _fail('event not found: ${f['id']}');
  // --all-day true|false переключает режим; при true даты обрезаются до полуночи.
  final allDay = f['all-day'] == null ? e.allDay : f['all-day'] == 'true';
  DateTime? parse(String? v) {
    if (v == null) return null;
    final d = DateTime.parse(v);
    return (allDay ? DateTime(d.year, d.month, d.day) : d).toUtc();
  }

  final updated = e.copyWith(
    title: f['title'],
    allDay: allDay,
    startUtc: parse(f['start']),
    endUtc: parse(f['end']),
    location: f['location'],
    description: f['description'],
    attendees: f['attendees'] != null ? _parseAttendees(f['attendees']) : null,
  );
  if (!updated.endUtc.isAfter(updated.startUtc)) {
    throw 'end must be after start';
  }
  await events.putLocalDirty(updated);
  await events.enqueue('update', updated.id);
  _ok({'updated': _eventJson(updated), 'note': 'queued; syncs when app runs'});
}

Future<void> _delete(EventRepository events, Map<String, String> f) async {
  _require(f, ['id']);
  final e = await events.getById(f['id']!);
  if (e == null) return _fail('event not found: ${f['id']}');
  await events.putLocalDirty(e.copyWith(deletedRemotely: true));
  await events.enqueue('delete', e.id);
  _ok({'deleted': e.id, 'note': 'queued; syncs when app runs'});
}

Future<void> _rsvp(EventRepository events, Map<String, String> f) async {
  _require(f, ['id', 'response']);
  final e = await events.getById(f['id']!);
  if (e == null) return _fail('event not found: ${f['id']}');
  final resp = switch (f['response']) {
    'accepted' => ResponseStatus.accepted,
    'declined' => ResponseStatus.declined,
    'tentative' => ResponseStatus.tentative,
    _ => throw 'response must be accepted|declined|tentative',
  };
  await events.putLocalDirty(e.copyWith(myResponse: resp));
  await events.enqueue('rsvp', e.id, {'resp': resp.index});
  _ok({'id': e.id, 'response': f['response'], 'note': 'queued'});
}

Future<void> _accounts(AccountRepository accounts) async {
  final list = await accounts.allAccounts();
  _ok({
    'accounts': [
      for (final a in list)
        {
          'id': a.id,
          'email': a.email,
          'name': a.displayName,
          'provider': a.provider.name,
          'status': a.status.name,
        }
    ]
  });
}

Future<void> _calendars(AccountRepository accounts) async {
  final list = await accounts.watchCalendars().first;
  _ok({
    'calendars': [
      for (final c in list)
        {
          'id': c.id,
          'accountId': c.accountId,
          'name': c.name,
          'visible': c.visible,
          'primary': c.isPrimary,
        }
    ]
  });
}

Future<void> _contacts(ContactRepository contacts) async {
  final list = await contacts.all();
  _ok({
    'contacts': [
      for (final c in list)
        {'id': c.id, 'name': c.displayName, 'email': c.email, 'source': c.source}
    ]
  });
}

Future<void> _contactAdd(ContactRepository contacts, Map<String, String> f) async {
  _require(f, ['name', 'email']);
  await contacts.upsert(
      email: f['email']!, displayName: f['name']!, id: f['id']);
  _ok({'added': {'name': f['name'], 'email': f['email']}});
}

/// Немедленный пуш Outbox в источники (после изменения через CLI — «сразу синк»).
/// Печатает прогресс в stderr, чтобы stdout оставался чистым JSON.
Future<void> _pushOutbox(EventRepository events, AccountRepository accounts,
    ProviderRegistry registry) async {
  final pending = await events.pendingOutbox();
  if (pending.isEmpty) return;
  final accs = {for (final a in await accounts.allAccounts()) a.id: a};
  final provisioner = ConferenceProvisioner();
  for (final item in pending) {
    try {
      final e = await events.getById(item.eventId);
      if (e == null) {
        await events.removeOutbox(item.id);
        continue;
      }
      final acc = accs[e.source.accountId];
      if (acc == null) continue;
      final provider = registry.forAccount(acc);
      switch (item.op) {
        case 'create':
          final cals = await accounts.calendarsOf(acc.id);
          // СТРОГО целевой календарь этого же аккаунта. НИКОГДА не подставляем
          // cals.first: иначе событие с чужим calendarId создаётся не там
          // (в т.ч. в чужом аккаунте) — порча данных (см. sync_engine guard).
          Calendar? cal;
          for (final c in cals) {
            if (c.id == e.calendarId) {
              cal = c;
              break;
            }
          }
          if (cal == null) {
            stderr.writeln('skip create: календарь ${e.calendarId} '
                'не принадлежит ${acc.id}');
            continue;
          }
          var ev = e;
          if (ev.conference != null && !ev.conference!.isReady) {
            ev = await provisioner.ensure(ev,
                target: acc, allAccounts: accs.values.toList(), events: events);
          }
          final created = await provider.createEvent(acc, cal, ev);
          final saved = (ev.conference?.isReady ?? false)
              ? created.copyWith(conference: ev.conference)
              : created;
          await events.putLocalDirty(saved);
        case 'update':
          await provider.updateEvent(acc, e);
        case 'delete':
          await provider.deleteEvent(acc, e, RecurrenceScope.all);
          await provisioner.deleteConference(e.conference); // Zoom standalone
          await events.hardDelete(e.id);
        case 'rsvp':
          final m = RegExp(r'"resp"\s*:\s*(\d+)').firstMatch(item.payloadJson);
          final resp = ResponseStatus.values[int.parse(m?.group(1) ?? '0')];
          await provider.respondToInvite(acc, e, resp);
      }
      await events.removeOutbox(item.id);
      stderr.writeln('pushed ${item.op} ${item.eventId}');
    } catch (err) {
      await events.bumpRetry(item.id, item.retryCount + 1);
      stderr.writeln('push failed (${item.op}): $err');
    }
  }
}

// ───────────────────────── JSON ─────────────────────────

Map<String, dynamic> _eventJson(CalendarEvent e) => {
      'id': e.id,
      'title': e.title,
      'start': e.startUtc.toUtc().toIso8601String(),
      'end': e.endUtc.toUtc().toIso8601String(),
      'allDay': e.allDay,
      'status': e.isCancelled ? 'cancelled' : e.status.name,
      'response': e.myResponse.name, // organizer/accepted/needsAction/...
      'showAs': e.showAs.name,
      'calendarId': e.calendarId,
      'accountId': e.source.accountId,
      if (e.webUrl != null) 'url': e.webUrl,
      if (e.location != null) 'location': e.location,
      if (e.description != null) 'description': e.description,
      if (e.conference != null)
        'conference': {
          'type': e.conference!.type.name,
          'url': e.conference!.joinUrl,
        },
      if (e.room != null) 'room': e.room!.email, // переговорка (ресурс)
      if (e.people.isNotEmpty)
        'attendees': [
          for (final a in e.people)
            {'email': a.email, 'response': a.response.name}
        ],
    };

Map<String, dynamic> _mergedJson(MergedEvent m) => {
      ..._eventJson(m.primary),
      'merged': m.isMerged,
      if (m.isMerged) 'sourceCount': m.sources.length,
      if (m.isMerged)
        'sources': [
          for (final s in m.sources)
            {'calendarId': s.calendarId, 'response': s.myResponse.name}
        ],
    };

// ───────────────────────── утилиты ─────────────────────────

class _Interval {
  _Interval(this.start, this.end, this.title);
  final DateTime start;
  final DateTime end;
  final String title;
}

List<_Interval> _mergeIntervals(List<_Interval> input) {
  if (input.isEmpty) return [];
  final sorted = [...input]..sort((a, b) => a.start.compareTo(b.start));
  final out = <_Interval>[sorted.first];
  for (final i in sorted.skip(1)) {
    final last = out.last;
    if (!i.start.isAfter(last.end)) {
      out[out.length - 1] = _Interval(
          last.start, i.end.isAfter(last.end) ? i.end : last.end, 'busy');
    } else {
      out.add(i);
    }
  }
  return out;
}

DateRange _range(Map<String, String> f) {
  final from = f['from'] != null
      ? DateTime.parse(f['from']!)
      : DateTime.now().subtract(const Duration(days: 1));
  final to = f['to'] != null
      ? DateTime.parse(f['to']!)
      : DateTime.now().add(const Duration(days: 7));
  return DateRange(from.toUtc(), to.toUtc());
}

List<Attendee> _parseAttendees(String? s) {
  if (s == null || s.isEmpty) return const [];
  return s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.contains('@'))
      .map((e) => Attendee(email: e))
      .toList();
}

Conference? _parseConference(String? s) {
  if (s == null || s.isEmpty) return null;
  final type = ConferenceType.values.firstWhere((t) => t.name == s,
      orElse: () => ConferenceType.unknown);
  if (type == ConferenceType.unknown) return null;
  // «Ожидающая» — реальную встречу заведёт провижинер при пуше Outbox.
  return Conference.pending(type);
}

Map<String, String> _parseFlags(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a.startsWith('--')) {
      final key = a.substring(2);
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        map[key] = args[++i];
      } else {
        map[key] = 'true';
      }
    }
  }
  return map;
}

void _require(Map<String, String> f, List<String> keys) {
  final missing = keys.where((k) => f[k] == null).toList();
  if (missing.isNotEmpty) throw 'missing required flags: ${missing.join(', ')}';
}

String _dbPath(String? override) {
  if (override != null) return override;
  final env = Platform.environment;
  if (env['CALENFI_DB'] != null) return env['CALENFI_DB']!;
  final dataHome = env['XDG_DATA_HOME'] ??
      p.join(env['HOME'] ?? '/root', '.local', 'share');
  return p.join(dataHome, _appId, 'calenfi.sqlite');
}

void _ok(Map<String, dynamic> data) {
  stdout.writeln(const JsonEncoder.withIndent('  ')
      .convert({'ok': true, ...data}));
}

void _fail(String error, {String? stack}) {
  final out = <String, dynamic>{'ok': false, 'error': error};
  if (stack != null) out['stack'] = stack;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
  exitCode = 1;
}

void _printUsage() {
  stdout.writeln('''
Calenfi Agent CLI — JSON-интерфейс к локальному календарю.

Команды:
  agenda    --from ISO --to ISO [--include-cancelled]   список встреч
  busy      --from ISO --to ISO                          интервалы занятости (free/busy)
  freeslots --from ISO --to ISO --duration MIN [--day-start 10 --day-end 20]
  create    --title T --start ISO --end ISO [--calendar ID|--account EMAIL]
            [--all-day (тогда --start/--end — даты, --end необязателен)]
            [--location L --description D --attendees a@x,b@y --room room@x
             --rrule "FREQ=WEEKLY;BYDAY=MO,WE" (повторение, RFC 5545)
             --conference meet|teams|zoom|telemost]
  update    --id ID [--title --start --end --all-day true|false --location
                     --description]
  delete    --id ID
  rsvp      --id ID --response accepted|declined|tentative
  accounts                                               список учётных записей
  calendars                                              список календарей
  sync      [--account acc-<id>]                          синхронизация (все или один аккаунт)
  contacts                                               список контактов
  contact-add --name N --email E                          добавить контакт
  secret-set  --key K --value V                           положить секрет (напр. ключи Zoom)

Время — ISO 8601 (например 2026-06-12T15:00:00). Вывод — JSON.
Путь к БД можно переопределить через --db или переменную CALENFI_DB.
''');
}
