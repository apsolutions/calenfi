import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../domain/models/calendar.dart';
import '../domain/models/calendar_event.dart';
import '../domain/models/merged_event.dart';
import 'diag_log.dart';

/// Локальные уведомления-напоминания о начале встреч (FR-N).
///
/// Эффективное напоминание события: его собственные `reminders`, иначе дефолт
/// календаря (`defaultReminderMinutes`), иначе — ничего. В пуш кладём ссылку на
/// подключение (если встреча онлайн); тап/кнопка «Подключиться» открывают её.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'calenfi_event_reminders';
  static const _channelName = 'Напоминания о встречах';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Инициализация плагина, канала и запрос разрешения. Идемпотентно.
  /// Таймзоны инициализируются в main (`tzdata.initializeTimeZones`).
  ///
  /// [askPermission] = false — для фоновой синхронизации: экрана нет, и окно
  /// с вопросом о разрешении показать некому.
  Future<void> init({bool askPermission = true}) async {
    if (!_supported || _ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );

    final android13 = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (askPermission) await android13?.requestNotificationsPermission();
    await android13?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Напоминания о начале встреч',
      importance: Importance.max,
    ));
    _ready = true;
  }

  static const _loginChannelId = 'calenfi_login';
  static const _loginNotificationId = 0x7fffff01;

  /// Держит процесс приложения живым, пока человек входит в учётную запись
  /// в браузере.
  ///
  /// Ответ браузера принимает локальный сервер внутри приложения. Android
  /// замораживает приложение примерно через минуту после того, как поверх
  /// открылся браузер, и страница «Вы пытаетесь войти в Calenfi?» висела,
  /// пока человек не догадывался вернуться в приложение. Процесс со службой
  /// переднего плана система не замораживает и не отрезает от сети.
  ///
  /// Возвращает false, если службу поднять не удалось: вход всё равно идёт,
  /// просто без этой страховки.
  Future<bool> startLoginKeepAlive() async {
    if (!_supported) return false;
    try {
      if (!_ready) await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      await android.startForegroundService(
        _loginNotificationId,
        'Calenfi: вход в учётную запись',
        'Завершите вход в браузере. Нажмите, чтобы вернуться в Calenfi.',
        notificationDetails: const AndroidNotificationDetails(
          _loginChannelId,
          'Вход в учётную запись',
          channelDescription:
              'Показывается, пока идёт вход через браузер, чтобы система не '
              'останавливала Calenfi',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
        ),
        startType: AndroidServiceStartType.startNotSticky,
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeDataSync,
        },
      );
      DiagLog.instance.add('login', 'служба переднего плана запущена');
      return true;
    } on Object catch (e, st) {
      DiagLog.instance
          .error('login', 'службу переднего плана запустить не удалось', e, st);
      return false;
    }
  }

  /// Останавливает службу, запущенную [startLoginKeepAlive].
  Future<void> stopLoginKeepAlive() async {
    if (!_supported) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    } on Object catch (e, st) {
      DiagLog.instance
          .error('login', 'службу переднего плана остановить не удалось', e, st);
    }
  }

  static void _onTap(NotificationResponse r) {
    final url = r.payload;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Пересобирает расписание уведомлений под ближайшие события.
  ///
  /// [events] — склеенные события (берём primary), [calsById] — для дефолтного
  /// напоминания календаря. Планируем только будущие срабатывания, не дальше
  /// [horizon] и не более [maxScheduled] штук (лимит системных алармов).
  Future<void> sync(
    List<MergedEvent> events,
    Map<String, Calendar> calsById,
    DateTime now, {
    Duration horizon = const Duration(days: 7),
    int maxScheduled = 64,
    bool askPermission = true,
  }) async {
    if (!_supported) return;
    if (!_ready) await init(askPermission: askPermission);

    await _plugin.cancelAll();
    final until = now.add(horizon);

    // Собираем все будущие срабатывания (событие × оффсет напоминания).
    final jobs = <_Job>[];
    for (final m in events) {
      final e = m.primary;
      if (e.allDay || e.isCancelled) continue;
      final offsets = _effectiveOffsets(e, calsById[e.calendarId]);
      for (final off in offsets) {
        final fireAt = e.startUtc.subtract(off);
        if (fireAt.isAfter(now) && fireAt.isBefore(until)) {
          jobs.add(_Job(e, fireAt, off));
        }
      }
    }
    jobs.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    var id = 0;
    for (final job in jobs.take(maxScheduled)) {
      await _scheduleOne(id++, job, now);
    }
  }

  /// Напоминания события: собственные, иначе дефолт календаря, иначе — нет.
  static List<Duration> _effectiveOffsets(CalendarEvent e, Calendar? cal) {
    if (e.reminders.isNotEmpty) {
      return e.reminders.map((r) => r.before).toList();
    }
    final d = cal?.defaultReminderMinutes;
    if (d != null) return [Duration(minutes: d)];
    return const [];
  }

  Future<void> _scheduleOne(int id, _Job job, DateTime now) async {
    final e = job.event;
    final localStart = e.startUtc.toLocal();
    final hm = '${localStart.hour.toString().padLeft(2, '0')}:'
        '${localStart.minute.toString().padLeft(2, '0')}';
    final joinUrl = e.conference?.joinUrl;

    final lead = job.offset == Duration.zero
        ? 'Сейчас начнётся'
        : 'Через ${_humanOffset(job.offset)}';
    final bodyParts = <String>['$lead · $hm'];
    if (e.location != null && e.location!.trim().isNotEmpty) {
      bodyParts.add(e.location!.trim());
    }
    if (joinUrl != null) bodyParts.add(joinUrl);

    final actions = <AndroidNotificationAction>[
      if (joinUrl != null)
        const AndroidNotificationAction('join', 'Подключиться',
            showsUserInterface: true),
    ];

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Напоминания о начале встреч',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.event,
      styleInformation: BigTextStyleInformation(bodyParts.join('\n')),
      actions: actions,
    );

    await _plugin.zonedSchedule(
      id,
      e.title.isEmpty ? '(без названия)' : e.title,
      bodyParts.join(' · '),
      // Абсолютный момент: событие хранится в UTC, планируем по UTC —
      // срабатывает в правильное время независимо от зоны/DST.
      tz.TZDateTime.from(job.fireAt.toUtc(), tz.UTC),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: joinUrl,
    );
  }

  static String _humanOffset(Duration d) {
    final m = d.inMinutes;
    if (m % 60 == 0 && m >= 60) return '${m ~/ 60} ч';
    return '$m мин';
  }
}

class _Job {
  _Job(this.event, this.fireAt, this.offset);
  final CalendarEvent event;
  final DateTime fireAt;
  final Duration offset;
}
