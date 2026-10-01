// Складной телефон (Galaxy Z Fold 7): у одного приложения два экрана.
// Внешний — 411×960 точек, обычный телефон. Внутренний — 750×832, почти
// квадрат: для него десктопная верхняя панель была слишком широкой, поле
// поиска сжималось в ноль, а кнопка настроек уезжала за правый край.
//
// Размеры взяты с устройства: 1080×2520 и 1968×2184 пикселей при 420 dpi.
//
// Снимки для просмотра глазами (не эталоны):
//   FOLD_SHOTS=/tmp/shots flutter test --update-goldens test/fold_layout_test.dart
import 'dart:io';

import 'package:calenfi/app/providers.dart';
import 'package:calenfi/app/theme.dart';
import 'package:calenfi/app/window_class.dart';
import 'package:calenfi/data/repositories/event_repository.dart';
import 'package:calenfi/domain/models/account.dart';
import 'package:calenfi/domain/models/calendar.dart';
import 'package:calenfi/domain/models/calendar_event.dart';
import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/models/merged_event.dart';
import 'package:calenfi/features/calendar/calendar_screen.dart';
import 'package:calenfi/features/calendar/calendar_state.dart';
import 'package:calenfi/features/calendar/day_view.dart';
import 'package:calenfi/features/calendar/pending_edits.dart';
import 'package:calenfi/features/calendar/time_grid.dart';
import 'package:calenfi/features/event_editor/event_editor_screen.dart';
import 'package:calenfi/l10n/app_localizations.dart';
import 'package:calenfi/sync/sync_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _IdleSyncEngine implements SyncEngine {
  @override
  Stream<int> get activeStream => const Stream<int>.empty();
  @override
  int get activeCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Неотправленные правки без таймеров и базы: только счётчик для панели.
class _StaticPending extends PendingEditsNotifier {
  _StaticPending(int n) : super(_FakeEventRepository(), _IdleSyncEngine()) {
    state = {
      for (var i = 0; i < n; i++)
        'p$i': PendingEdit(
            deadline: DateTime.now().add(const Duration(minutes: 2)),
            op: 'update'),
    };
  }
}

