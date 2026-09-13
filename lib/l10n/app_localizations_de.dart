// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class L10nDe extends L10n {
  L10nDe([String locale = 'de']) : super(locale);

  @override
  String get accAddAccount => 'Konto hinzufügen';

  @override
  String get accAppPassword => 'App-Passwort';

  @override
  String get accAppPasswordHelper =>
      'NICHT das Haupt-E-Mail-Passwort — erstellen Sie ein App-Passwort';

  @override
  String get accAutoRefresh => 'Automatische Aktualisierung';

  @override
  String get accCaldavPasswordHelper =>
      'Für CalDAV — ein App-Passwort, nicht das Haupt-E-Mail-Passwort';

  @override
  String get accCancel => 'Abbrechen';

  @override
  String get accChangePassword => 'Passwort ändern';

  @override
  String accCompleteSignIn(String name) {
    return '$name: Schließen Sie die Anmeldung im geöffneten Browser ab…';
  }

  @override
  String get accConnect => 'Verbinden';

  @override
  String get accConnectAccount => 'Konto verbinden';

  @override
  String accConnected(String email) {
    return 'Verbunden: $email';
  }

  @override
  String get accConnecting => 'Verbinde…';

  @override
  String get accDelete => 'Löschen';

  @override
  String get accEmail => 'E-Mail';

  @override
  String accError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get accEwsUrlLabel => 'EWS-URL (optional)';

  @override
  String accFailed(String error) {
    return 'Fehlgeschlagen: $error';
  }

  @override
  String get accFillEmailPassword => 'E-Mail und Passwort ausfüllen';

  @override
  String get accHidden => 'ausgeblendet';

  @override
  String get accHost => 'Host';

  @override
  String get accHour1 => '1 Std.';

  @override
  String get accLoginIfDifferent => 'Anmeldename (falls abweichend)';

  @override
  String get accLoginPassword => 'Benutzername und Passwort';

  @override
  String get accManual => 'Manuell';

  @override
  String accMinutes(int count) {
    return '$count Min.';
  }

  @override
  String get accNewPassword => 'Neues Passwort';

  @override
  String get accNoCalendars => 'Keine Kalender';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return 'Anmeldung bei $name ist nicht eingerichtet';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return 'Dieser Calenfi-Build enthält keinen OAuth-Client für $name, daher kann die Anmeldung im Browser nicht starten. Gib den Client deiner OAuth-App ein (Weiterleitungs-URI http://localhost); er wird im sicheren Speicher des Geräts abgelegt.';
  }

  @override
  String get accOAuthClientId => 'Client-ID';

  @override
  String get accOAuthClientSecret => 'Client-Geheimnis';

  @override
  String get accSaveAndSignIn => 'Speichern und anmelden';

  @override
  String get accPassword => 'Passwort';

  @override
  String get accPasswordSaved => 'Passwort gespeichert, synchronisiere…';

  @override
  String get accPort => 'Port';

  @override
  String get accSave => 'Speichern';

  @override
  String get accSectionCalendars => 'Kalender';

  @override
  String get accSectionVideoMeetings => 'Videokonferenzen';

  @override
  String get accSignInBrowser => 'Anmeldung über Browser';

  @override
  String get accStatusAuthError => 'Autorisierungsfehler';

  @override
  String get accStatusNeedsReconnect => 'erneute Verbindung erforderlich';

  @override
  String get accStatusOffline => 'keine Verbindung';

  @override
  String get accStatusOk => 'verbunden';

  @override
  String get accStatusSyncError => 'Synchronisierungsfehler';

  @override
  String get accTitle => 'Konten';

  @override
  String get accVisibilityHint =>
      'Kalendersichtbarkeit — unter Einstellungen → Kalender';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => 'Abbrechen';

  @override
  String get calCombineOff =>
      'Gleiche Termine zusammenführen (aus — jeder einzeln)';

  @override
  String get calCombineOn => 'Gleiche Termine zusammenführen (ein)';

  @override
  String get calDay => 'Tag';

  @override
  String get calDayShort => 'T';

  @override
  String get calMonth => 'Monat';

  @override
  String get calMonthShort => 'M';

  @override
  String get calMoveModeHint =>
      'Verschiebemodus: Termine ziehen. Tippen für Details.';

  @override
  String get calNoTitle => 'Ohne Titel';

  @override
  String get calNothingFound => 'Nichts gefunden';

  @override
  String calPendingCount(int count) {
    return 'Nicht in die Cloud gesendet: $count';
  }

  @override
  String get calPinEvents => 'Termine anheften';

  @override
  String calSearchFound(int count) {
    return 'Gefunden: $count';
  }

  @override
  String get calSearchHint => 'Suche: Titel, Teilnehmer, ID';

  @override
  String get calSettings => 'Einstellungen';

  @override
  String get calShowCancelled => 'Gelöschte/abgesagte anzeigen';

  @override
  String get calSortDate => 'Datum';

  @override
  String get calSortRelevance => 'Relevanz';

  @override
  String get calSynced => 'Synchronisiert';

  @override
  String get calToCloud => 'In die Cloud';

  @override
  String get calToday => 'Heute';

  @override
  String get calUnpinEvents => 'Termine lösen (durch Ziehen verschieben)';

  @override
  String get calViewInDev => 'Ansicht in Entwicklung';

  @override
  String get calWeek => 'Woche';

  @override
  String get calWeekShort => 'W';

  @override
  String get detAccept => 'Zusagen';

  @override
  String get detAllDay => 'ganztägig';

  @override
  String get detAttendeeCopied => 'Teilnehmer kopiert';

  @override
  String detAttendeesCount(int total, int accepted) {
    return 'Teilnehmer: $total  ·  $accepted zugesagt';
  }

  @override
  String get detCancel => 'Abbrechen';

  @override
  String get detCancelledDeleted => 'Abgesagt / gelöscht';

  @override
  String get detConfVideoCall => 'Videoanruf';

  @override
  String get detCopied => 'Kopiert';

  @override
  String get detCopy => 'Kopieren';

  @override
  String get detDecline => 'Absagen';

  @override
  String get detDelete => 'Löschen';

  @override
  String get detDeleteEventQ => 'Ereignis löschen?';

  @override
  String get detEdit => 'Bearbeiten';

  @override
  String get detEditTitle => 'Titel bearbeiten';

  @override
  String detFieldCopied(String label) {
    return '$label kopiert';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return 'In mehreren Kalendern ($count):';
  }

  @override
  String detJoin(String label) {
    return 'Beitreten · $label';
  }

  @override
  String get detMeetingLinkCopied => 'Besprechungslink kopiert';

  @override
  String get detOpenInCloud => 'In der Cloud öffnen';

  @override
  String get detOptional => 'optional';

  @override
  String get detOrganizer => 'Organisator';

  @override
  String get detRecurringWhatDelete =>
      'Wiederkehrendes Ereignis – was löschen?';

  @override
  String get detRecurringWhatEdit => 'Serientermin — was ändern?';

  @override
  String get detEditWholeSeries => 'Gesamte Serie (alle Termine)';

  @override
  String get detResponseAccepted => 'Zugesagt';

  @override
  String get detResponseDeclined => 'Abgesagt';

  @override
  String get detResponseNeedsAction => 'Antwort ausstehend';

  @override
  String get detResponseOrganizer => 'Sie sind der Organisator';

  @override
  String get detResponseTentative => 'Vielleicht';

  @override
  String get detSave => 'Speichern';

  @override
  String get detTentative => 'Vielleicht';

  @override
  String get detThisAndFollowing => 'Dieses und folgende';

  @override
  String get detThisEventOnly => 'Nur dieses Ereignis';

  @override
  String get detTitleChanged => 'Titel geändert';

  @override
  String get detUnknownCalendar => 'Unbekannter Kalender';

  @override
  String get detWholeSeries => 'Gesamte Serie';

  @override
  String get edAllDay => 'Ganztägig';

  @override
  String get edAttendees => 'Teilnehmer';

  @override
  String get edBusy => 'Gebucht';

  @override
  String get edCalendar => 'Kalender';

  @override
  String get edCancel => 'Abbrechen';

  @override
  String get edChoose => 'auswählen…';

  @override
  String get edConference => 'Videokonferenz';

  @override
  String get edConnectAccount => 'Konto verbinden';

  @override
  String get edDaily => 'Täglich';

  @override
  String get edDoNotRepeat => 'Nicht wiederholen';

  @override
  String get edDone => 'Fertig';

  @override
  String get edEditEvent => 'Termin bearbeiten';

  @override
  String get edEnd => 'Ende';

  @override
  String get edEndAfter => 'Ende nach';

  @override
  String get edEvery => 'Alle';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Tage',
      one: 'Alle $count Tage',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Monate',
      one: 'Alle $count Monate',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Wochen',
      one: 'Alle $count Wochen',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Jahre',
      one: 'Alle $count Jahre',
    );
    return '$_temp0';
  }

  @override
  String get edFree => 'Frei';

  @override
  String get edFreqDay => 'Tag';

  @override
  String get edFreqMonth => 'Monat';

  @override
  String get edFreqWeek => 'Woche';

  @override
  String get edFreqYear => 'Jahr';

  @override
  String get edFri => 'Fr';

  @override
  String get edFridayAcc => 'Freitag';

  @override
  String get edInviteeHint => 'Name aus Kontakten oder E-Mail';

  @override
  String get edLocationHint => 'Ort';

  @override
  String get edMon => 'Mo';

  @override
  String get edMondayAcc => 'Montag';

  @override
  String get edMonthly => 'Monatlich';

  @override
  String get edNewEvent => 'Neuer Termin';

  @override
  String get edNoEndDate => 'Kein Enddatum';

  @override
  String get edNone => 'Keine';

  @override
  String get edNotesHint => 'Notizen';

  @override
  String edOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiederholungen',
      one: '$count Wiederholung',
    );
    return '$_temp0';
  }

  @override
  String get edOccurrencesLabel => 'Wiederholungen';

  @override
  String edOnDayOfMonth(int day) {
    return 'am $day.';
  }

  @override
  String get edOrdinal1 => 'am 1.';

  @override
  String get edOrdinal2 => 'am 2.';

  @override
  String get edOrdinal3 => 'am 3.';

  @override
  String get edOrdinal4 => 'am 4.';

  @override
  String get edOrdinalLast => 'am letzten';

  @override
  String edOrdinalN(int number) {
    return 'am $number.';
  }

  @override
  String get edRecurrenceTitle => 'Wiederholung';

  @override
  String get edRepeat => 'Wiederholen';

  @override
  String get edSat => 'Sa';

  @override
  String get edSaturdayAcc => 'Samstag';

  @override
  String get edSeriesInstance =>
      'Serieninstanz – die Regel gilt für die gesamte Serie';

  @override
  String get edShowAs => 'Anzeigen als';

  @override
  String get edStart => 'Beginn';

  @override
  String get edSun => 'So';

  @override
  String get edSundayAcc => 'Sonntag';

  @override
  String get edThu => 'Do';

  @override
  String get edThursdayAcc => 'Donnerstag';

  @override
  String get edTitleHint => 'Titel';

  @override
  String get edTue => 'Di';

  @override
  String get edTuesdayAcc => 'Dienstag';

  @override
  String get edUnitDay => 'Tage';

  @override
  String get edUnitMonth => 'Monate';

  @override
  String get edUnitWeek => 'Wochen';

  @override
  String get edUnitYear => 'Jahre';

  @override
  String get edUntil => 'Bis Datum';

  @override
  String edUntilDate(String date) {
    return 'bis $date';
  }

  @override
  String get edUntitled => 'Ohne Titel';

  @override
  String get edVisDefault => 'Standard';

  @override
  String get edVisPrivate => 'Privat';

  @override
  String get edVisPublic => 'Öffentlich';

  @override
  String get edVisibility => 'Sichtbarkeit';

  @override
  String get edWed => 'Mi';

  @override
  String get edWednesdayAcc => 'Mittwoch';

  @override
  String get edWeekly => 'Wöchentlich';

  @override
  String get edYearly => 'Jährlich';

  @override
  String get setAbout => 'Über';

  @override
  String get setAboutSubtitle => 'Local-First-Kalenderaggregator · MVP';

  @override
  String get setAccounts => 'Konten';

  @override
  String get setAccountsAndConnections => 'Konten und Verbindungen';

  @override
  String setAccountsConnected(int count) {
    return '$count verbunden';
  }

  @override
  String get setCalendarNameHint => 'Kalendername';

  @override
  String get setCalendars => 'Kalender';

  @override
  String get setCalendarsSubtitle =>
      'Welche Kalender im Raster angezeigt werden';

  @override
  String get setCancel => 'Abbrechen';

  @override
  String setColorTitle(String name) {
    return 'Farbe: $name';
  }

  @override
  String get setCombine => 'Termine zusammenfassen';

  @override
  String get setCombineSubtitle =>
      'Identische Ereignisse aus verschiedenen Kalendern zusammenführen. Deaktivieren — jeder Termin bleibt einzeln, du kannst mit jeder Kopie arbeiten';

  @override
  String get setCommitDelay => 'Verzögerung vor dem Senden von Änderungen';

  @override
  String get setCommitDelaySubtitle =>
      'Verschieben/Größe ändern warten vor dem Hochladen in die Cloud: gestrichelte Umrandung + Countdown + „jetzt anwenden“. 0 — sofort.';

  @override
  String get setDelayImmediate => 'Sofort';

  @override
  String setDelayMinutes(int count) {
    return '$count Min.';
  }

  @override
  String get setEvents => 'Ereignisse';

  @override
  String setFromSource(String name) {
    return 'Aus der Quelle: $name';
  }

  @override
  String get setLanguage => 'Sprache';

  @override
  String get setLanguageSystem => 'System';

  @override
  String get setMaps => 'Karten';

  @override
  String get setMapsSubtitle => 'Standardmäßig Yandex Maps';

  @override
  String get setNoAccounts => 'Keine Konten';

  @override
  String get setNoCalendars => 'keine Kalender';

  @override
  String get setOpenPlacesIn => 'Orte öffnen in';

  @override
  String get setReminderAtStart => 'bei Beginn';

  @override
  String get setReminderAtStartFull => 'Zur Startzeit';

  @override
  String setReminderHours(int count) {
    return '$count Std. vorher';
  }

  @override
  String setReminderMinutes(int count) {
    return '$count Min. vorher';
  }

  @override
  String get setReminderNone => 'keine';

  @override
  String get setReminderNoneFull => 'Keine Erinnerung';

  @override
  String get setReminderSubtitle =>
      'Standard für Ereignisse in diesem Kalender';

  @override
  String setReminderTitle(String name) {
    return 'Erinnerung: $name';
  }

  @override
  String get setRenameCalendar => 'Kalender umbenennen';

  @override
  String get setReset => 'Zurücksetzen';

  @override
  String get setResetColor => 'Auf Quellfarbe zurücksetzen';

  @override
  String get setSave => 'Speichern';

  @override
  String get setShowCancelled => 'Gelöschte/abgesagte anzeigen';

  @override
  String get setShowCancelledSubtitle => 'In durchgestrichenem Stil';

  @override
  String get setShowMonth => 'Monatsansicht anzeigen';

  @override
  String get setShowMonthSubtitle =>
      'Auf dem Handy ist die Monatsansicht eng — du kannst sie ausblenden';

  @override
  String get setTitle => 'Einstellungen';

  @override
  String get setView => 'Ansicht';

  @override
  String get uiCancel => 'Abbrechen';

  @override
  String uiError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get uiMove => 'Verschieben';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => 'Termin verschieben?';

  @override
  String get uiNoTitle => 'Ohne Titel';

  @override
  String uiNotUpdated(String accounts) {
    return 'Nicht aktualisiert: $accounts';
  }

  @override
  String get uiReasonAuthError => 'Authentifizierungsfehler';

  @override
  String get uiReasonFailure => 'Fehler';

  @override
  String get uiReasonNeedsReconnect => 'Neuverbindung';

  @override
  String get uiReasonOffline => 'kein Netz';

  @override
  String get uiRetry => 'Wiederholen';
}
