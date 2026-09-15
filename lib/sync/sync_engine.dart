import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../data/providers/calendar/empty_provider.dart';
import '../data/providers/calendar/provider_registry.dart';
import '../data/providers/calendar/token_exception.dart';
import '../data/providers/conference/conference_provisioner.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/contact_repository.dart';
import '../data/repositories/event_repository.dart';
import '../domain/models/account.dart';
import '../domain/models/calendar.dart';
import '../domain/models/calendar_event.dart';
import '../domain/models/enums.dart';
import '../domain/providers/calendar_provider.dart';

/// Результат синхронизации одного аккаунта.
class AccountSyncReport {
  AccountSyncReport(this.accountId, {this.error});
  final String accountId;
  final Object? error;
  bool get ok => error == null;
}

/// Движок синхронизации (docs/architecture.md §7).
///
/// Pull: инкрементальный синк по сохранённому syncState каждого календаря.
/// Push: отправка локальных правок из Outbox. Ошибки изолируются по аккаунту
/// (FR-S7) — падение одного источника не ломает остальные.
class SyncEngine {
  SyncEngine({
    required this.registry,
    required this.accounts,
    required this.events,
    this.contacts,
    ConferenceProvisioner? provisioner,
  }) : _provisioner = provisioner ?? ConferenceProvisioner();

  final ProviderRegistry registry;
  final AccountRepository accounts;
  final EventRepository events;

  /// Справочник контактов — автопополняется участниками синкнутых встреч (FR-K),
  /// чтобы они появлялись в автодополнении при создании события. Опционально
  /// (в CLI не задаётся).
  final ContactRepository? contacts;

  /// Развязка провижининга видеовстреч (Teams/Meet/Zoom/Telemost) от календаря.
  final ConferenceProvisioner _provisioner;

  /// Число аккаунтов, синхронизирующихся прямо сейчас (>0 → индикатор «идёт
  /// синхронизация»). Через Stream (не ValueNotifier), чтобы движок не тянул
  /// Flutter и работал в чистом Dart-CLI.
  int _active = 0;
  final _activeCtrl = StreamController<int>.broadcast();
  Stream<int> get activeStream => _activeCtrl.stream;
  int get activeCount => _active;
  void _setActive(int delta) {
    _active += delta;
    if (!_activeCtrl.isClosed) _activeCtrl.add(_active);
  }

  /// Освободить ресурсы (закрыть Stream). Нужно в одноразовых сценариях (CLI/
  /// тесты), иначе незакрытый StreamController держит изолят живым.
  void dispose() {
    if (!_activeCtrl.isClosed) _activeCtrl.close();
  }

  /// Аккаунты, чей список календарей уже перечитан в этой сессии (чтобы не
  /// дёргать listCalendars на каждом периодическом синке, но подхватить новые
  /// календари хотя бы раз за запуск).
  final Set<String> _calsRefreshed = {};

  /// Полный синк уже идёт? Повторные вызовы (напр. многократный refresh)
  /// присоединяются к нему, а не запускают ещё один параллельно.
  Future<List<AccountSyncReport>>? _inFlight;

  /// Синхронизировать все аккаунты. Возвращает отчёты (для UI-статусов).
  /// Идемпотентно: если синк уже идёт — возвращаем его же будущее.
  Future<List<AccountSyncReport>> syncAll() {
    return _inFlight ??= _runSyncAll().whenComplete(() => _inFlight = null);
  }

  Future<List<AccountSyncReport>> _runSyncAll() async {
    final all = await accounts.allAccounts();
    final reports = <AccountSyncReport>[];
    for (final acc in all) {
      reports.add(await syncAccount(acc));
    }
    return reports;
  }

  /// Синхронизировать один аккаунт по id (мгновенный пуш изменения именно его
  /// календаря). Тихо игнорирует неизвестный id.
  Future<void> syncAccountById(String accountId) async {
    final all = await accounts.allAccounts();
    for (final acc in all) {
      if (acc.id == accountId) {
        await syncAccount(acc);
        return;
      }
    }
  }

  /// Синки одного аккаунта, идущие прямо сейчас — чтобы ручной refresh и
  /// периодический тик не запускали один и тот же аккаунт параллельно
  /// (гонка reconcile → мигание событий).
  final Map<String, Future<AccountSyncReport>> _accountInFlight = {};