/// Настоящий Roboto вместо тестового шрифта с квадратными глифами: иначе
/// ширина подписей завышена в полтора раза и тест ловит переполнения,
/// которых на устройстве нет.
bool _realFonts = false;

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!File('${dir.path}/Roboto-Regular.ttf').existsSync()) return;
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${dir.path}/$name').readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf'))
        ..addFont(read('Roboto-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(read('MaterialIcons-Regular.otf')))
      .load();
  _realFonts = true;
}

/// Проверки «помещается ли» имеют смысл только с настоящим шрифтом. Если в
/// кэше Flutter его нет, тест пропускается, а не падает на квадратных глифах.
bool _skipWithoutFonts() {
  if (_realFonts) return false;
  markTestSkipped('нет Roboto в кэше Flutter: ширину подписей не проверить');
  return true;
}

const _dpr = 2.625; // 420 dpi
const _cover = Size(411.4, 960);
const _coverLandscape = Size(960, 411.4);
const _inner = Size(749.7, 832);
const _innerLandscape = Size(832, 749.7);

void main() {
  setUpAll(_loadFonts);

  final day = DateTime(2026, 10, 1); // четверг
  MergedEvent ev(String id, int h, int m, int dur, String title,
      {int dayOffset = 0}) {
    final s = DateTime(2026, 10, 1 + dayOffset, h, m);
    final e = CalendarEvent(
      id: id,
      calendarId: 'c1',
      title: title,
      startUtc: s.toUtc(),
      endUtc: s.add(Duration(minutes: dur)).toUtc(),
      source: const EventSource(accountId: 'a1', calendarId: 'c1'),
    );
    return MergedEvent(groupId: id, primary: e, sources: [e]);
  }

  final events = [
    ev('e1', 11, 0, 60, 'Планёрка команды'),
    ev('e2', 12, 30, 30, 'Weekly sync'),
    ev('e3', 14, 0, 45, 'Статус проекта и планирование ресурсов'),
    ev('e4', 17, 0, 60, 'Демо'),
    ev('e5', 10, 0, 90, 'Обсуждение плана на квартал', dayOffset: 1),
    ev('e6', 15, 0, 60, 'Созвон', dayOffset: -1),
  ];

  List<Account> accounts({required bool broken}) => [
        for (var i = 0; i < 5; i++)
          Account(
            id: 'a$i',
            provider: ProviderType.google,
            displayName: 'Account $i',
            email: 'a$i@example.test',
            status: broken && i == 3 ? AccountStatus.offline : AccountStatus.ok,
            lastSyncUtc: DateTime.now().toUtc(),
          ),
      ];

  late ProviderContainer container;
  late List<String> layoutErrors;

  void setSize(WidgetTester tester, Size dp) {
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = dp * _dpr;
  }

  /// Несколько кадров вместо pumpAndSettle: минутные часы календаря и
  /// секундный отсчёт неотправленных правок не дают дереву «успокоиться».
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Size dp, {
    CalendarViewMode? mode,
    bool broken = false,
    int pending = 0,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    setSize(tester, dp);
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = platform;

    // Ошибки вёрстки первого кадра собираем сами, чтобы назвать их в отчёте.
    // Перехват снимаем сразу после кадров: упавшая проверка при подменённом
    // обработчике превращается в невнятное «тест не вернул FlutterError».
    layoutErrors = [];
    final previous = FlutterError.onError;
    FlutterError.onError =
        (d) => layoutErrors.add(d.exceptionAsString().split('\n').first);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          focusedDateProvider.overrideWith((ref) => day),
          if (mode != null) viewModeProvider.overrideWith((ref) => mode),
          syncEngineProvider.overrideWithValue(_IdleSyncEngine()),
          accountsStreamProvider
              .overrideWith((ref) => Stream.value(accounts(broken: broken))),
          mergedEventsProvider.overrideWith((ref) => Stream.value(events)),
          dayEventsProvider.overrideWith((ref, d) => Stream.value(events
              .where((e) => e.primary.startUtc.toLocal().day == d.day)
              .toList())),
          calendarColorsProvider
              .overrideWith((ref) => Stream.value({'c1': 0xFF3F8EFC})),
          calendarsListProvider.overrideWith((ref) => Stream.value(const [
                Calendar(
                    id: 'c1', accountId: 'a1', name: 'Рабочий', color: 0xFF3F8EFC)
              ])),
          pendingEditsProvider.overrideWith((ref) => _StaticPending(pending)),
        ],
        child: Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildDarkTheme(),
            locale: const Locale('ru'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: const CalendarScreen(),
          );
        }),
      ),
    );
    await frames(tester);
    FlutterError.onError = previous;
  }

  /// Платформу возвращаем в конце тела теста: проверка инвариантов после
  /// теста требует, чтобы подмена была снята.
  void restorePlatform() => debugDefaultTargetPlatformOverride = null;

  Future<void> shot(String name) async {
    final dir = Platform.environment['FOLD_SHOTS'];
    if (dir == null) return;
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('$dir/$name.png'));
  }

  test('классы ширины: внешний экран узкий, внутренний средний', () {
    expect(windowClassForWidth(_cover.width), WindowClass.compact);
    expect(windowClassForWidth(_inner.width), WindowClass.medium);
    expect(windowClassForWidth(_innerLandscape.width), WindowClass.medium);
    // Половина внутреннего экрана в режиме разделения — снова телефон.
    expect(windowClassForWidth(372), WindowClass.compact);
    expect(windowClassForWidth(1280), WindowClass.expanded);
  });

  const sizes = {
    'cover-portrait': _cover,
    'cover-landscape': _coverLandscape,
    'inner-portrait': _inner,
    'inner-landscape': _innerLandscape,
    'inner-split-half': Size(372, 832),
    'popup-window': Size(320, 520),
    'medium-lower-bound': Size(600, 800),
    'desktop-900': Size(900, 700),
    'desktop-1280': Size(1280, 800),
  };

  for (final entry in sizes.entries) {
    for (final mode in const [
      CalendarViewMode.day,
      CalendarViewMode.week,
      CalendarViewMode.month,
    ]) {
      // «Нагрузка» — самая широкая верхняя панель: один аккаунт не обновился
      // (счётчик «4/5 · время» и восклицательный знак) плюс неотправленные
      // правки.
      for (final stress in const [false, true]) {
        testWidgets(
            '${entry.key}, ${mode.name}${stress ? ', сбой синка и правки' : ''}: '
            'ничего не вылезает за край', (tester) async {
          if (_skipWithoutFonts()) return;
          await pumpScreen(tester, entry.value,
              mode: mode, broken: stress, pending: stress ? 2 : 0);
          await shot('${entry.key}-${mode.name}${stress ? '-stress' : ''}');

          expect(layoutErrors, isEmpty);
          // Кнопка настроек целиком на экране: через неё подключаются и
          // чинятся учётные записи.
          final menu = tester.getRect(find.byIcon(Icons.more_vert));
          expect(menu.right, lessThanOrEqualTo(entry.value.width));
          expect(menu.left, greaterThanOrEqualTo(0));
          restorePlatform();
        });
      }
    }
  }

  testWidgets('внутренний экран: поиск открывается кнопкой и закрывается',
      (tester) async {
    if (_skipWithoutFonts()) return;
    await pumpScreen(tester, _inner, mode: CalendarViewMode.week);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('top-bar-search')));
    await frames(tester);
    await shot('inner-portrait-search');

    expect(find.byType(TextField), findsOneWidget);
    // Поле занимает всю строку, а не остаток после кнопок.
    expect(tester.getSize(find.byType(TextField)).width, greaterThan(600));
    expect(layoutErrors, isEmpty);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await frames(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(layoutErrors, isEmpty);
    restorePlatform();
  });

  testWidgets('раскрыл — неделя, сложил — день, и у каждого экрана своя память',
      (tester) async {
    await pumpScreen(tester, _cover);
    expect(container.read(viewModeProvider), CalendarViewMode.day);

    setSize(tester, _inner);
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.week);

    // На внутреннем экране выбрали месяц, на внешнем — неделю.
    container.read(viewModeProvider.notifier).state = CalendarViewMode.month;
    await frames(tester);
    setSize(tester, _cover);
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.day);
    container.read(viewModeProvider.notifier).state = CalendarViewMode.week;
    await frames(tester);

    setSize(tester, _inner);
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.month);

    setSize(tester, _cover);
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.week);

    // Поворот внутреннего экрана вид не меняет: класс ширины тот же.
    setSize(tester, _inner);
    await frames(tester);
    setSize(tester, _innerLandscape);
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.month);
    expect(layoutErrors, isEmpty);
    restorePlatform();
  });

  testWidgets('на десктопе сужение окна вид не переключает', (tester) async {
    await pumpScreen(tester, const Size(1280, 800),
        platform: TargetPlatform.linux);
    container.read(viewModeProvider.notifier).state = CalendarViewMode.month;
    await frames(tester);

    setSize(tester, const Size(500, 800));
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.month);

    setSize(tester, const Size(1280, 800));
    await frames(tester);
    expect(container.read(viewModeProvider), CalendarViewMode.month);
    restorePlatform();
  });

  testWidgets('редактор: на низком экране во весь экран, на внутреннем — окном',
      (tester) async {
    if (_skipWithoutFonts()) return;
    await pumpScreen(tester, _coverLandscape, mode: CalendarViewMode.week);
    await tester.tap(find.byType(FloatingActionButton));
    await frames(tester);
    await shot('cover-landscape-editor');
    expect(tester.getSize(find.byType(EventEditorScreen)).height,
        greaterThan(_coverLandscape.height - 80));
    expect(layoutErrors, isEmpty);
    await tester.pumpWidget(const SizedBox());

    await pumpScreen(tester, _inner, mode: CalendarViewMode.week);
    await tester.tap(find.byType(FloatingActionButton));
    await frames(tester);
    await shot('inner-portrait-editor');
    expect(tester.getSize(find.byType(EventEditorScreen)), const Size(480, 660));
    expect(layoutErrors, isEmpty);
    restorePlatform();
  });

  // Жалоба: «просил писать в недельной вёрстке дату + день в одну строчку,
  // чтобы не тратить место». Было два этажа на 56 точек: «ПН» над «28».
  testWidgets('шапка недели: день и число одной строкой на обоих экранах',
      (tester) async {
    if (_skipWithoutFonts()) return;
    for (final size in const [_cover, _inner]) {
      await pumpScreen(tester, size);
      // На узком экране приложение стартует с дня — неделю выбираем явно.
      container.read(viewModeProvider.notifier).state = CalendarViewMode.week;
      await frames(tester);
      final cells = find.byType(DayHeaderCell);
      expect(cells, findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        final texts = find.descendant(of: cells.at(i), matching: find.byType(Text));
        expect(texts, findsNWidgets(2));
        final weekday = tester.getRect(texts.at(0));
        final number = tester.getRect(texts.at(1));
        expect(weekday.right, lessThanOrEqualTo(number.left),
            reason: 'число стоит правее дня недели, а не под ним');
        expect((weekday.center.dy - number.center.dy).abs(), lessThan(3));
      }
      expect(find.text('ЧТ'), findsOneWidget);
      // Вся строка с днями — 30 точек над сеткой.
      final grid = tester.getTopLeft(find.byType(TimeGrid)).dy;
      final header = tester.getTopLeft(cells.first).dy;
      expect(grid - header, lessThan(kDayHeaderHeight + 2));
      expect(layoutErrors, isEmpty);
      await shot('week-header-${size == _cover ? 'cover' : 'inner'}');
      await tester.pumpWidget(const SizedBox());
    }
    restorePlatform();
  });

  test('домашний виджет растягивается на ширину внутреннего экрана', () {
    final info = File('android/app/src/main/res/xml/agenda_widget_info.xml')
        .readAsStringSync();
    final attributes = info.substring(info.indexOf('<appwidget-provider'));
    expect(attributes, isNot(contains('maxResizeWidth')));
    expect(attributes, isNot(contains('maxResizeHeight')));
    expect(attributes, contains('android:resizeMode="horizontal|vertical"'));
  });
}
