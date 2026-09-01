import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/keymap.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/merged_event.dart';
import '../event_editor/event_editor_screen.dart';
import '../settings/settings_screen.dart';
import 'account_health_banner.dart';
import 'calendar_state.dart';
import 'day_view.dart';
import 'event_details_sheet.dart';
import 'month_view.dart';
import 'pending_edits.dart';
import 'week_view.dart';

/// Компактный стиль иконок топ-бара: убирает 48-px тач-таргет и лишние отступы,
/// чтобы Row верхней панели не переполнялся на узком экране (S23, overflow 8px).
final ButtonStyle _compactIconStyle = IconButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.all(6),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Тонкая полоса «идёт синхронизация» — календарь показан сразу из кэша,
/// а синк крутится в фоне (без блокирующей шестерни).
class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(syncEngineProvider);
    return StreamBuilder<int>(
      stream: engine.activeStream,
      initialData: engine.activeCount,
      builder: (_, snap) => (snap.data ?? 0) > 0
          ? const LinearProgressIndicator(minHeight: 2)
          : const SizedBox.shrink(),
    );
  }
}

/// Полоска-подсказка в режиме переноса: тянуть встречи, тап — детали.
class _MoveModeHint extends StatelessWidget {
  const _MoveModeHint();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_with, size: 14, color: cs.onPrimaryContainer),
          const SizedBox(width: 6),
          Expanded(
            child: Text(L10n.of(context).calMoveModeHint,
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// Поиск событий по названию / участнику / id с выпадающим списком результатов
/// и переключателем сортировки (по релевантности / по дате). Живёт в середине
/// верхней панели (десктоп). Результат по клику открывает карточку события.
class _EventSearch extends ConsumerStatefulWidget {
  const _EventSearch();
  @override
  ConsumerState<_EventSearch> createState() => _EventSearchState();
}

class _EventSearchState extends ConsumerState<_EventSearch> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  Timer? _debounce;
  List<CalendarEvent> _results = const [];
  bool _byDate = false; // false — релевантность, true — дата
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {}); // обновить крестик очистки
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _run);
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    _query = q;
    if (q.isEmpty) {
      setState(() => _results = const []);
      _portal.hide();
      return;
    }
    final r = await ref.read(eventRepositoryProvider).search(q);
    if (!mounted) return;
    setState(() => _results = r);
    _portal.show();
  }

  int _relevance(CalendarEvent e) {
    final q = _query.toLowerCase();
    final t = e.title.toLowerCase();
    var s = 0;
    if (t == q) {
      s += 300;
    } else if (t.startsWith(q)) {
      s += 200;
    } else if (t.contains(q)) {
      s += 120;
    }
    if (e.people.any((a) =>
        a.email.toLowerCase().contains(q) ||
        (a.displayName?.toLowerCase().contains(q) ?? false))) {
      s += 60;
    }
    if (e.id.toLowerCase().contains(q)) s += 20;
    return s;
  }

  List<CalendarEvent> get _sorted {
    final list = [..._results];
    if (_byDate) {
      list.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    } else {
      final now = DateTime.now().toUtc();
      list.sort((a, b) {
        final byScore = _relevance(b).compareTo(_relevance(a));
        if (byScore != 0) return byScore;
        return a.startUtc
            .difference(now)
            .abs()
            .compareTo(b.startUtc.difference(now).abs());
      });
    }
    return list;
  }

  void _open(CalendarEvent e) {
    _portal.hide();
    _focus.unfocus();
    showEventDetails(
        context, MergedEvent(groupId: e.id, primary: e, sources: [e]));
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _overlay,
        child: SizedBox(
          height: 38,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            onTap: () {
              if (_results.isNotEmpty) _portal.show();
            },
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
              hintText: L10n.of(context).calSearchHint,
              hintStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _controller.clear(),
                    ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 34, minHeight: 34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext ctx) {
    final sorted = _sorted;
    final cs = Theme.of(ctx).colorScheme;
    return Stack(children: [
      // клик мимо — закрыть
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _portal.hide,
        ),
      ),
      CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  minWidth: 340, maxWidth: 480, maxHeight: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
                    child: Row(children: [
                      Text(L10n.of(ctx).calSearchFound(sorted.length),
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      const Spacer(),
                      SegmentedButton<bool>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                              value: false,
                              label: Text(L10n.of(ctx).calSortRelevance)),
                          ButtonSegment(
                              value: true, label: Text(L10n.of(ctx).calSortDate)),
                        ],
                        selected: {_byDate},
                        onSelectionChanged: (s) =>
                            setState(() => _byDate = s.first),
                      ),
                    ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: sorted.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(L10n.of(ctx).calNothingFound))
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: sorted.length,
                            itemBuilder: (_, i) => _tile(sorted[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _tile(CalendarEvent e) {
    final colors = ref.read(calendarColorsProvider).value ?? const {};
    final color = Color(e.colorOverride ?? colors[e.calendarId] ?? 0xFF888888);
    final d = e.startUtc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final date = d.year == now.year
        ? '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}'
        : '${two(d.day)}.${two(d.month)}.${d.year}';
    // если совпадение по участнику — покажем его почту подсказкой
    final q = _query.toLowerCase();
    final who = e.people
        .where((a) =>
            a.email.toLowerCase().contains(q) ||
            (a.displayName?.toLowerCase().contains(q) ?? false))
        .map((a) => a.displayName?.isNotEmpty == true ? a.displayName! : a.email)
        .take(1)
        .join();
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      title: Text(e.title.isEmpty ? L10n.of(context).calNoTitle : e.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(who.isEmpty ? date : '$date · $who',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11)),
      onTap: () => _open(e),
    );
  }
}

/// Компактная инлайн-версия панели ожидающих для топ-бара (широкий экран):
/// счётчик + «В облако» (отправить всё). Отмена отдельных правок — крестиком на
/// самом событии; «Отменить всё» — здесь же вторичной кнопкой.
class _PendingInline extends ConsumerWidget {
  const _PendingInline();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingEditsProvider).length;
    if (n == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(pendingEditsProvider.notifier);
    final dense = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStatePropertyAll(
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_upload_outlined,
            size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text('$n', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(width: 4),
        TextButton(
            style: dense,
            onPressed: notifier.cancelAll,
            child: Text(L10n.of(context).calCancel)),
        const SizedBox(width: 2),
        FilledButton(
            style: dense,
            onPressed: notifier.applyAll,
            child: Text(L10n.of(context).calToCloud)),
      ]),
    );
  }
}