  /// Обёртка с учётом «идёт синхронизация» (для индикатора в UI) и защитой от
  /// параллельного синка одного и того же аккаунта.
  Future<AccountSyncReport> syncAccount(Account acc) {
    // ВАЖНО: тело — блок, а не `=> _accountInFlight.remove(...)`. Стрелка вернула
    // бы результат Map.remove() — а это и есть сама завершающаяся Future, и
    // whenComplete стал бы ждать её же → самодедлок (Future ждёт саму себя).
    return _accountInFlight[acc.id] ??= _syncAccountTracked(acc).whenComplete(
      () {
        _accountInFlight.remove(acc.id);
      },
    );
  }

  Future<AccountSyncReport> _syncAccountTracked(Account acc) async {
    _setActive(1);
    try {
      // Предохранитель: синк одного аккаунта не может висеть вечно (иначе он
      // блокировал бы syncAll и держал per-account гард). Таймауты dio/curl
      // ограничивают отдельные запросы, этот — весь проход.
      return await _syncAccount(acc).timeout(
        const Duration(seconds: 150),
        onTimeout: () async {
          await accounts.recordSyncFailure(
            acc.id,
            AccountStatus.syncError,
            'Синхронизация превысила лимит времени',
          );
          return AccountSyncReport(acc.id, error: 'timeout');
        },
      );
    } finally {
      _setActive(-1);
    }
  }

  /// Синхронизация одного аккаунта с **3 попытками** перед вердиктом «упал»
  /// (критично: не гасим календарь по разовому сбою — FR-A6/надёжность).
  Future<AccountSyncReport> _syncAccount(Account acc) async {
    final provider = registry.forAccount(acc);

    // Нет провайдера/кредов (напр. на телефоне без on-device авторизации) —
    // НЕ делаем вид, что синхронизировано: помечаем «не подключён», чтобы
    // пользователь видел реальный статус, а не устаревшие данные (FR-A6).
    if (provider is EmptyProvider) {
      await accounts.recordSyncFailure(
        acc.id,
        AccountStatus.needsReconnect,
        'Нет учётных данных на устройстве — аккаунт не синхронизируется',
      );
      return AccountSyncReport(acc.id, error: 'not connected');
    }

    Object? lastErr;

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        // 1) убедиться, что календари известны. Перечитываем список при первом
        // синке аккаунта в сессии (и если пусто) — иначе новый календарь в
        // облаке не появится, а устаревшие/mock-календари навсегда заблокируют
        // открытие реальных. upsert сохраняет visible/цвета/syncState.
        var cals = await accounts.calendarsOf(acc.id);
        if (cals.isEmpty || !_calsRefreshed.contains(acc.id)) {
          final discovered = await provider.listCalendars(acc);
          if (discovered.isNotEmpty) {
            await accounts.upsertCalendars(discovered);
            _calsRefreshed.add(acc.id);
            cals = await accounts.calendarsOf(acc.id);
          }
        }

        // 2) push сначала — чтобы не перетереть локальные правки приходящим pull.
        // Возвращает текст ошибки, если правка не доехала (не поддержано/лимит),
        // — тогда pull всё равно делаем, но статус ставим error, а не ok, чтобы
        // пользователь видел: изменение НЕ сохранилось (не молчим).
        final pushError = await _processOutbox(acc, provider);

        // Перечитываем очередь ПОСЛЕ push: успешные задания уже удалены,
        // rekey обновил eventId, а неуспешные update/delete/rsvp/create должны
        // пережить pull без потери локальной версии.
        final protectedIds = (await events.pendingOutbox())
            .map((item) => item.eventId)
            .toSet();

        // 3) pull по каждому календарю
        for (final cal in cals) {
          await _pullCalendar(acc, provider, cal, protectedIds);
        }

        // 4) подчистить «призраков» — UUID-копии, не удалённые после создания,
        // у которых уже есть серверный двойник (иначе дубль в UI).
        await events.cleanupGhostDuplicates();
        await events.cleanupOrphanSeriesMasters();

        if (pushError != null) {
          await accounts.recordSyncFailure(
            acc.id,
            AccountStatus.syncError,
            pushError,
          );
          return AccountSyncReport(acc.id, error: pushError);
        }
        await accounts.recordSyncSuccess(acc.id, DateTime.now().toUtc());
        return AccountSyncReport(acc.id);
      } catch (e) {
        lastErr = e;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    // после 3 неудач — фиксируем статус: переподключение / офлайн / ошибка.
    final status = lastErr is TokenExpiredException
        ? AccountStatus.needsReconnect
        : _isNetwork(lastErr)
        ? AccountStatus.offline
        : AccountStatus.syncError;
    await accounts.recordSyncFailure(acc.id, status, _describe(lastErr));
    return AccountSyncReport(acc.id, error: lastErr);
  }

