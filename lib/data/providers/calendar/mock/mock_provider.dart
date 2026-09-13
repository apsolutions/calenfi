import '../../../../domain/models/account.dart';
import '../../../../domain/models/calendar.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/enums.dart';
import '../../../../domain/providers/calendar_provider.dart';
import '../../../../domain/providers/provider_capabilities.dart';

/// Мок-адаптер: имитирует реальный источник без сети (для разработки и тестов
/// до подключения реальных провайдеров, Этап 2). Хранит события в памяти,
/// поддерживает CRUD и одноразовый инкремент-синк.
class MockProvider implements CalendarProvider {
  MockProvider(this.accountId, {this.light = false});

  final String accountId;

  /// «Лёгкий» сид: только общее (склеиваемое) событие + пара своих — чтобы
  /// дедуп-демо был наглядным, а не «всё дублируется».
  final bool light;

  @override
  ProviderType get type => ProviderType.google;

  @override
  ProviderCapabilities get caps => ProviderCapabilities.google;

  final Map<String, List<CalendarEvent>> _store = {};
  bool _seeded = false;

  late final List<Calendar> _calendars = [
    Calendar(id: '$accountId:work', accountId: accountId, name: 'Работа', color: 0xFF4F86F7, isPrimary: true),
    Calendar(id: '$accountId:personal', accountId: accountId, name: 'Личное', color: 0xFF34A853),
  ];

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async =>
      AuthResult(success: true);

  @override
  Future<void> refreshAuth(Account acc) async {}

  @override
  Future<List<Calendar>> listCalendars(Account acc) async => _calendars;

  @override
  Future<List<CalendarEvent>> fetchEvents(
      Account acc, Calendar cal, DateRange range) async {
    _ensureSeeded();
    return (_store[cal.id] ?? [])
        .where((e) =>
            e.startUtc.isBefore(range.endUtc) &&
            e.endUtc.isAfter(range.startUtc))
        .toList();
  }

  @override
  Future<SyncResult> incrementalSync(
      Account acc, Calendar cal, String? syncState) async {
    _ensureSeeded();
    // Первый синк (syncState == null) отдаёт все события; далее — пусто.
    if (syncState != null) {
      return const SyncResult(upserts: [], deletedIds: [], newSyncState: 'v1');
    }
    return SyncResult(
      upserts: List.of(_store[cal.id] ?? const []),
      deletedIds: const [],
      newSyncState: 'v1',
    );
  }

  @override
  Future<CalendarEvent> createEvent(
      Account acc, Calendar cal, CalendarEvent e) async {
    final created = e.copyWith();
    _store.putIfAbsent(cal.id, () => []).add(created);
    return created;
  }

  @override
  Future<CalendarEvent> updateEvent(
    Account acc,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async {
    final list = _store[e.calendarId];
    if (list != null) {
      final i = list.indexWhere((x) => x.id == e.id);
      if (i >= 0) list[i] = e;
    }
    return e;
  }

  @override
  Future<void> deleteEvent(
      Account acc, CalendarEvent e, RecurrenceScope scope) async {
    _store[e.calendarId]?.removeWhere((x) => x.id == e.id);
  }

  @override
  Future<void> respondToInvite(
      Account acc, CalendarEvent e, ResponseStatus r) async {
    await updateEvent(acc, e.copyWith(myResponse: r));
  }

  // --- сид демо-данных ---
  void _ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    DateTime at(int dayOffset, int h, int m) {
      final d = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      return DateTime(d.year, d.month, d.day, h, m).toUtc();
    }

    CalendarEvent mk(String cal, String id, String title, DateTime s, DateTime e,
        {ResponseStatus resp = ResponseStatus.organizer,
        String? location,
        String? description,
        String? sharedUid,
        EventStatus status = EventStatus.confirmed}) {
      // sharedUid делает событие одинаковым между аккаунтами → дедуп (FR-D2).
      final uid = sharedUid ?? '$accountId:$id';
      return CalendarEvent(
        id: '$accountId:$id',
        calendarId: '$accountId:$cal',
        title: title,
        startUtc: s,
        endUtc: e,
        timeZoneId: 'Europe/Moscow',
        myResponse: resp,
        location: location,
        description: description,
        status: status,
        source: EventSource(
          accountId: accountId,
          calendarId: '$accountId:$cal',
          providerEventId: uid,
        ),
      );
    }

    // общее событие между аккаунтами (одинаковый UID) → демонстрация склейки (FR-D)
    final shared = mk('work', 'shared', 'Общий статус компании',
        at(0, 11, 0), at(0, 11, 30),
        sharedUid: 'SHARED-COMPANY-STATUS');

    if (light) {
      _store['$accountId:work'] = [
        shared,
        mk('work', 'y1', 'Личный созвон (Яндекс)', at(0, 15, 0), at(0, 15, 30)),
      ];
      _store['$accountId:personal'] = [];
      return;
    }

    _store['$accountId:work'] = [
      mk('work', 'e1', 'afina Management Sync', at(0, 10, 0), at(0, 10, 30),
          description: 'https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0'),
      shared,
      mk('work', 'e2', 'Дейлик с командой', at(0, 12, 0), at(0, 12, 30)),
      mk('work', 'e5', 'Статус по проекту', at(1, 13, 0), at(1, 14, 0)),
      mk('work', 'e7', 'Внутреннее обсуждение HR', at(2, 17, 0), at(2, 18, 0)),
    ];
    _store['$accountId:personal'] = [
      mk('personal', 'e3', "Mentor's Seminar", at(0, 13, 0), at(0, 14, 20),
          resp: ResponseStatus.needsAction,
          description: 'Подключайтесь: https://us06web.zoom.us/j/84538569211?pwd=h9mxRRyE92'),
      mk('personal', 'e4', 'Катя Скрипка', at(0, 14, 0), at(0, 14, 45),
          location: 'Москва, ул. Тверская, 1'),
      mk('personal', 'e6', 'Отменённая встреча', at(0, 16, 0), at(0, 16, 30),
          status: EventStatus.cancelled),
    ];
  }
}
