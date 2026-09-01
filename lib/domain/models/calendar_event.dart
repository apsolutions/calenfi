import 'attendee.dart';
import 'conference.dart';
import 'enums.dart';
import 'reminder.dart';

/// Откуда событие пришло и как записать его обратно (FR-S4).
class EventSource {
  const EventSource({
    required this.accountId,
    required this.calendarId,
    this.providerEventId,
    this.etag,
  });

  final String accountId;
  final String calendarId;

  /// Id события в источнике (для update/delete).
  final String? providerEventId;

  /// ETag / changeKey для контроля конфликтов (FR-S5).
  final String? etag;

  EventSource copyWith({
    String? accountId,
    String? calendarId,
    String? providerEventId,
    String? etag,
  }) => EventSource(
    accountId: accountId ?? this.accountId,
    calendarId: calendarId ?? this.calendarId,
    providerEventId: providerEventId ?? this.providerEventId,
    etag: etag ?? this.etag,
  );
}

/// Событие календаря.
///
/// Время храним в UTC + явный IANA timezone id; пересчёт в выбранную таймзону
/// — на уровне отображения (FR-V7). Имя [CalendarEvent], чтобы не конфликтовать
/// с `Event` из фреймворка.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    this.timeZoneId = 'UTC',
    this.allDay = false,
    this.location,
    this.description,
    this.recurrenceRule,
    this.recurrenceId,
    this.attendees = const [],
    this.myResponse = ResponseStatus.organizer,
    this.showAs = ShowAs.busy,
    this.visibility = EventVisibility.defaultVis,
    this.reminders = const [],
    this.conference,
    required this.source,
    this.status = EventStatus.confirmed,
    this.deletedRemotely = false,
    this.colorOverride,
    this.mergedGroupId,
    this.webUrl,
  });

  /// Локальный id.
  final String id;
  final String calendarId;

  /// iCalendar UID — усиливающий сигнал для дедупа (FR-D2).
  String? get providerUid => source.providerEventId;

  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final String timeZoneId;
  final bool allDay;
  final String? location;
  final String? description;

  /// RRULE мастер-серии (FR-E6).
  final String? recurrenceRule;

  /// Идентификатор экземпляра внутри серии.
  final String? recurrenceId;

  final List<Attendee> attendees;
  final ResponseStatus myResponse;
  final ShowAs showAs;
  final EventVisibility visibility;
  final List<Reminder> reminders;
  final Conference? conference;
  final EventSource source;

  /// Статус в источнике; cancelled показывается при включённом тумблере (FR-V12).
  final EventStatus status;

  /// Удалено в источнике, но удержано локально для показа (FR-V12).
  final bool deletedRemotely;

  /// Переопределение цвета (иначе берётся цвет календаря).
  final int? colorOverride;

  /// Если событие склеено с дублями — id группы (FR-D).
  final String? mergedGroupId;

  /// Готовая web-ссылка на событие в облаке (Yandex URL / Google htmlLink /
  /// Graph webLink) — кликабельна в карточке.
  final String? webUrl;

  /// Переговорка (ресурс-участник) — отдельная категория, сосуществует с
  /// людьми и видеовстречей. null, если комната не забронирована.
  Attendee? get room {
    for (final a in attendees) {
      if (a.isResource) return a;
    }
    return null;
  }

  /// Участники-люди (без ресурс-комнат), с дедупом по email: источник
  /// (Exchange/Graph) иногда присылает одного человека дважды — required+optional
  /// или два алиаса — из-за чего он показывался в карточке дважды.
  List<Attendee> get people {
    final seen = <String>{};
    final out = <Attendee>[];
    for (final a in attendees) {
      if (a.isResource) continue;
      final key = a.email.trim().toLowerCase();
      if (key.isNotEmpty && !seen.add(key)) {
        continue; // дубль по email — пропуск
      }
      out.add(a);
    }
    return out;
  }

  /// Копия с новым локальным id для ещё не созданного события.
  /// До первого push тот же UUID используется как временный provider id.
  CalendarEvent withId(String newId) => _withLocalId(
    newId,
    EventSource(
      accountId: source.accountId,
      calendarId: source.calendarId,
      providerEventId: newId,
      etag: source.etag,
    ),
  );

  /// Меняет только локальный id, не трогая адрес/id ресурса
  /// в провайдере. Нужно, когда адаптер канонизирует локальный ключ.
  CalendarEvent withLocalId(String newId) => _withLocalId(newId, source);

  CalendarEvent _withLocalId(String newId, EventSource newSource) =>
      CalendarEvent(
        id: newId,
        calendarId: calendarId,
        title: title,
        startUtc: startUtc,
        endUtc: endUtc,
        timeZoneId: timeZoneId,
        allDay: allDay,
        location: location,
        description: description,
        recurrenceRule: recurrenceRule,
        recurrenceId: recurrenceId,
        attendees: attendees,
        myResponse: myResponse,
        showAs: showAs,
        visibility: visibility,
        reminders: reminders,
        conference: conference,
        source: newSource,
        status: status,
        deletedRemotely: deletedRemotely,
        colorOverride: colorOverride,
        mergedGroupId: mergedGroupId,
        webUrl: webUrl,
      );

  bool get isCancelled => status == EventStatus.cancelled || deletedRemotely;

  bool get isInvitePending => myResponse == ResponseStatus.needsAction;

  /// Событие — часть повторяющейся серии (мастер с RRULE или экземпляр,
  /// привязанный к серии). Определяет, спрашивать ли область удаления/правки.
  bool get isRecurring => recurrenceRule != null || recurrenceId != null;

  CalendarEvent copyWith({
    String? title,
    DateTime? startUtc,
    DateTime? endUtc,
    String? timeZoneId,
    bool? allDay,
    String? location,
    String? description,
    String? recurrenceRule,
    List<Attendee>? attendees,
    ResponseStatus? myResponse,
    ShowAs? showAs,
    EventVisibility? visibility,
    List<Reminder>? reminders,
    Conference? conference,
    EventStatus? status,
    bool? deletedRemotely,
    int? colorOverride,
    String? mergedGroupId,
    EventSource? source,
    String? webUrl,
  }) => CalendarEvent(
    id: id,
    calendarId: calendarId,
    title: title ?? this.title,
    startUtc: startUtc ?? this.startUtc,
    endUtc: endUtc ?? this.endUtc,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    allDay: allDay ?? this.allDay,
    location: location ?? this.location,
    description: description ?? this.description,
    recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    recurrenceId: recurrenceId,
    attendees: attendees ?? this.attendees,
    myResponse: myResponse ?? this.myResponse,
    showAs: showAs ?? this.showAs,
    visibility: visibility ?? this.visibility,
    reminders: reminders ?? this.reminders,
    conference: conference ?? this.conference,
    source: source ?? this.source,
    webUrl: webUrl ?? this.webUrl,
    status: status ?? this.status,
    deletedRemotely: deletedRemotely ?? this.deletedRemotely,
    colorOverride: colorOverride ?? this.colorOverride,
    mergedGroupId: mergedGroupId ?? this.mergedGroupId,
  );
}