  static bool _isNetwork(Object? error) {
    Object? cause = error;

    if (error is DioException) {
      // Dio groups DNS/no-route, refused/reset and TLS failures under
      // connectionError. Only an underlying SocketException with an explicit
      // local-network marker proves that the device itself is offline.
      if (error.type != DioExceptionType.connectionError &&
          error.type != DioExceptionType.unknown) {
        return false;
      }
      cause = error.error;
    }

    if (cause is! SocketException) return false;

    final details = [
      cause.message,
      cause.osError?.message,
    ].whereType<String>().join(' ').toLowerCase();
    const offlineMarkers = [
      'failed host lookup',
      'name or service not known',
      'no such host is known',
      'nodename nor servname provided',
      'no address associated with hostname',
      'temporary failure in name resolution',
      'network is unreachable',
      'network is down',
      'no route to host',
      'unreachable network',
    ];
    return offlineMarkers.any(details.contains);
  }

  static String _describe(Object? e) {
    final s = e.toString();
    return s.length > 200 ? s.substring(0, 200) : s;
  }

  Future<void> _pullCalendar(
    Account acc,
    CalendarProvider provider,
    Calendar cal,
    Set<String> protectedIds,
  ) async {
    final result = await provider.incrementalSync(acc, cal, cal.syncState);
    // Всё применяем ОДНОЙ транзакцией (upsert + tombstone + сверка окна), чтобы
    // события не мигали в UI между отдельными записями. Сверка: [upserts] —
    // полный набор за окно, локальные события в окне, которых больше нет в
    // источнике, удаляем (кроме dirty).
    final window = result.fullWindow;
    await events.applyPull(
      calendarId: cal.id,
      upserts: result.upserts,
      deletedProviderIds: result.deletedIds,
      protectedIds: protectedIds,
      windowStart: window?.startUtc,
      windowEnd: window?.endUtc,
      keepIds: window != null
          ? result.upserts.map((e) => e.id).toSet()
          : const {},
    );
    await accounts.setCalendarSyncState(cal.id, result.newSyncState);
    await _harvestContacts(result.upserts);
  }

  /// Кладёт участников синкнутых встреч в справочник контактов (только новых —
  /// [ContactRepository.addIfAbsent] не затирает существующие). Ресурсы
  /// (переговорки) и записи без валидной почты пропускаем. Ошибки глотаем —
  /// пополнение справочника не должно ронять синк.
  Future<void> _harvestContacts(List<CalendarEvent> upserts) async {
    final cr = contacts;
    if (cr == null || upserts.isEmpty) return;
    final seen = <String>{};
    for (final ev in upserts) {
      for (final a in ev.attendees) {
        if (a.isResource) continue;
        final email = a.email.trim();
        final low = email.toLowerCase();
        if (email.isEmpty || !email.contains('@') || !seen.add(low)) continue;
        final dn = a.displayName?.trim();
        final name = (dn != null && dn.isNotEmpty) ? dn : email;
        try {
          await cr.addIfAbsent(email: email, displayName: name);
        } catch (_) {
          /* пополнение справочника — best-effort */
        }
      }
    }
  }

  /// Сколько раз пробуем протолкнуть задание, прежде чем признать провал и
  /// показать ошибку (вместо тихого вечного ретрая — FR-A6).
  static const _maxOutboxRetries = 5;

