import 'package:calenfi/domain/usecases/event_actions.dart';
import 'dart:async';

import 'package:calenfi/data/local/db/database.dart';
import 'package:calenfi/data/providers/calendar/mock/mock_provider.dart';
import 'package:calenfi/data/providers/calendar/provider_registry.dart';
import 'package:calenfi/data/repositories/account_repository.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/calendar_provider.dart';
import 'package:calenfi/features/calendar/pending_edits.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Gates control the exact network interleaving; no timing-dependent sleeps.
class _Gate {
  final entered = Completer<void>();
  final release = Completer<void>();
  Future<void> wait() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
  }

  void open() {
    if (!release.isCompleted) release.complete();
  }
}

class _Server extends MockProvider {
  _Server(this.kind) : super('a');
  final ProviderType kind;
  @override
  ProviderType get type => kind;
  CalendarEvent? remote;
  _Gate? pullGate;
  _Gate? writeGate;
  bool failWrite = false;
  bool tombstone = false;
  bool omit = false;
  bool canonicalize = false;
  final writes = <CalendarEvent>[];
  final scopes = <RecurrenceScope>[];
  final originals = <DateTime?>[];
  final responses = <ResponseStatus>[];
  int creates = 0;
  int pulls = 0;
  @override
  Future<List<Calendar>> listCalendars(Account acc) async => const [
    Calendar(id: 'a|work', accountId: 'a', name: 'Work', color: 0),
  ];
  @override
  Future<SyncResult> incrementalSync(
    Account acc,
    Calendar cal,
    String? state,
  ) async {
    pulls++;
    final snapshot = remote;
    final gate = pullGate;
    pullGate = null;
    if (gate != null) await gate.wait();
    return SyncResult(
      upserts: snapshot == null || omit ? [] : [snapshot],
      deletedIds: tombstone ? ['server'] : [],
      newSyncState: null,
      fullWindow: DateRange(DateTime.utc(2026), DateTime.utc(2027)),
    );
  }

  @override
  Future<CalendarEvent> createEvent(
    Account acc,
    Calendar cal,
    CalendarEvent e,
  ) async {
    creates++;
    return updateEvent(acc, e);
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    writes.add(e);
    scopes.add(scope);
    originals.add(originalStartUtc);
    final gate = writeGate;
    writeGate = null;
    if (gate != null) await gate.wait();
    if (failWrite) throw StateError('server rejected edit');
    remote = e.copyWith(
      source: e.source.copyWith(
        providerEventId: 'server',
        etag: 'v${writes.length}',
      ),
    );
    if (canonicalize) remote = remote!.withLocalId('a:canonical');
    return remote!;
  }

  @override
  Future<void> deleteEvent(
    Account a,
    CalendarEvent e,
    RecurrenceScope s,
  ) async {
    writes.add(e);
    final gate = writeGate;
    writeGate = null;
    if (gate != null) await gate.wait();
    if (failWrite) throw StateError('server rejected cancellation');
    remote = null;
  }

  @override
  Future<void> respondToInvite(
    Account a,
    CalendarEvent e,
    ResponseStatus r,
  ) async {
    responses.add(r);
    final gate = writeGate;
    writeGate = null;
    if (gate != null) await gate.wait();
    if (failWrite) throw StateError('server rejected response');
    remote = e.copyWith(myResponse: r);
  }
}

