// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get accAddAccount => 'Add account';

  @override
  String get accAppPassword => 'App password';

  @override
  String get accAppPasswordHelper =>
      'NOT your main email password — create an app password';

  @override
  String get accAutoRefresh => 'Auto-refresh';

  @override
  String get accCaldavPasswordHelper =>
      'For CalDAV — an app password, not your main email password';

  @override
  String get accCancel => 'Cancel';

  @override
  String get accChangePassword => 'Change password';

  @override
  String accCompleteSignIn(String name) {
    return '$name: complete sign-in in the browser that opened…';
  }

  @override
  String get accConnect => 'Connect';

  @override
  String get accConnectAccount => 'Connect account';

  @override
  String accConnected(String email) {
    return 'Connected: $email';
  }

  @override
  String get accConnecting => 'Connecting…';

  @override
  String get accDelete => 'Delete';

  @override
  String get accEmail => 'E-mail';

  @override
  String accError(String error) {
    return 'Error: $error';
  }

  @override
  String get accEwsUrlLabel => 'EWS URL (optional)';

  @override
  String accFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get accFillEmailPassword => 'Fill in e-mail and password';

  @override
  String get accHidden => 'hidden';

  @override
  String get accHost => 'Host';

  @override
  String get accHour1 => '1 h';

  @override
  String get accLoginIfDifferent => 'Login (if different)';

  @override
  String get accLoginPassword => 'Login and password';

  @override
  String get accManual => 'Manual';

  @override
  String accMinutes(int count) {
    return '$count min';
  }

  @override
  String get accNewPassword => 'New password';

  @override
  String get accNoCalendars => 'No calendars';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return '$name sign-in is not set up';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return 'This Calenfi build has no OAuth client for $name, so the browser sign-in cannot start. Enter the client of your OAuth app (redirect URI http://localhost); it is kept in this device\'s secure storage.';
  }

  @override
  String get accOAuthClientId => 'Client ID';

  @override
  String get accOAuthClientSecret => 'Client secret';

  @override
  String get accSaveAndSignIn => 'Save and sign in';

  @override
  String get accPassword => 'Password';

  @override
  String get accPasswordSaved => 'Password saved, syncing…';

  @override
  String get accReconnect => 'Reconnect';

  @override
  String get accPort => 'Port';

  @override
  String get accSave => 'Save';

  @override
  String get accSectionCalendars => 'Calendars';

  @override
  String get accSectionVideoMeetings => 'Video meetings';

  @override
  String get accSignInBrowser => 'Sign in via browser';

  @override
  String get accStatusAuthError => 'authorization error';

  @override
  String get accStatusNeedsReconnect => 'reconnection required';

  @override
  String get accStatusOffline => 'no network';

  @override
  String get accStatusOk => 'connected';

  @override
  String get accStatusSyncError => 'sync failed';

  @override
  String get accTitle => 'Accounts';

  @override
  String get accVisibilityHint =>
      'Calendar visibility — in Settings → Calendars';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => 'Cancel';

  @override
  String get calCombineOff =>
      'Merge identical events (off — each shown separately)';

  @override
  String get calCombineOn => 'Merge identical events (on)';

  @override
  String get calDay => 'Day';

  @override
  String get calDayShort => 'D';

  @override
  String get calMonth => 'Month';

  @override
  String get calMonthShort => 'M';

  @override
  String get calMoveModeHint => 'Move mode: drag events. Tap for details.';

  @override
  String get calNoTitle => 'No title';

  @override
  String get calNothingFound => 'Nothing found';

  @override
  String calPendingCount(int count) {
    return 'Not sent to cloud: $count';
  }

  @override
  String get calPinEvents => 'Pin events';

  @override
  String calSearchFound(int count) {
    return 'Found: $count';
  }

  @override
  String get calSearchHint => 'Search: title, participant, id';

  @override
  String get calSettings => 'Settings';

  @override
  String get calShowCancelled => 'Show deleted/cancelled';

  @override
  String get calSortDate => 'Date';

  @override
  String get calSortRelevance => 'Relevance';

  @override
  String get calSynced => 'Synced';

  @override
  String get calToCloud => 'To cloud';

  @override
  String get calToday => 'Today';

  @override
  String get calUnpinEvents => 'Unpin events (move by dragging)';

  @override
  String get calViewInDev => 'View under development';

  @override
  String get calWeek => 'Week';

  @override
  String get calWeekShort => 'W';

  @override
  String get detAccept => 'Accept';

  @override
  String get detAllDay => 'all day';

  @override
  String get detAttendeeCopied => 'Attendee copied';

  @override
  String detAttendeesCount(int total, int accepted) {
    return 'Attendees: $total  ·  $accepted accepted';
  }

  @override
  String get detCancel => 'Cancel';

  @override
  String get detCancelledDeleted => 'Cancelled / deleted';

  @override
  String get detConfVideoCall => 'video call';

  @override
  String get detCopied => 'Copied';

  @override
  String get detCopy => 'Copy';

  @override
  String get detDecline => 'Decline';

  @override
  String get detDelete => 'Delete';

  @override
  String get detDeleteEventQ => 'Delete event?';

  @override
  String get detEdit => 'Edit';

  @override
  String get detEditTitle => 'Edit title';

  @override
  String detFieldCopied(String label) {
    return '$label copied';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return 'In multiple calendars ($count):';
  }

  @override
  String detJoin(String label) {
    return 'Join · $label';
  }

  @override
  String get detMeetingLinkCopied => 'Meeting link copied';

  @override
  String get detOpenInCloud => 'Open in cloud';

  @override
  String get detOptional => 'optional';

  @override
  String get detOrganizer => 'organizer';

  @override
  String get detRecurringWhatDelete => 'Recurring event — what to delete?';

  @override
  String get detRecurringWhatEdit => 'Recurring event — what to change?';

  @override
  String get detEditWholeSeries => 'Entire series (every occurrence)';

  @override
  String get detResponseAccepted => 'Accepted';

  @override
  String get detResponseDeclined => 'Declined';

  @override
  String get detResponseNeedsAction => 'Awaiting response';

  @override
  String get detResponseOrganizer => 'You\'re the organizer';

  @override
  String get detResponseTentative => 'Maybe';

  @override
  String get detSave => 'Save';

  @override
  String get detTentative => 'Maybe';

  @override
  String get detThisAndFollowing => 'This and following';

  @override
  String get detThisEventOnly => 'This event only';

  @override
  String get detTitleChanged => 'Title changed';

  @override
  String get detUnknownCalendar => 'Unknown calendar';

  @override
  String get detWholeSeries => 'Entire series';

  @override
  String get edAllDay => 'All day';

  @override
  String get edAttendees => 'Attendees';

  @override
  String get edBusy => 'Busy';

  @override
  String get edCalendar => 'Calendar';

  @override
  String get edCancel => 'Cancel';

  @override
  String get edChoose => 'choose…';

  @override
  String get edConference => 'Video meeting';

  @override
  String get edConnectAccount => 'Connect account';

  @override
  String get edDaily => 'Daily';

  @override
  String get edDoNotRepeat => 'Do not repeat';

  @override
  String get edDone => 'Done';

  @override
  String get edEditEvent => 'Edit event';

  @override
  String get edEnd => 'End';

  @override
  String get edEndAfter => 'End after';

  @override
  String get edEvery => 'Every';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every $count day',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every $count month',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every $count week',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every $count year',
    );
    return '$_temp0';
  }

  @override
  String get edFree => 'Free';

  @override
  String get edFreqDay => 'Day';

  @override
  String get edFreqMonth => 'Month';

  @override
  String get edFreqWeek => 'Week';

  @override
  String get edFreqYear => 'Year';

  @override
  String get edFri => 'Fri';

  @override
  String get edFridayAcc => 'Friday';

  @override
  String get edInviteeHint => 'Name from contacts or email';

  @override
  String get edLocationHint => 'Location';

  @override
  String get edMon => 'Mon';

  @override
  String get edMondayAcc => 'Monday';

  @override
  String get edMonthly => 'Monthly';

  @override
  String get edNewEvent => 'New event';

  @override
  String get edNoEndDate => 'No end date';

  @override
  String get edNone => 'None';

  @override
  String get edNotesHint => 'Notes';

  @override
  String edOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count occurrences',
      one: '$count occurrence',
    );
    return '$_temp0';
  }

  @override
  String get edOccurrencesLabel => 'occurrences';

  @override
  String edOnDayOfMonth(int day) {
    return 'on day $day';
  }

  @override
  String get edOrdinal1 => 'on the 1st';

  @override
  String get edOrdinal2 => 'on the 2nd';

  @override
  String get edOrdinal3 => 'on the 3rd';

  @override
  String get edOrdinal4 => 'on the 4th';

  @override
  String get edOrdinalLast => 'on the last';

  @override
  String edOrdinalN(int number) {
    return 'on the ${number}th';
  }

  @override
  String get edRecurrenceTitle => 'Recurrence';

  @override
  String get edRepeat => 'Repeat';

  @override
  String get edSat => 'Sat';

  @override
  String get edSaturdayAcc => 'Saturday';

  @override
  String get edSeriesInstance =>
      'Series instance — rule applies to the whole series';

  @override
  String get edShowAs => 'Show as';

  @override
  String get edStart => 'Start';

  @override
  String get edSun => 'Sun';

  @override
  String get edSundayAcc => 'Sunday';

  @override
  String get edThu => 'Thu';

  @override
  String get edThursdayAcc => 'Thursday';

  @override
  String get edTitleHint => 'Title';

  @override
  String get edTue => 'Tue';

  @override
  String get edTuesdayAcc => 'Tuesday';

  @override
  String get edUnitDay => 'days';

  @override
  String get edUnitMonth => 'months';

  @override
  String get edUnitWeek => 'weeks';

  @override
  String get edUnitYear => 'years';

  @override
  String get edUntil => 'Until date';

  @override
  String edUntilDate(String date) {
    return 'until $date';
  }

  @override
  String get edUntitled => 'Untitled';

  @override
  String get edVisDefault => 'Default';

  @override
  String get edVisPrivate => 'Private';

  @override
  String get edVisPublic => 'Public';

  @override
  String get edVisibility => 'Visibility';

  @override
  String get edWed => 'Wed';

  @override
  String get edWednesdayAcc => 'Wednesday';

  @override
  String get edWeekly => 'Weekly';

  @override
  String get edYearly => 'Yearly';

  @override
  String get setAbout => 'About';

  @override
  String get setAboutSubtitle => 'Local-first calendar aggregator · MVP';

  @override
  String get setAccounts => 'Accounts';

  @override
  String get setAccountsAndConnections => 'Accounts & connections';

  @override
  String setAccountsConnected(int count) {
    return '$count connected';
  }

  @override
  String get setCalendarNameHint => 'Calendar name';

  @override
  String get setCalendars => 'Calendars';

  @override
  String get setCalendarsSubtitle => 'Which calendars to show in the grid';

  @override
  String get setCancel => 'Cancel';

  @override
  String setColorTitle(String name) {
    return 'Color: $name';
  }

  @override
  String get setCombine => 'Merge meetings';

  @override
  String get setCombineSubtitle =>
      'Merge identical events from different calendars. Turn off — each meeting stays separate, so you can work with every copy';

  @override
  String get setCommitDelay => 'Delay before sending changes';

  @override
  String get setCommitDelaySubtitle =>
      'Move/resize wait before going to the cloud: dashed outline + countdown + \"apply now\". 0 — instantly.';

  @override
  String get setDelayImmediate => 'Immediately';

  @override
  String setDelayMinutes(int count) {
    return '$count min';
  }

  @override
  String get setEvents => 'Events';

  @override
  String setFromSource(String name) {
    return 'From source: $name';
  }

  @override
  String get setLanguage => 'Language';

  @override
  String get setLanguageSystem => 'System';

  @override
  String get setMaps => 'Maps';

  @override
  String get setMapsSubtitle => 'Yandex Maps by default';

  @override
  String get setNoAccounts => 'No accounts';

  @override
  String get setNoCalendars => 'no calendars';

  @override
  String get setOpenPlacesIn => 'Open places in';

  @override
  String get setReminderAtStart => 'at start';

  @override
  String get setReminderAtStartFull => 'At start time';

  @override
  String setReminderHours(int count) {
    return '$count h before';
  }

  @override
  String setReminderMinutes(int count) {
    return '$count min before';
  }

  @override
  String get setReminderNone => 'none';

  @override
  String get setReminderNoneFull => 'No reminder';

  @override
  String get setReminderSubtitle => 'Default for events in this calendar';

  @override
  String setReminderTitle(String name) {
    return 'Reminder: $name';
  }

  @override
  String get setRenameCalendar => 'Rename calendar';

  @override
  String get setReset => 'Reset';

  @override
  String get setResetColor => 'Reset to source color';

  @override
  String get setSave => 'Save';

  @override
  String get setShowCancelled => 'Show deleted/cancelled';

  @override
  String get setShowCancelledSubtitle => 'In a strikethrough style';

  @override
  String get setShowMonth => 'Show month view';

  @override
  String get setShowMonthSubtitle =>
      'The month is cramped on a phone — you can hide it';

  @override
  String get setTitle => 'Settings';

  @override
  String get setView => 'View';

  @override
  String get uiCancel => 'Cancel';

  @override
  String uiError(String error) {
    return 'Error: $error';
  }

  @override
  String get uiMove => 'Move';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => 'Move event?';

  @override
  String get uiNoTitle => 'Untitled';

  @override
  String uiNotUpdated(String accounts) {
    return 'Not updated: $accounts';
  }

  @override
  String get uiReasonAuthError => 'auth error';

  @override
  String get uiReasonFailure => 'failure';

  @override
  String get uiReasonNeedsReconnect => 'reconnecting';

  @override
  String get uiReasonOffline => 'no network';

  @override
  String get uiRetry => 'Retry';
}
