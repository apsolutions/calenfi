import '../domain/models/calendar_event.dart';
import '../domain/models/enums.dart';
import '../domain/models/merged_event.dart';

/// Чей календарь держит копию события: нужен, чтобы сверху склейки стояла
/// копия из календаря, куда пригласили меня, а не бронь переговорки или
/// подписка на чужой календарь.
class CopyOwnership {
  const CopyOwnership({
    required this.accountEmail,
    required this.calendarName,
    this.isPrimary = false,
    this.readOnly = false,
  });

  /// Адрес учётной записи, к которой относится календарь.
  final String accountEmail;

  /// Имя календаря у провайдера (без пользовательского переименования).
  final String calendarName;
  final bool isPrimary;
  final bool readOnly;

  /// Основной календарь самой учётной записи: так его отмечает провайдер,
  /// либо (у CalDAV, где отметки нет) он назван адресом учётной записи.
  bool get isOwnMain =>
      isPrimary ||
      calendarName.trim().toLowerCase() == accountEmail.trim().toLowerCase();
}

/// Движок дедупликации / склейки одинаковых событий (FR-D1, FR-D2).
///
/// Это view-level группировка: исходные [CalendarEvent] не мутируются.
/// Правило сопоставления (FR-D2):
///  • совпадение iCalendar UID (`providerUid`) — сильный сигнал (склеиваем);
///  • иначе: нормализованный заголовок + время начала + время окончания
///    (all-day и timed не склеиваются).
class DedupEngine {
  const DedupEngine();

  /// Насколько далеко могут разойтись начала двух копий одного вхождения с
  /// общим UID. Меньше суток, чтобы соседние дни ежедневной серии не слились.
  static const _uidSameOccurrence = Duration(hours: 12);

  /// Группирует события в [MergedEvent]. Если [combine] == false — каждое
  /// событие остаётся отдельной «группой из одного» (FR-C11).
  ///
  /// [ownership] — сведения о календарях по их id; без них основная копия
  /// выбирается только по моему ответу на приглашение.
  List<MergedEvent> group(
    List<CalendarEvent> events, {
    bool combine = true,
    Map<String, CopyOwnership> ownership = const {},
  }) {
    if (!combine) {
      return events
          .map((e) => MergedEvent(groupId: e.id, primary: e, sources: [e]))
          .toList();
    }

    final uf = _UnionFind(events.length);

    // Индексы по сигналам.
    final byUid = <String, List<int>>{};
    final byKey = <String, int>{};
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final uid = e.providerUid;
      if (uid != null && uid.isNotEmpty) {
        (byUid[uid] ??= []).add(i);
      }
      final key = _heuristicKey(e);
      final j = byKey[key];
      if (j != null) uf.union(i, j);
      byKey[key] = i;
    }

    // Общий UID — это одна встреча только в пределах одного вхождения: у всех
    // вхождений повторяющейся серии UID одинаковый. Склеиваем копии, чьи
    // начала ближе [_uidSameOccurrence] (перенесённая копия), но не соседние
    // вхождения серии — иначе на широком диапазоне (виджет берёт год) серия
    // сворачивается в одну группу и её вхождения пропадают.
    for (final idx in byUid.values) {
      if (idx.length < 2) continue;
      idx.sort((a, b) => events[a].startUtc.compareTo(events[b].startUtc));
      for (var k = 1; k < idx.length; k++) {
        final gap = events[idx[k]].startUtc.difference(events[idx[k - 1]].startUtc);
        if (gap < _uidSameOccurrence) uf.union(idx[k], idx[k - 1]);
      }
    }

    // Собираем группы по корню union-find.
    final groups = <int, List<CalendarEvent>>{};
    for (var i = 0; i < events.length; i++) {
      groups.putIfAbsent(uf.find(i), () => []).add(events[i]);
    }

    return groups.values.map((members) {
      final primary = _pickPrimary(members, ownership);
      return MergedEvent(
        groupId: primary.id,
        primary: primary,
        sources: members,
      );
    }).toList();
  }

  /// Эвристический ключ: нормализованный заголовок + интервал + флаг all-day.
  static String _heuristicKey(CalendarEvent e) {
    final t = normalizeTitle(e.title);
    final s = e.startUtc.toUtc().millisecondsSinceEpoch;
    final en = e.endUtc.toUtc().millisecondsSinceEpoch;
    return '${e.allDay ? 'A' : 'T'}|$t|$s|$en';
  }

  /// Нормализация заголовка для сопоставления (FR-D2):
  /// trim, lower-case, схлопывание пробелов.
  static String normalizeTitle(String title) =>
      title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// «Основной» источник склейки (FR-D5): его название, календарь и цвет
  /// видны в сетке, и в него идут правки.
  ///
  /// Сверху должна стоять копия из моего календаря, куда пригласили мою
  /// учётную запись. Раньше брался первый по id с ответом «нет ответа» или
  /// «принято», и встреча с бронью переговорки показывалась календарём
  /// бронирования, а приглашение из чужого календаря — календарём подписки.
  static CalendarEvent _pickPrimary(
    List<CalendarEvent> members,
    Map<String, CopyOwnership> ownership,
  ) {
    final sorted = [...members]..sort((a, b) => a.id.compareTo(b.id));
    // Сначала НАСТОЯЩИЕ события (id вида `accId:providerId`), а не локальные
    // UUID-копии/призраки — чтобы правки/переименование шли в реальное событие.
    final real = sorted.where((e) => e.id.contains(':')).toList();
    final pool = real.isNotEmpty ? real : sorted;
    var best = pool.first;
    var bestScore = ownershipScore(best, ownership[best.calendarId]);
    for (final e in pool.skip(1)) {
      final s = ownershipScore(e, ownership[e.calendarId]);
      if (s > bestScore) {
        best = e;
        bestScore = s;
      }
    }
    return best;
  }

  /// Насколько копия «моя». Больше — выше в склейке.
  static int ownershipScore(CalendarEvent e, CopyOwnership? owner) {
    var score = 0;
    if (owner != null) {
      final me = owner.accountEmail.trim().toLowerCase();
      final invited = me.isNotEmpty &&
          e.attendees.any((a) => !a.isResource && a.email.trim().toLowerCase() == me);
      // Учётная запись этого календаря в участниках или организатор.
      if (invited || e.myResponse == ResponseStatus.organizer) score += 4;
      // Основной календарь учётной записи, а не общий, не бронь, не подписка.
      if (owner.isOwnMain) score += 8;
      if (owner.readOnly) score -= 4;
    }
    switch (e.myResponse) {
      case ResponseStatus.accepted:
      case ResponseStatus.organizer:
        score += 2;
      case ResponseStatus.needsAction:
      case ResponseStatus.tentative:
        score += 1;
      case ResponseStatus.declined:
        score -= 2;
    }
    return score;
  }
}

class _UnionFind {
  _UnionFind(int n) : _parent = List<int>.generate(n, (i) => i);
  final List<int> _parent;

  int find(int x) {
    while (_parent[x] != x) {
      _parent[x] = _parent[_parent[x]];
      x = _parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) _parent[ra] = rb;
  }
}
