import '../domain/models/calendar_event.dart';
import '../domain/models/merged_event.dart';

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
  List<MergedEvent> group(List<CalendarEvent> events, {bool combine = true}) {
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
      final primary = _pickPrimary(members);
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

  /// «Основной» источник для редактирования (FR-D5). Детерминированно:
  /// сначала тот, где я организатор/принял, иначе — стабильно по id.
  static CalendarEvent _pickPrimary(List<CalendarEvent> members) {
    final sorted = [...members]..sort((a, b) => a.id.compareTo(b.id));
    // Сначала НАСТОЯЩИЕ события (id вида `accId:providerId`), а не локальные
    // UUID-копии/призраки — чтобы правки/переименование шли в реальное событие.
    final real = sorted.where((e) => e.id.contains(':')).toList();
    final pool = real.isNotEmpty ? real : sorted;
    return pool.firstWhere(
      (e) => e.myResponse.index <= 1, // needsAction(0)/accepted(1) — приоритет
      orElse: () => pool.first,
    );
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