  /// Проталкивает Outbox своего аккаунта. Возвращает текст ошибки, если хотя бы
  /// одна правка не доехала (постоянная ошибка или исчерпан лимит попыток), —
  /// иначе null. Ошибку поднимаем в [_syncAccount], чтобы статус стал error.
  Future<String?> _processOutbox(Account acc, CalendarProvider provider) async {
    final pending = await events.pendingOutbox();
    // pending — snapshot. Если первый create/update канонизирует id,
    // следующие элементы этого уже загруженного snapshot всё ещё
    // содержат old id. Алиасы дополняют транзакционный retarget в БД.
    final aliases = <String, String>{};
    String resolveEventId(String id) {
      final seen = <String>{};
      var resolved = id;
      while (seen.add(resolved) && aliases.containsKey(resolved)) {
        resolved = aliases[resolved]!;
      }
      return resolved;
    }

    String? failure;
    for (final item in pending) {
      final effectiveEventId = resolveEventId(item.eventId);
      // Задание уже исчерпало попытки — не долбим сервер молча; ошибка уже
      // отражена в статусе аккаунта (см. catch ниже). Ждём ручного действия.
      if (item.retryCount >= _maxOutboxRetries) {
        // Но принадлежность СВОЕМУ аккаунту всё равно проверим для отчёта.
        final ev = await events.getById(effectiveEventId);
        if (item.op == 'create' || ev?.source.accountId == acc.id) {
          failure ??= 'изменение не отправлено (исчерпаны попытки)';
        }
        continue;
      }
      try {
        final event = await events.getById(effectiveEventId);
        // Пуш только для СВОЕГО аккаунта. Раньше синк другого аккаунта доходил
        // до removeOutbox и СТИРАЛ чужое задание, не отправив его (баг: локально
        // удалено, в облаке осталось). Для create аккаунт определяется по
        // календарю ниже (свой `continue`).
        if (item.op != 'create') {
          if (event == null) {
            await events.removeOutbox(item.id); // сирота — чистим
            continue;
          }
          if (event.source.accountId != acc.id) continue; // чужой — не трогаем
        }
        switch (item.op) {
          case 'create':
            // Defense-in-depth: событие пушит только СВОЙ аккаунт. Раньше guard
            // держался лишь на совпадении calendarId; при коллизии id календарей
            // между провайдерами этого мало — проверяем владельца явно, как в
            // update/delete/rsvp. Так O365 никогда не создаст чужое событие.
            // ВАЖНО: чужое задание именно ПРОПУСКАЕМ (continue) — упади мы вниз
            // switch'а, removeOutbox стёр бы его, не отправив (см. тест
            // cross_account_create_test).
            if (event != null && event.source.accountId != acc.id) continue;
            if (event != null) {
              final cals = await accounts.calendarsOf(acc.id);
              // СТРОГО: создаём только если целевой календарь принадлежит ЭТОМУ
              // аккаунту. Раньше был orElse → cals.first: при синке «не того»
              // аккаунта событие с чужим calendarId создавалось в его первом
              // календаре (guard cal.accountId==acc.id это НЕ ловил, т.к.
              // cals.first — календарь текущего аккаунта) → дубль в чужом
              // календаре (напр. в личном вместо рабочего). Если владельца
              // тут нет — пропускаем, задание обработает нужный аккаунт.
              Calendar? cal;
              for (final c in cals) {
                if (c.id == event.calendarId) {
                  cal = c;
                  break;
                }
              }
              if (cal == null) continue; // не наш календарь — не создаём
              // Завести видеовстречу нужной УЗ до создания события (если выбран
              // тип и она ещё «ожидающая»). Кросс-аккаунт → реальная ссылка в теле.
              var ev = event;
              if (ev.conference != null && !ev.conference!.isReady) {
                ev = await _provisioner.ensure(
                  ev,
                  target: acc,
                  allAccounts: await accounts.allAccounts(),
                  events: events,
                );
              }
              final created = await provider.createEvent(acc, cal, ev);
              // Сохранить кросс-аккаунтную конференцию, даже если провайдер
              // календаря её не распарсил из ответа.
              final saved = (ev.conference?.isReady ?? false)
                  ? created.copyWith(conference: ev.conference)
                  : created;
              // Сервер присвоил СВОЙ id (напр. Google → accId:providerId) —
              // удаляем оптимистичную локальную строку со старым UUID, иначе
              // остаются ДВА события (UUID-копия dirty + серверная). FR-S4.
              if (saved.id != event.id) {
                await events.rekeyLocalDirtyAndOutbox(event.id, saved);
                aliases[event.id] = saved.id;
              } else {
                await events.putLocalDirty(saved);
              }
              // Создали СЕРИЮ: провайдер вернул мастера, а читать мы будем
              // развёрнутые вхождения. Оставить мастера локально нельзя —
              // он повиснет в сетке лишней встречей рядом с первым вхождением
              // (и перетаскивание попадёт по нему, сдвинув всю серию). Строку
              // помечаем чистой: pull ниже принесёт вхождения, а сверка окна
              // уберёт мастера в той же транзакции.
              if (saved.recurrenceRule != null && saved.recurrenceId == null) {
                await events.putLocalClean(saved);
              }
            }
          case 'update':
            if (event != null && event.source.accountId == acc.id) {
              // Область правки повторяющегося события выбирает пользователь;
              // origStart — время вхождения ДО правки, по нему адаптер сдвигает
              // серию ровно на дельту, а не переставляет её на дату вхождения.
              final scope = _readScope(item.payloadJson);
              final updated = await provider.updateEvent(
                acc,
                event,
                scope: scope,
                originalStartUtc: _readEpochUtc(item.payloadJson, 'origStart'),
              );
              // Адаптер может канонизировать локальный id (например,
              // CalDAV legacy `account:calendar:`-префиксы). Переносим
              // dirty-строку на новый ключ, чтобы pull очистил её, а
              // старый dirty-дубль не пережил reconcile.
              if (updated.id != event.id) {
                await events.rekeyLocalDirtyAndOutbox(event.id, updated);
                aliases[event.id] = updated.id;
              } else {
                // Даже при том же локальном id провайдер мог вернуть новый
                // ETag/changeKey. Следующий update/delete из уже загруженной
                // цепочки обязан увидеть его, иначе отправит stale If-Match.
                await events.putLocalDirty(updated);
              }
              // Сдвинули СЕРИЮ — у вхождений меняются времена, а с ними и
              // локальные id (`<master>_<время>` у Google, uid + RECURRENCE-ID
              // у CalDAV). Отправленная строка адресует старое вхождение,
              // которого больше нет: оставь её dirty — и она навсегда зависнет
              // рядом с новым временем. Помечаем чистой, сверка окна уберёт.
              if (scope != RecurrenceScope.thisOnly) {
                await events.putLocalClean(updated);
              }
            }
          case 'delete':
            if (event != null && event.source.accountId == acc.id) {
              final idx = int.tryParse(
                _readInt(item.payloadJson, 'scope') ?? '',
              );
              final scope =
                  (idx != null &&
                      idx >= 0 &&
                      idx < RecurrenceScope.values.length)
                  ? RecurrenceScope.values[idx]
                  : RecurrenceScope.all;
              await provider.deleteEvent(acc, event, scope);
              // Удалить и внешнюю видеовстречу (Zoom standalone) — best-effort.
              await _provisioner.deleteConference(event.conference);
              await events.hardDelete(event.id);
            }
          case 'rsvp':
            if (event != null && event.source.accountId == acc.id) {
              final resp =
                  ResponseStatus.values[int.tryParse(
                        _readInt(item.payloadJson, 'resp') ?? '0',
                      ) ??
                      0];
              await provider.respondToInvite(acc, event, resp);
            }
        }
        await events.removeOutbox(item.id);
      } catch (e) {
        final attempts = item.retryCount + 1;
        await events.bumpRetry(item.id, attempts);
        // Постоянные ошибки (не поддерживается провайдером) ретраить бессмысленно
        // — сразу «сжигаем» попытки. Иначе — после лимита. В обоих случаях
        // показываем ошибку на аккаунте, а не теряем правку молча.
        final permanent = e is UnsupportedError || e is UnimplementedError;
        if (permanent) {
          await events.bumpRetry(item.id, _maxOutboxRetries);
        }
        if (permanent || attempts >= _maxOutboxRetries) {
          failure ??= _describe(e);
        }
      }
    }
    return failure;
  }

  /// Область правки/удаления из задания Outbox (по умолчанию — одно вхождение:
  /// так безопаснее, случайная правка не заденет всю серию).
  static RecurrenceScope _readScope(String json) {
    final idx = int.tryParse(_readInt(json, 'scope') ?? '');
    return (idx != null && idx >= 0 && idx < RecurrenceScope.values.length)
        ? RecurrenceScope.values[idx]
        : RecurrenceScope.thisOnly;
  }

  static DateTime? _readEpochUtc(String json, String key) {
    final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(json);
    final ms = m == null ? null : int.tryParse(m.group(1)!);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Числовое поле payload или null, если его нет. Раньше отсутствие давало
  /// '0', и delete без `scope` превращался в thisOnly вместо всей серии.
  static String? _readInt(String json, String key) {
    final m = RegExp('"$key"\\s*:\\s*(\\d+)').firstMatch(json);
    return m?.group(1);
  }
}