void main() {
  for (final kind in ProviderType.values) {
    group(kind.name, () {
      late AppDatabase db;
      late EventRepository events;
      late AccountRepository accounts;
      late SyncEngine sync;
      late _Server server;
      late Account account;
      late CalendarEvent initial;
      final gates = <_Gate>[];
      _Gate gate() {
        final g = _Gate();
        gates.add(g);
        return g;
      }

      Future<void> expectVisibleResponse(ResponseStatus response) async {
        final visible = await events
            .watchMerged(
              DateRange(DateTime.utc(2026, 10, 18), DateTime.utc(2026, 10, 19)),
            )
            .first;
        if (response == ResponseStatus.declined) {
          expect(visible, isEmpty);
        } else {
          expect(visible, hasLength(1));
          expect(visible.single.primary.id, initial.id);
          expect(visible.single.primary.myResponse, response);
        }
      }

      Future<void> edit(
        CalendarEvent e, {
        RecurrenceScope scope = RecurrenceScope.thisOnly,
        DateTime? original,
      }) async {
        await events.putLocalDirty(e);
        await events.enqueue('update', e.id, {
          'scope': scope.index,
          if (original != null) 'origStart': original.millisecondsSinceEpoch,
        });
      }

      setUp(() async {
        db = AppDatabase(NativeDatabase.memory());
        events = EventRepository(db);
        accounts = AccountRepository(db);
        server = _Server(kind);
        account = Account(
          id: 'a',
          provider: kind,
          displayName: 'Test',
          email: 'a@example.test',
        );
        initial = CalendarEvent(
          id: 'a:server',
          calendarId: 'a|work',
          title: 'Original',
          startUtc: DateTime.utc(2026, 10, 18, 10),
          endUtc: DateTime.utc(2026, 10, 18, 11),
          source: const EventSource(
            accountId: 'a',
            calendarId: 'a|work',
            providerEventId: 'server',
            etag: 'v0',
          ),
        );
        server.remote = initial;
        sync = SyncEngine(
          registry: ProviderRegistry(overrideFactory: (_) => server),
          accounts: accounts,
          events: events,
        );
        await accounts.upsertAccount(account);
        await sync.syncAccount(account);
      });
      tearDown(() async {
        for (final g in gates) {
          g.open();
        }
        gates.clear();
        await sync.whenIdle();
        sync.dispose();
        await db.close();
      });

      for (final response in [
        ResponseStatus.accepted,
        ResponseStatus.tentative,
        ResponseStatus.declined,
      ]) {
        test(
          '${response.name} during refresh survives stale pull and reaches server',
          () async {
            final g = gate();
            server.pullGate = g;
            final refresh = sync.syncAccount(account);
            await g.entered.future;
            await EventActions(events, sync).rsvp(initial, response);
            expect((await events.getById(initial.id))!.myResponse, response);
            await expectVisibleResponse(response);
            final push = sync.syncAccountById(account.id);
            await Future<void>.delayed(Duration.zero);
            g.open();
            await refresh;
            await push;
            await sync.whenIdle();
            expect(server.responses, [response]);
            expect(server.remote!.myResponse, response);
            expect((await events.getById(initial.id))!.myResponse, response);
            await expectVisibleResponse(response);
            expect(await events.pendingOutbox(), isEmpty);
          },
        );
        test(
          'failed ${response.name} stays queued and retries without changing meeting identity',
          () async {
            server.failWrite = true;
            await events.saveAndEnqueue(
              initial.copyWith(myResponse: response),
              'rsvp',
              {'resp': response.index},
            );
            expect((await sync.syncAccount(account)).ok, isFalse);
            expect(
              (await accounts.allAccounts()).single.status,
              AccountStatus.syncError,
            );
            expect(await events.pendingOutbox(), hasLength(1));
            expect((await events.getById(initial.id))!.myResponse, response);
            await expectVisibleResponse(response);
            server.failWrite = false;
            await sync.syncAccount(account);
            expect(server.remote!.id, initial.id);
            expect(server.remote!.myResponse, response);
            await expectVisibleResponse(response);
            expect(await events.pendingOutbox(), isEmpty);
            expect(server.creates, 0);
          },
        );
      }
      test(
        'accept then maybe then decline while first reply uploads preserves order',
        () async {
          final g = gate();
          server.writeGate = g;
          final actions = EventActions(events, sync);
          await actions.rsvp(initial, ResponseStatus.accepted);
          await g.entered.future;
          await actions.rsvp(initial, ResponseStatus.tentative);
          await actions.rsvp(initial, ResponseStatus.declined);
          final joined = sync.syncAccountById(account.id);
          await Future<void>.delayed(Duration.zero);
          g.open();
          await joined;
          await sync.whenIdle();
          expect(server.responses, [
            ResponseStatus.accepted,
            ResponseStatus.tentative,
            ResponseStatus.declined,
          ]);
          expect(
            (await events.getById(initial.id))!.myResponse,
            ResponseStatus.declined,
          );
          expect(await events.pendingOutbox(), isEmpty);
        },
      );
      test('cancel during refresh is not resurrected by stale pull', () async {
        final g = gate();
        server.pullGate = g;
        final refresh = sync.syncAccount(account);
        await g.entered.future;
        await EventActions(
          events,
          sync,
        ).delete(initial, scope: RecurrenceScope.thisOnly);
        expect((await events.getById(initial.id))!.deletedRemotely, isTrue);
        final joined = sync.syncAccountById(account.id);
        await Future<void>.delayed(Duration.zero);
        g.open();
        await refresh;
        await joined;
        await sync.whenIdle();
        expect(server.remote, isNull);
        expect(await events.getById(initial.id), isNull);
        expect(await events.pendingOutbox(), isEmpty);
      });
      test(
        'cancel while a move uploads retains deletion until it is sent',
        () async {
          final g = gate();
          server.writeGate = g;
          final moved = initial.copyWith(
            startUtc: initial.startUtc.add(const Duration(hours: 2)),
            endUtc: initial.endUtc.add(const Duration(hours: 2)),
          );
          final actions = EventActions(events, sync);
          await actions.update(moved, original: initial);
          await g.entered.future;
          await actions.delete(moved);
          final joined = sync.syncAccountById(account.id);
          await Future<void>.delayed(Duration.zero);
          g.open();
          await joined;
          await sync.whenIdle();
          expect(server.writes, hasLength(2));
          expect(server.remote, isNull);
          expect(await events.getById(initial.id), isNull);
          expect(await events.pendingOutbox(), isEmpty);
        },
      );
      test(
        'failed cancellation remains pending and visible until successful retry',
        () async {
          server.failWrite = true;
          await events.saveAndEnqueue(
            initial.copyWith(deletedRemotely: true),
            'delete',
            {'scope': RecurrenceScope.all.index},
          );
          expect((await sync.syncAccount(account)).ok, isFalse);
          expect(
            (await accounts.allAccounts()).single.status,
            AccountStatus.syncError,
          );
          expect((await events.getById(initial.id))!.deletedRemotely, isTrue);
          expect(await events.pendingOutbox(), hasLength(1));
          server.failWrite = false;
          await sync.syncAccount(account);
          expect(server.remote, isNull);
          expect(await events.getById(initial.id), isNull);
          expect(await events.pendingOutbox(), isEmpty);
        },
      );

      test(
        'edit during pull survives stale response and is sent by follow-up',
        () async {
          final g = gate();
          server.pullGate = g;
          final refresh = sync.syncAccount(account);
          await g.entered.future;
          await edit(initial.copyWith(title: 'Newest'));
          final push = sync.syncAccountById(account.id);
          // Let the explicit mutation request reach the running pass.
          await Future<void>.delayed(Duration.zero);
          g.open();
          await refresh;
          await push;
          await sync.whenIdle();
          expect(server.remote!.title, 'Newest');
          expect((await events.getById(initial.id))!.title, 'Newest');
          expect(await events.pendingOutbox(), isEmpty);
        },
      );

      for (final mode in ['upsert', 'tombstone', 'reconcile']) {
        test('staged drag survives $mode without an outbox entry', () async {
          final pending = PendingEditsNotifier(events, sync);
          addTearDown(pending.dispose);
          final g = gate();
          server.pullGate = g;
          server.tombstone = mode == 'tombstone';
          server.omit = mode == 'reconcile';
          final refresh = sync.syncAccount(account);
          await g.entered.future;
          await pending.stage(
            initial.copyWith(title: 'Staged'),
            const Duration(hours: 1),
            original: initial,
          );
          g.open();
          await refresh;
          final local = await events.getById(initial.id);
          expect(local, isNotNull);
          expect(local!.title, 'Staged');
          expect(local.deletedRemotely, isFalse);
          expect(server.writes, isEmpty);
        });
      }

      test(
        'second edit while first upload waits preserves both versions and fresh ETag',
        () async {
          await edit(initial.copyWith(title: 'First'));
          final g = gate();
          server.writeGate = g;
          final first = sync.syncAccount(account);
          await g.entered.future;
          await edit(initial.copyWith(title: 'Second'));
          final second = sync.syncAccountById(account.id);
          await Future<void>.delayed(Duration.zero);
          g.open();
          await first;
          await second;
          await sync.whenIdle();
          expect(server.writes.map((e) => e.title), ['First', 'Second']);
          expect(server.writes.last.source.etag, 'v1');
          expect((await events.getById(initial.id))!.title, 'Second');
          expect(await events.pendingOutbox(), isEmpty);
          expect(await db.select(db.events).get(), hasLength(1));
        },
      );

      test(
        'queued versions retain their recurrence scope and original time',
        () async {
          final firstTime = initial.startUtc.add(const Duration(minutes: 15));
          await edit(
            initial.copyWith(title: 'Series', startUtc: firstTime),
            scope: RecurrenceScope.all,
            original: initial.startUtc,
          );
          await edit(
            initial.copyWith(
              title: 'Instance',
              startUtc: firstTime.add(const Duration(minutes: 15)),
            ),
            original: firstTime,
          );
          await sync.syncAccount(account);
          expect(server.writes.map((e) => e.title), ['Series', 'Instance']);
          expect(server.scopes, [
            RecurrenceScope.all,
            RecurrenceScope.thisOnly,
          ]);
          expect(server.originals, [initial.startUtc, firstTime]);
        },
      );

      test(
        'staged newer edit survives acknowledgement of older upload',
        () async {
          await edit(initial.copyWith(title: 'First'));
          final g = gate();
          server.writeGate = g;
          final first = sync.syncAccount(account);
          await g.entered.future;
          await events.putLocalDirty(
            initial.copyWith(title: 'Not committed yet'),
          );
          g.open();
          await first;
          expect(
            (await events.getById(initial.id))!.title,
            'Not committed yet',
          );
          expect(server.remote!.title, 'First');
          expect(await events.pendingOutbox(), isEmpty);
        },
      );

      test(
        'rekey during upload retains newer edit and leaves one row',
        () async {
          server.canonicalize = true;
          await edit(initial.copyWith(title: 'First'));
          final g = gate();
          server.writeGate = g;
          final first = sync.syncAccount(account);
          await g.entered.future;
          await edit(initial.copyWith(title: 'Second'));
          g.open();
          await first;
          await sync.syncAccount(account);
          expect(server.remote!.title, 'Second');
          expect(await events.getById(initial.id), isNull);
          expect(await db.select(db.events).get(), hasLength(1));
          expect(await events.pendingOutbox(), isEmpty);
        },
      );

      test(
        'rejected upload is visible while subsequent pull still waits',
        () async {
          server.failWrite = true;
          await edit(initial.copyWith(title: 'Unsaved'));
          final g = gate();
          server.pullGate = g;
          final result = sync.syncAccount(account);
          await g.entered.future;
          expect(
            (await accounts.allAccounts()).single.status,
            AccountStatus.syncError,
          );
          expect(
            (await accounts.allAccounts()).single.lastError,
            contains('Изменение не отправлено'),
          );
          g.open();
          expect((await result).ok, isFalse);
        },
      );

      test(
        'first rejected write is immediately visible and retained',
        () async {
          server.failWrite = true;
          await edit(initial.copyWith(title: 'Unsaved'));
          final result = await sync.syncAccount(account);
          expect(result.ok, isFalse);
          expect(
            (await accounts.allAccounts()).single.status,
            AccountStatus.syncError,
          );
          expect((await events.getById(initial.id))!.title, 'Unsaved');
          expect((await events.pendingOutbox()).single.retryCount, 1);
          server.failWrite = false;
          expect((await sync.syncAccount(account)).ok, isTrue);
          expect(
            (await accounts.allAccounts()).single.status,
            AccountStatus.ok,
          );
          expect(await events.pendingOutbox(), isEmpty);
        },
      );

      test(
        'failed first operation blocks later operations for same event',
        () async {
          server.failWrite = true;
          await edit(initial.copyWith(title: 'First'));
          await edit(initial.copyWith(title: 'Second'));
          await sync.syncAccount(account);
          expect(server.writes, hasLength(1));
          expect(await events.pendingOutbox(), hasLength(2));
        },
      );

      test('staged edit survives rekey until its timer is committed', () async {
        server.canonicalize = true;
        final write = gate();
        server.writeGate = write;
        await edit(initial.copyWith(title: 'first'));
        final running = sync.syncAccount(account);
        await write.entered.future;
        final pending = PendingEditsNotifier(events, sync);
        addTearDown(pending.dispose);
        await pending.stage(
          initial.copyWith(title: 'staged'),
          const Duration(days: 1),
          original: initial,
        );
        write.open();
        await running;
        expect((await events.getById('a:canonical'))!.title, 'staged');
        expect(await events.getById(initial.id), isNull);
        // Even a newly created repository can resolve an editor's old reference.
        expect(
          await EventRepository(db).resolveEventId(initial.id),
          'a:canonical',
        );
        await pending.applyNow(initial.id);
        await sync.whenIdle();
        expect(server.writes.map((e) => e.title), ['first', 'staged']);
        expect(server.writes.last.id, 'a:canonical');
        expect(await events.pendingOutbox(), isEmpty);
        expect(await events.getById(initial.id), isNull);
      });

      test(
        'an editor holding the old identity cannot recreate a duplicate row',
        () async {
          server.canonicalize = true;
          await edit(initial.copyWith(title: 'first'));
          await sync.syncAccount(account);
          await edit(initial.copyWith(title: 'second'));
          await sync.syncAccount(account);
          expect(await events.getById(initial.id), isNull);
          expect((await events.getById('a:canonical'))!.title, 'second');
          expect(server.writes.last.id, 'a:canonical');
          expect(server.creates, 0);
        },
      );

      test(
        'edit during create keeps canonical identity without another create',
        () async {
          await events.hardDelete(initial.id);
          server.remote = null;
          final draft = initial.withId('local-uuid');
          server.canonicalize = true;
          await events.putLocalDirty(draft);
          await events.enqueue('create', draft.id);
          final g = gate();
          server.writeGate = g;
          final first = sync.syncAccount(account);
          await g.entered.future;
          await edit(draft.copyWith(title: 'Edited draft'));
          g.open();
          await first;
          await sync.syncAccount(account);
          expect(server.creates, 1);
          expect(server.remote!.title, 'Edited draft');
          expect(await db.select(db.events).get(), hasLength(1));
          expect(await events.pendingOutbox(), isEmpty);
        },
      );
    });
  }
}
