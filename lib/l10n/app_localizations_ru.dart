// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class L10nRu extends L10n {
  L10nRu([String locale = 'ru']) : super(locale);

  @override
  String get accAddAccount => 'Добавить учётную запись';

  @override
  String get accAppPassword => 'Пароль приложения';

  @override
  String get accAppPasswordHelper =>
      'НЕ основной пароль почты — создайте пароль приложения';

  @override
  String get accAutoRefresh => 'Автообновление';

  @override
  String get accCaldavPasswordHelper =>
      'Для CalDAV — пароль приложения, не основной пароль почты';

  @override
  String get accCancel => 'Отмена';

  @override
  String get accChangePassword => 'Изменить пароль';

  @override
  String accCompleteSignIn(String name) {
    return '$name: завершите вход в открывшемся браузере…';
  }

  @override
  String get accConnect => 'Подключить';

  @override
  String get accConnectAccount => 'Подключить учётную запись';

  @override
  String accConnected(String email) {
    return 'Подключено: $email';
  }

  @override
  String get accConnecting => 'Подключаю…';

  @override
  String get accDelete => 'Удалить';

  @override
  String get accEmail => 'E-mail';

  @override
  String accError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get accEwsUrlLabel => 'EWS URL (необязательно)';

  @override
  String accFailed(String error) {
    return 'Не удалось: $error';
  }

  @override
  String get accFillEmailPassword => 'Заполните e-mail и пароль';

  @override
  String get accHidden => 'скрыт';

  @override
  String get accHost => 'Хост';

  @override
  String get accHour1 => '1 час';

  @override
  String get accLoginIfDifferent => 'Логин (если отличается)';

  @override
  String get accLoginPassword => 'Логин и пароль';

  @override
  String get accManual => 'Вручную';

  @override
  String accMinutes(int count) {
    return '$count мин';
  }

  @override
  String get accNewPassword => 'Новый пароль';

  @override
  String get accNoCalendars => 'Нет календарей';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return 'Вход в $name не настроен';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return 'В этой сборке Calenfi нет OAuth-клиента $name, поэтому вход через браузер не может начаться. Введите данные своего OAuth-приложения (redirect URI http://localhost), они сохранятся в защищённом хранилище устройства.';
  }

  @override
  String get accOAuthClientId => 'Client ID';

  @override
  String get accOAuthClientSecret => 'Client secret';

  @override
  String get accSaveAndSignIn => 'Сохранить и войти';

  @override
  String get accPassword => 'Пароль';

  @override
  String get accPasswordSaved => 'Пароль сохранён, синхронизирую…';

  @override
  String get accReconnect => 'Переподключить';

  @override
  String get accPort => 'Порт';

  @override
  String get accSave => 'Сохранить';

  @override
  String get accSectionCalendars => 'Календари';

  @override
  String get accSectionVideoMeetings => 'Видеовстречи';

  @override
  String get accSignInBrowser => 'Вход через браузер';

  @override
  String get accStatusAuthError => 'ошибка авторизации';

  @override
  String get accStatusNeedsReconnect => 'требуется переподключение';

  @override
  String get accStatusOffline => 'нет сети';

  @override
  String get accStatusOk => 'подключён';

  @override
  String get accStatusSyncError => 'сбой синхронизации';

  @override
  String get accTitle => 'Учётные записи';

  @override
  String get accVisibilityHint =>
      'Видимость календарей — в Настройки → Календари';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => 'Отменить';

  @override
  String get calCombineOff =>
      'Объединять одинаковые встречи (выкл — каждая отдельно)';

  @override
  String get calCombineOn => 'Объединять одинаковые встречи (вкл)';

  @override
  String get calDay => 'День';

  @override
  String get calDayShort => 'Д';

  @override
  String get calMonth => 'Месяц';

  @override
  String get calMonthShort => 'М';

  @override
  String get calMoveModeHint => 'Режим переноса: тяните встречи. Тап — детали.';

  @override
  String get calNoTitle => 'Без названия';

  @override
  String get calNothingFound => 'Ничего не найдено';

  @override
  String calPendingCount(int count) {
    return 'Не отправлено в облако: $count';
  }

  @override
  String get calPinEvents => 'Закрепить встречи';

  @override
  String calSearchFound(int count) {
    return 'Найдено: $count';
  }

  @override
  String get calSearchHint => 'Поиск: название, участник, id';

  @override
  String get calSettings => 'Настройки';

  @override
  String get calShowCancelled => 'Показать удалённые/отменённые';

  @override
  String get calSortDate => 'Дата';

  @override
  String get calSortRelevance => 'Релевантность';

  @override
  String get calSynced => 'Синхронизировано';

  @override
  String get calToCloud => 'В облако';

  @override
  String get calToday => 'Сегодня';

  @override
  String get calUnpinEvents => 'Открепить встречи (перенос перетаскиванием)';

  @override
  String get calViewInDev => 'Вид в разработке';

  @override
  String get calWeek => 'Неделя';

  @override
  String get calWeekShort => 'Н';

  @override
  String get detAccept => 'Принять';

  @override
  String get detAllDay => 'весь день';

  @override
  String get detAttendeeCopied => 'Участник скопирован';

  @override
  String detAttendeesCount(int total, int accepted) {
    String _temp0 = intl.Intl.pluralLogic(
      accepted,
      locale: localeName,
      other: 'приняли',
      one: 'принял',
    );
    return 'Участники: $total  ·  $_temp0 $accepted';
  }

  @override
  String get detCancel => 'Отмена';

  @override
  String get detCancelledDeleted => 'Отменено / удалено';

  @override
  String get detConfVideoCall => 'видеовстреча';

  @override
  String get detCopied => 'Скопировано';

  @override
  String get detCopy => 'Скопировать';

  @override
  String get detDecline => 'Отклонить';

  @override
  String get detDelete => 'Удалить';

  @override
  String get detDeleteEventQ => 'Удалить событие?';

  @override
  String get detEdit => 'Изменить';

  @override
  String get detEditTitle => 'Изменить название';

  @override
  String detFieldCopied(String label) {
    return '$label скопирован';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return 'В нескольких календарях ($count):';
  }

  @override
  String detJoin(String label) {
    return 'Присоединиться · $label';
  }

  @override
  String get detMeetingLinkCopied => 'Ссылка на встречу скопирована';

  @override
  String get detAttachments => 'Вложения';

  @override
  String get detOpenInCloud => 'Открыть в облаке';

  @override
  String get detOptional => 'необязателен';

  @override
  String get detOrganizer => 'организатор';

  @override
  String get detRecurringWhatDelete => 'Повторяющееся событие — что удалить?';

  @override
  String get detRecurringWhatEdit => 'Повторяющееся событие — что изменить?';

  @override
  String get detEditWholeSeries => 'Всю серию (все вхождения)';

  @override
  String get detResponseAccepted => 'Принято';

  @override
  String get detResponseDeclined => 'Отклонено';

  @override
  String get detResponseNeedsAction => 'Ожидает ответа';

  @override
  String get detResponseOrganizer => 'Вы организатор';

  @override
  String get detResponseTentative => 'Под вопросом';

  @override
  String get detSave => 'Сохранить';

  @override
  String get detTentative => 'Под вопросом';

  @override
  String get detThisAndFollowing => 'Это и последующие';

  @override
  String get detThisEventOnly => 'Только это событие';

  @override
  String get detTitleChanged => 'Название изменено';

  @override
  String get detUnknownCalendar => 'Неизвестный календарь';

  @override
  String get detWholeSeries => 'Всю серию';

  @override
  String get edAllDay => 'Весь день';

  @override
  String get edAttendees => 'Участники';

  @override
  String get edBusy => 'Занят';

  @override
  String get edCalendar => 'Календарь';

  @override
  String get edCancel => 'Отмена';

  @override
  String get edChoose => 'выбрать…';

  @override
  String get edConference => 'Видеовстреча';

  @override
  String get edConnectAccount => 'Подключить аккаунт';

  @override
  String get edDaily => 'Ежедневно';

  @override
  String get edDoNotRepeat => 'Не повторять';

  @override
  String get edDone => 'Готово';

  @override
  String get edEditEvent => 'Изменить событие';

  @override
  String get edEnd => 'Конец';

  @override
  String get edEndAfter => 'Завершить после';

  @override
  String get edEvery => 'Каждые';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count дней',
      many: 'Каждые $count дней',
      few: 'Каждые $count дня',
      one: 'Каждый $count день',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count месяцев',
      many: 'Каждые $count месяцев',
      few: 'Каждые $count месяца',
      one: 'Каждый $count месяц',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count недель',
      many: 'Каждые $count недель',
      few: 'Каждые $count недели',
      one: 'Каждую $count неделю',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Каждые $count лет',
      many: 'Каждые $count лет',
      few: 'Каждые $count года',
      one: 'Каждый $count год',
    );
    return '$_temp0';
  }

  @override
  String get edFree => 'Свободен';

  @override
  String get edFreqDay => 'День';

  @override
  String get edFreqMonth => 'Месяц';

  @override
  String get edFreqWeek => 'Неделя';

  @override
  String get edFreqYear => 'Год';

  @override
  String get edFri => 'Пт';

  @override
  String get edFridayAcc => 'пятницу';

  @override
  String get edInviteeHint => 'Имя из справочника или email';

  @override
  String get edLocationHint => 'Место';

  @override
  String get edMon => 'Пн';

  @override
  String get edMondayAcc => 'понедельник';

  @override
  String get edMonthly => 'Ежемесячно';

  @override
  String get edNewEvent => 'Новое событие';

  @override
  String get edNoEndDate => 'Без даты окончания';

  @override
  String get edNone => 'Нет';

  @override
  String get edNotesHint => 'Заметки';

  @override
  String edOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count повторений',
      many: '$count повторений',
      few: '$count повторения',
      one: '$count повторение',
    );
    return '$_temp0';
  }

  @override
  String get edOccurrencesLabel => 'повторений';

  @override
  String edOnDayOfMonth(int day) {
    return '$day-го числа';
  }

  @override
  String get edOrdinal1 => 'в 1-й';

  @override
  String get edOrdinal2 => 'во 2-й';

  @override
  String get edOrdinal3 => 'в 3-й';

  @override
  String get edOrdinal4 => 'в 4-й';

  @override
  String get edOrdinalLast => 'в последний';

  @override
  String edOrdinalN(int number) {
    return 'в $number-й';
  }

  @override
  String get edRecurrenceTitle => 'Повторение';

  @override
  String get edRepeat => 'Повторять';

  @override
  String get edSat => 'Сб';

  @override
  String get edSaturdayAcc => 'субботу';

  @override
  String get edSeriesInstance => 'Экземпляр серии — правило у всей серии';

  @override
  String get edShowAs => 'Показывать как';

  @override
  String get edStart => 'Начало';

  @override
  String get edSun => 'Вс';

  @override
  String get edSundayAcc => 'воскресенье';

  @override
  String get edThu => 'Чт';

  @override
  String get edThursdayAcc => 'четверг';

  @override
  String get edTitleHint => 'Название';

  @override
  String get edTue => 'Вт';

  @override
  String get edTuesdayAcc => 'вторник';

  @override
  String get edUnitDay => 'дн.';

  @override
  String get edUnitMonth => 'мес.';

  @override
  String get edUnitWeek => 'нед.';

  @override
  String get edUnitYear => 'г.';

  @override
  String get edUntil => 'До даты';

  @override
  String edUntilDate(String date) {
    return 'до $date';
  }

  @override
  String get edUntitled => 'Без названия';

  @override
  String get edVisDefault => 'По умолчанию';

  @override
  String get edVisPrivate => 'Приватно';

  @override
  String get edVisPublic => 'Публично';

  @override
  String get edVisibility => 'Видимость';

  @override
  String get edWed => 'Ср';

  @override
  String get edWednesdayAcc => 'среду';

  @override
  String get edWeekly => 'Еженедельно';

  @override
  String get edYearly => 'Ежегодно';

  @override
  String get setAbout => 'О приложении';

  @override
  String get setAboutSubtitle => 'Local-first агрегатор календарей · MVP';

  @override
  String get setAccounts => 'Учётные записи';

  @override
  String get setAccountsAndConnections => 'Учётные записи и подключения';

  @override
  String setAccountsConnected(int count) {
    return '$count подключено';
  }

  @override
  String get setCalendarNameHint => 'Имя календаря';

  @override
  String get setCalendars => 'Календари';

  @override
  String get setCalendarsSubtitle => 'Какие календари показывать в сетке';

  @override
  String get setCancel => 'Отмена';

  @override
  String setColorTitle(String name) {
    return 'Цвет: $name';
  }

  @override
  String get setCombine => 'Объединять встречи';

  @override
  String get setCombineSubtitle =>
      'Склеивать одинаковые события из разных календарей. Отжать — каждая встреча отдельно, можно работать с каждой копией';

  @override
  String get setCommitDelay => 'Задержка перед отправкой изменений';

  @override
  String get setCommitDelaySubtitle =>
      'Перенос/ресайз ждут перед уходом в облако: пунктир + отсчёт + «применить сейчас». 0 — сразу.';

  @override
  String get setDelayImmediate => 'Сразу';

  @override
  String setDelayMinutes(int count) {
    return '$count мин';
  }

  @override
  String get setEvents => 'События';

  @override
  String setFromSource(String name) {
    return 'Из источника: $name';
  }

  @override
  String get setLanguage => 'Язык';

  @override
  String get setLanguageSystem => 'Системный';

  @override
  String get setMaps => 'Карты';

  @override
  String get setMapsSubtitle => 'По умолчанию — Yandex Maps';

  @override
  String get setNoAccounts => 'Нет аккаунтов';

  @override
  String get setNoCalendars => 'нет календарей';

  @override
  String get setOpenPlacesIn => 'Открывать места в';

  @override
  String get setReminderAtStart => 'в начале';

  @override
  String get setReminderAtStartFull => 'В момент начала';

  @override
  String setReminderHours(int count) {
    return 'за $count ч';
  }

  @override
  String setReminderMinutes(int count) {
    return 'за $count мин';
  }

  @override
  String get setReminderNone => 'без';

  @override
  String get setReminderNoneFull => 'Без напоминания';

  @override
  String get setReminderSubtitle => 'По умолчанию для событий этого календаря';

  @override
  String setReminderTitle(String name) {
    return 'Напоминание: $name';
  }

  @override
  String get setRenameCalendar => 'Переименовать календарь';

  @override
  String get setReset => 'Сбросить';

  @override
  String get setResetColor => 'Сбросить к цвету источника';

  @override
  String get setSave => 'Сохранить';

  @override
  String get setShowCancelled => 'Показывать удалённые/отменённые';

  @override
  String get setShowCancelledSubtitle => 'Зачёркнутым стилем';

  @override
  String get setShowMonth => 'Показывать месячный вид';

  @override
  String get setShowMonthSubtitle => 'На телефоне месяц тесный — можно убрать';

  @override
  String get setTitle => 'Настройки';

  @override
  String get setView => 'Вид';

  @override
  String get uiCancel => 'Отмена';

  @override
  String uiError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get uiMove => 'Перенести';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => 'Перенести встречу?';

  @override
  String get uiNoTitle => 'Без названия';

  @override
  String uiNotUpdated(String accounts) {
    return 'Не обновилось: $accounts';
  }

  @override
  String get uiReasonAuthError => 'ошибка авторизации';

  @override
  String get uiReasonFailure => 'сбой';

  @override
  String get uiReasonNeedsReconnect => 'переподключение';

  @override
  String get uiReasonOffline => 'нет сети';

  @override
  String get uiRetry => 'Повторить';
}