/// Верхняя панель ожидающих отправки правок (перенос/ресайз с задержкой).
/// «В облако» — отправить всё сейчас; «Отменить» — вернуть всё из облака.
class _PendingBar extends ConsumerWidget {
  const _PendingBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(pendingEditsProvider).length;
    if (n == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(pendingEditsProvider.notifier);
    return Material(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 6, 2),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 16, color: cs.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(L10n.of(context).calPendingCount(n),
                  style:
                      TextStyle(fontSize: 13, color: cs.onTertiaryContainer)),
            ),
            TextButton.icon(
              onPressed: notifier.cancelAll,
              icon: const Icon(Icons.undo, size: 16),
              label: Text(L10n.of(context).calCancel),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: notifier.applyAll,
              icon: const Icon(Icons.cloud_upload, size: 16),
              label: Text(L10n.of(context).calToCloud),
            ),
          ],
        ),
      ),
    );
  }
}

/// Главный экран календаря: верхняя панель + текущий вид + FAB создания.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _initedView = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // На телефоне по умолчанию — дневной вид (недельная сетка слишком тесная).
    if (!_initedView) {
      _initedView = true;
      if (MediaQuery.of(context).size.width < 600) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(viewModeProvider.notifier).state = CalendarViewMode.day;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(viewModeProvider);
    return CalenfiKeymap(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const _TopBar(),
              const AccountHealthBanner(),
              const _SyncIndicator(),
              // Панель ожидающих отправки правок отдельной полосой — ТОЛЬКО на
              // узких экранах (< 720). На широких она инлайн в топ-баре и не
              // ресайзит сетку.
              if (MediaQuery.of(context).size.width < 720 &&
                  ref.watch(pendingEditsProvider).isNotEmpty)
                const _PendingBar(),
              // Баннер-подсказка только на телефоне; на десктопе не нужен.
              if (ref.watch(moveModeProvider) &&
                  MediaQuery.of(context).size.width < 600)
                const _MoveModeHint(),
              const Divider(height: 1),
              Expanded(
                child: switch (mode) {
                  // Дневной вид листается плавно своим PageView.
                  CalendarViewMode.day => const DayView(),
                  // Неделя/месяц — свайп листает период.
                  CalendarViewMode.week => _SwipePeriod(child: WeekView()),
                  CalendarViewMode.month => _SwipePeriod(child: MonthView()),
                  _ => Center(child: Text(L10n.of(context).calViewInDev)),
                },
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => EventEditor.open(context,
              initialDay: ref.read(focusedDateProvider)),
          child: const Icon(Icons.add),
        ),
        // Настройки — боковая панель (не закрывает календарь целиком, FR-C).
        // Внутренний Navigator: «Учётные записи» тоже открываются панелью, а не
        // на весь экран.
        endDrawer: Drawer(
          width: 400,
          child: SafeArea(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const _SettingsDrawerHome(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Корень боковой панели настроек (внутри endDrawer c вложенным Navigator).
/// «Учётные записи» из [SettingsPanel] пушатся в этот же Navigator → остаются
/// панелью, а не открываются на весь экран.
class _SettingsDrawerHome extends StatelessWidget {
  const _SettingsDrawerHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Builder(
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(
              children: [
                Text(L10n.of(context).calSettings,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Scaffold.of(ctx).closeEndDrawer(),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        const Expanded(child: SettingsPanel()),
      ],
    );
  }
}

/// Свайп влево/вправо листает период (для недели/месяца).
class _SwipePeriod extends ConsumerWidget {
  const _SwipePeriod({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 120) return;
          shiftFocused(ref, v < 0 ? 1 : -1);
        },
        child: child,
      );
}

/// Всегда видимое время последней синхронизации + жирный красный «!», если
/// какой-то календарь не синхронизировался. Тап — запустить синк.
class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStreamProvider).value ?? const [];
    final now = DateTime.now().toUtc();
    // Когда всё исправно, показываем самый старый успешный синк: один свежий
    // аккаунт не должен маскировать отставший. При частичном сбое не выдаём
    // дату сломанного аккаунта за состояние всего приложения — показываем
    // число действительно актуальных аккаунтов и время худшего из них.
    DateTime? oldest;
    DateTime? oldestFresh;
    var freshCount = 0;
    bool anyNever = false; // есть аккаунт, ни разу не синканный
    bool anyStale = false; // есть аккаунт, отставший от своего интервала
    for (final a in accounts) {
      final t = a.lastSyncUtc;
      if (t == null) {
        anyNever = true;
        continue;
      }
      if (oldest == null || t.isBefore(oldest)) oldest = t;
      final iv = a.refresh.effectiveInterval;
      final limit = iv == Duration.zero
          ? const Duration(minutes: 30)
          : iv * 2 + const Duration(minutes: 2);
      final isStale = now.difference(t) > limit;
      if (isStale) anyStale = true;
      if (a.isHealthy && !isStale) {
        freshCount++;
        if (oldestFresh == null || t.isBefore(oldestFresh)) oldestFresh = t;
      }
    }
    final failed = accounts.any((a) => !a.isHealthy);
    final stale = anyNever || anyStale;
    final ok = accounts.isNotEmpty && !failed && !stale;
    final warn = failed || stale;

    const green = Color(0xFF2ECC71);
    const amber = Color(0xFFFF8F00);
    final color = warn ? amber : (ok ? green : null);
    final statusText = warn
        ? '$freshCount/${accounts.length}'
              '${oldestFresh == null ? '' : ' · ${_fmtSince(oldestFresh.toLocal())}'}'
        : (oldest == null ? '—' : _fmtSince(oldest.toLocal()));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        // Сперва отправить ВСЕ отложенные правки (перенос/ресайз ждут таймера
        // commitDelay) в Outbox — иначе синк пушил лишь те, чей таймер уже
        // истёк (обычно первое перенесённое событие), а остальные «висели».
        await ref.read(pendingEditsProvider.notifier).applyAll();
        await ref.read(syncTriggerProvider)();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(L10n.of(context).calSynced)));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Во время синка — жёлтая «cloud_sync», чтобы было видно, что пошло.
            StreamBuilder<int>(
              stream: ref.read(syncEngineProvider).activeStream,
              initialData: ref.read(syncEngineProvider).activeCount,
              builder: (_, snap) => (snap.data ?? 0) > 0
                  ? const Icon(Icons.cloud_sync,
                      size: 20, color: Color(0xFFFFC400))
                  : Icon(
                      ok
                          ? Icons.cloud_done_outlined
                          : (failed ? Icons.sync_problem : Icons.sync),
                      size: 20,
                      color: color),
            ),
            const SizedBox(width: 3),
            Text(statusText,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: ok ? FontWeight.w600 : null)),
            if (warn)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text('!',
                    style: TextStyle(
                        color: Color(0xFFFF1744),
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmtSince(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    return sameDay
        ? '${two(d.hour)}:${two(d.minute)}'
        : '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    final showCancelled = ref.watch(showCancelledProvider);
    final showMonth = ref.watch(showMonthViewProvider);
    // На узком экране (телефон) убираем стрелки (листание — свайпом) и
    // сокращаем подписи, чтобы переключатель видов влезал.
    final narrow = MediaQuery.of(context).size.width < 600;
    // Панель ожидающих правок показываем ИНЛАЙН в топ-баре (между датой и
    // Д/Н/М), только когда ширины хватает — иначе она уезжает отдельной полосой
    // (см. CalendarScreen) и не ресайзит сетку на десктопе.
    final wideForPending = MediaQuery.of(context).size.width >= 720;
    final pendingN = ref.watch(pendingEditsProvider).length;

    // Если месяц скрыт, а сейчас выбран месяц — мягко переключаемся на неделю.
    final selectedMode =
        (!showMonth && mode == CalendarViewMode.month) ? CalendarViewMode.week : mode;
    if (selectedMode != mode) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(viewModeProvider.notifier).state = selectedMode);
    }

    // Три точки открывают Настройки сразу (панелью) — попап из одного пункта не
    // нужен. «Показать удалённые/отменённые» и всё прочее живёт в Настройках.
    final menu = Builder(
      builder: (ctx) => IconButton(
        style: _compactIconStyle,
        icon: const Icon(Icons.more_vert),
        tooltip: L10n.of(context).calSettings,
        onPressed: () => Scaffold.of(ctx).openEndDrawer(),
      ),
    );

    final switcher = SegmentedButton<CalendarViewMode>(
      showSelectedIcon: false,
      style: narrow
          ? const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap)
          : null,
      segments: [
        ButtonSegment(
            value: CalendarViewMode.day,
            label: Text(narrow
                ? L10n.of(context).calDayShort
                : L10n.of(context).calDay)),
        ButtonSegment(
            value: CalendarViewMode.week,
            label: Text(narrow
                ? L10n.of(context).calWeekShort
                : L10n.of(context).calWeek)),
        if (showMonth)
          ButtonSegment(
              value: CalendarViewMode.month,
              label: Text(narrow
                  ? L10n.of(context).calMonthShort
                  : L10n.of(context).calMonth)),
      ],
      selected: {selectedMode},
      onSelectionChanged: (s) =>
          ref.read(viewModeProvider.notifier).state = s.first,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (narrow)
            // Вместо бесполезной иконки — сама дата; тап по ней = «Сегодня».
            Expanded(
              child: TextButton(
                onPressed: () => goToday(ref),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                child: const _PeriodTitle(),
              ),
            )
          else ...[
            IconButton(
                onPressed: () => shiftFocused(ref, -1),
                icon: const Icon(Icons.chevron_left)),
            OutlinedButton(
                onPressed: () => goToday(ref),
                child: Text(L10n.of(context).calToday)),
            IconButton(
                onPressed: () => shiftFocused(ref, 1),
                icon: const Icon(Icons.chevron_right)),
            const SizedBox(width: 6),
            const _PeriodTitle(),
            const SizedBox(width: 12),
            // Поиск событий по названию/участнику/id — единственный Expanded,
            // тянется на всю свободную длину; правый кластer (Д/Н/М, синк, меню)
            // прижат к правому краю без «дыры».
            const Expanded(child: _EventSearch()),
            const SizedBox(width: 8),
          ],
          // Ожидающие правки — между датой и Д/Н/М (если ширина позволяет).
          if (wideForPending && pendingN > 0) const _PendingInline(),
          switcher,
          const SizedBox(width: 4),
          const _SyncStatus(),
          // Быстрый переключатель «открепить встречи» (перенос перетаскиванием).
          // Только на мобиле: на десктопе «закреп» не нужен (нет ложных нажатий),
          // режим перетаскивания/ресайза включён по умолчанию, тумблер скрыт.
          if (isMobilePlatform)
            Builder(builder: (_) {
              final moveMode = ref.watch(moveModeProvider);
              return IconButton(
                style: _compactIconStyle,
                tooltip: moveMode
                    ? L10n.of(context).calPinEvents
                    : L10n.of(context).calUnpinEvents,
                isSelected: moveMode,
                onPressed: () =>
                    ref.read(moveModeProvider.notifier).state = !moveMode,
                icon: const Icon(Icons.push_pin_outlined),
                selectedIcon: const Icon(Icons.open_with),
              );
            }),
          if (!narrow) ...[
            // Склейка дублей из разных календарей: отжать — и каждая встреча
            // показывается отдельно (можно работать с каждой копией).
            Builder(builder: (_) {
              final combine = ref.watch(combineProvider);
              return IconButton(
                style: _compactIconStyle,
                tooltip: combine
                    ? L10n.of(context).calCombineOn
                    : L10n.of(context).calCombineOff,
                isSelected: combine,
                onPressed: () =>
                    ref.read(combineProvider.notifier).state = !combine,
                icon: const Icon(Icons.layers_clear_outlined),
                selectedIcon: const Icon(Icons.layers),
              );
            }),
            IconButton(
              style: _compactIconStyle,
              tooltip: L10n.of(context).calShowCancelled,
              isSelected: showCancelled,
              onPressed: () => ref.read(showCancelledProvider.notifier).state =
                  !showCancelled,
              icon: const Icon(Icons.event_busy_outlined),
              selectedIcon: const Icon(Icons.event_busy),
            ),
          ],
          menu,
        ],
      ),
    );
  }
}

/// Заголовок периода: в дне — «ср, 17 июн», в неделе — «14–20 июн»,
/// в месяце — «июнь 2026». Чётко показывает, на что смотрит пользователь.
class _PeriodTitle extends ConsumerWidget {
  const _PeriodTitle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);
    final d = ref.watch(focusedDateProvider);
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;

    // Форматирование по активной локали (intl) — символы дат грузит
    // GlobalMaterialLocalizations при установленной локали MaterialApp.
    final loc = Localizations.localeOf(context).toString();
    final dayMon = DateFormat.MMMd(loc); // «17 июн» / «Jun 17»
    String text;
    switch (mode) {
      case CalendarViewMode.day:
        text = DateFormat.MMMEd(loc).format(d); // «ср, 17 июн» / «Wed, Jun 17»
        if (isToday) text = '${L10n.of(context).calToday} · $text';
      case CalendarViewMode.week:
        final s = weekStart(d);
        final e = s.add(const Duration(days: 6));
        text = '${dayMon.format(s)} – ${dayMon.format(e)}';
      default:
        text = DateFormat.yMMMM(loc).format(d); // «июнь 2026» / «June 2026»
    }
    return Text(text,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }
}
