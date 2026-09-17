import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// No description provided for @accAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accAddAccount;

  /// No description provided for @accAppPassword.
  ///
  /// In en, this message translates to:
  /// **'App password'**
  String get accAppPassword;

  /// No description provided for @accAppPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'NOT your main email password — create an app password'**
  String get accAppPasswordHelper;

  /// No description provided for @accAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh'**
  String get accAutoRefresh;

  /// No description provided for @accCaldavPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'For CalDAV — an app password, not your main email password'**
  String get accCaldavPasswordHelper;

  /// No description provided for @accCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accCancel;

  /// No description provided for @accChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accChangePassword;

  /// No description provided for @accCompleteSignIn.
  ///
  /// In en, this message translates to:
  /// **'{name}: complete sign-in in the browser that opened…'**
  String accCompleteSignIn(String name);

  /// No description provided for @accConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get accConnect;

  /// No description provided for @accConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect account'**
  String get accConnectAccount;

  /// No description provided for @accConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected: {email}'**
  String accConnected(String email);

  /// No description provided for @accConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get accConnecting;

  /// No description provided for @accDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accDelete;

  /// No description provided for @accEmail.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get accEmail;

  /// No description provided for @accError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String accError(String error);

  /// No description provided for @accEwsUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'EWS URL (optional)'**
  String get accEwsUrlLabel;

  /// No description provided for @accFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String accFailed(String error);

  /// No description provided for @accFillEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Fill in e-mail and password'**
  String get accFillEmailPassword;

  /// No description provided for @accHidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get accHidden;

  /// No description provided for @accHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get accHost;

  /// No description provided for @accHour1.
  ///
  /// In en, this message translates to:
  /// **'1 h'**
  String get accHour1;

  /// No description provided for @accLoginIfDifferent.
  ///
  /// In en, this message translates to:
  /// **'Login (if different)'**
  String get accLoginIfDifferent;

  /// No description provided for @accLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Login and password'**
  String get accLoginPassword;

  /// No description provided for @accManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get accManual;

  /// No description provided for @accMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String accMinutes(int count);

  /// No description provided for @accNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accNewPassword;

  /// No description provided for @accNoCalendars.
  ///
  /// In en, this message translates to:
  /// **'No calendars'**
  String get accNoCalendars;

  /// No description provided for @accOAuthNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} sign-in is not set up'**
  String accOAuthNotConfiguredTitle(String name);

  /// No description provided for @accOAuthNotConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'This Calenfi build has no OAuth client for {name}, so the browser sign-in cannot start. Enter the client of your OAuth app (redirect URI http://localhost); it is kept in this device\'s secure storage.'**
  String accOAuthNotConfiguredBody(String name);

  /// No description provided for @accOAuthClientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get accOAuthClientId;

  /// No description provided for @accOAuthClientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client secret'**
  String get accOAuthClientSecret;

  /// No description provided for @accSaveAndSignIn.
  ///
  /// In en, this message translates to:
  /// **'Save and sign in'**
  String get accSaveAndSignIn;

  /// No description provided for @accPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accPassword;

  /// No description provided for @accPasswordSaved.
  ///
  /// In en, this message translates to:
  /// **'Password saved, syncing…'**
  String get accPasswordSaved;

  /// No description provided for @accReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get accReconnect;

  /// No description provided for @accPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get accPort;

  /// No description provided for @accSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accSave;

  /// No description provided for @accSectionCalendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get accSectionCalendars;

  /// No description provided for @accSectionVideoMeetings.
  ///
  /// In en, this message translates to:
  /// **'Video meetings'**
  String get accSectionVideoMeetings;

  /// No description provided for @accSignInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Sign in via browser'**
  String get accSignInBrowser;

  /// No description provided for @accStatusAuthError.
  ///
  /// In en, this message translates to:
  /// **'authorization error'**
  String get accStatusAuthError;

  /// No description provided for @accStatusNeedsReconnect.
  ///
  /// In en, this message translates to:
  /// **'reconnection required'**
  String get accStatusNeedsReconnect;

  /// No description provided for @accStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'no network'**
  String get accStatusOffline;

  /// No description provided for @accStatusOk.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get accStatusOk;

  /// No description provided for @accStatusSyncError.
  ///
  /// In en, this message translates to:
  /// **'sync failed'**
  String get accStatusSyncError;

  /// No description provided for @accTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accTitle;

  /// No description provided for @accVisibilityHint.
  ///
  /// In en, this message translates to:
  /// **'Calendar visibility — in Settings → Calendars'**
  String get accVisibilityHint;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Calenfi'**
  String get appTitle;

  /// No description provided for @calCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get calCancel;

  /// No description provided for @calCombineOff.
  ///
  /// In en, this message translates to:
  /// **'Merge identical events (off — each shown separately)'**
  String get calCombineOff;

  /// No description provided for @calCombineOn.
  ///
  /// In en, this message translates to:
  /// **'Merge identical events (on)'**
  String get calCombineOn;

  /// No description provided for @calDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calDay;

  /// No description provided for @calDayShort.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get calDayShort;

  /// No description provided for @calMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calMonth;

  /// No description provided for @calMonthShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get calMonthShort;

  /// No description provided for @calMoveModeHint.
  ///
  /// In en, this message translates to:
  /// **'Move mode: drag events. Tap for details.'**
  String get calMoveModeHint;

  /// No description provided for @calNoTitle.
  ///
  /// In en, this message translates to:
  /// **'No title'**
  String get calNoTitle;

  /// No description provided for @calNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get calNothingFound;

  /// No description provided for @calPendingCount.
  ///
  /// In en, this message translates to:
  /// **'Not sent to cloud: {count}'**
  String calPendingCount(int count);

  /// No description provided for @calPinEvents.
  ///
  /// In en, this message translates to:
  /// **'Pin events'**
  String get calPinEvents;

  /// No description provided for @calSearchFound.
  ///
  /// In en, this message translates to:
  /// **'Found: {count}'**
  String calSearchFound(int count);

  /// No description provided for @calSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search: title, participant, id'**
  String get calSearchHint;

  /// No description provided for @calSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get calSettings;

  /// No description provided for @calShowCancelled.
  ///
  /// In en, this message translates to:
  /// **'Show deleted/cancelled'**
  String get calShowCancelled;

  /// No description provided for @calSortDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get calSortDate;

  /// No description provided for @calSortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get calSortRelevance;

  /// No description provided for @calSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get calSynced;

  /// No description provided for @calToCloud.
  ///
  /// In en, this message translates to:
  /// **'To cloud'**
  String get calToCloud;

  /// No description provided for @calToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calToday;

  /// No description provided for @calUnpinEvents.
  ///
  /// In en, this message translates to:
  /// **'Unpin events (move by dragging)'**
  String get calUnpinEvents;

  /// No description provided for @calViewInDev.
  ///
  /// In en, this message translates to:
  /// **'View under development'**
  String get calViewInDev;

  /// No description provided for @calWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calWeek;

  /// No description provided for @calWeekShort.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get calWeekShort;

  /// No description provided for @detAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get detAccept;

  /// No description provided for @detAllDay.
  ///
  /// In en, this message translates to:
  /// **'all day'**
  String get detAllDay;

  /// No description provided for @detAttendeeCopied.
  ///
  /// In en, this message translates to:
  /// **'Attendee copied'**
  String get detAttendeeCopied;

  /// No description provided for @detAttendeesCount.
  ///
  /// In en, this message translates to:
  /// **'Attendees: {total}  ·  {accepted} accepted'**
  String detAttendeesCount(int total, int accepted);

  /// No description provided for @detCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get detCancel;

  /// No description provided for @detCancelledDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cancelled / deleted'**
  String get detCancelledDeleted;

  /// No description provided for @detConfVideoCall.
  ///
  /// In en, this message translates to:
  /// **'video call'**
  String get detConfVideoCall;

  /// No description provided for @detCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get detCopied;

  /// No description provided for @detCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get detCopy;

  /// No description provided for @detDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get detDecline;

  /// No description provided for @detDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detDelete;

  /// No description provided for @detDeleteEventQ.
  ///
  /// In en, this message translates to:
  /// **'Delete event?'**
  String get detDeleteEventQ;

  /// No description provided for @detEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get detEdit;

  /// No description provided for @detEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get detEditTitle;

  /// No description provided for @detFieldCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String detFieldCopied(String label);

  /// No description provided for @detId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get detId;

  /// No description provided for @detInMultipleCalendars.
  ///
  /// In en, this message translates to:
  /// **'In multiple calendars ({count}):'**
  String detInMultipleCalendars(int count);

  /// No description provided for @detJoin.
  ///
  /// In en, this message translates to:
  /// **'Join · {label}'**
  String detJoin(String label);

  /// No description provided for @detMeetingLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Meeting link copied'**
  String get detMeetingLinkCopied;

  /// No description provided for @detOpenInCloud.
  ///
  /// In en, this message translates to:
  /// **'Open in cloud'**
  String get detOpenInCloud;

  /// No description provided for @detOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get detOptional;

  /// No description provided for @detOrganizer.
  ///
  /// In en, this message translates to:
  /// **'organizer'**
  String get detOrganizer;

  /// No description provided for @detRecurringWhatDelete.
  ///
  /// In en, this message translates to:
  /// **'Recurring event — what to delete?'**
  String get detRecurringWhatDelete;

  /// No description provided for @detRecurringWhatEdit.
  ///
  /// In en, this message translates to:
  /// **'Recurring event — what to change?'**
  String get detRecurringWhatEdit;

  /// No description provided for @detEditWholeSeries.
  ///
  /// In en, this message translates to:
  /// **'Entire series (every occurrence)'**
  String get detEditWholeSeries;

  /// No description provided for @detResponseAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get detResponseAccepted;

  /// No description provided for @detResponseDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get detResponseDeclined;

  /// No description provided for @detResponseNeedsAction.
  ///
  /// In en, this message translates to:
  /// **'Awaiting response'**
  String get detResponseNeedsAction;

  /// No description provided for @detResponseOrganizer.
  ///
  /// In en, this message translates to:
  /// **'You\'re the organizer'**
  String get detResponseOrganizer;

  /// No description provided for @detResponseTentative.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get detResponseTentative;

  /// No description provided for @detSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get detSave;

  /// No description provided for @detTentative.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get detTentative;

  /// No description provided for @detThisAndFollowing.
  ///
  /// In en, this message translates to:
  /// **'This and following'**
  String get detThisAndFollowing;

  /// No description provided for @detThisEventOnly.
  ///
  /// In en, this message translates to:
  /// **'This event only'**
  String get detThisEventOnly;

  /// No description provided for @detTitleChanged.
  ///
  /// In en, this message translates to:
  /// **'Title changed'**
  String get detTitleChanged;

  /// No description provided for @detUnknownCalendar.
  ///
  /// In en, this message translates to:
  /// **'Unknown calendar'**
  String get detUnknownCalendar;

  /// No description provided for @detWholeSeries.
  ///
  /// In en, this message translates to:
  /// **'Entire series'**
  String get detWholeSeries;

  /// No description provided for @edAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get edAllDay;

  /// No description provided for @edAttendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get edAttendees;

  /// No description provided for @edBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get edBusy;

  /// No description provided for @edCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get edCalendar;

  /// No description provided for @edCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get edCancel;

  /// No description provided for @edChoose.
  ///
  /// In en, this message translates to:
  /// **'choose…'**
  String get edChoose;

  /// No description provided for @edConference.
  ///
  /// In en, this message translates to:
  /// **'Video meeting'**
  String get edConference;

  /// No description provided for @edConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect account'**
  String get edConnectAccount;

  /// No description provided for @edDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get edDaily;

  /// No description provided for @edDoNotRepeat.
  ///
  /// In en, this message translates to:
  /// **'Do not repeat'**
  String get edDoNotRepeat;

  /// No description provided for @edDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get edDone;

  /// No description provided for @edEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get edEditEvent;

  /// No description provided for @edEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get edEnd;

  /// No description provided for @edEndAfter.
  ///
  /// In en, this message translates to:
  /// **'End after'**
  String get edEndAfter;

  /// No description provided for @edEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get edEvery;

  /// No description provided for @edEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Every {count} day} other{Every {count} days}}'**
  String edEveryNDays(int count);

  /// No description provided for @edEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Every {count} month} other{Every {count} months}}'**
  String edEveryNMonths(int count);

  /// No description provided for @edEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Every {count} week} other{Every {count} weeks}}'**
  String edEveryNWeeks(int count);

  /// No description provided for @edEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Every {count} year} other{Every {count} years}}'**
  String edEveryNYears(int count);

  /// No description provided for @edFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get edFree;

  /// No description provided for @edFreqDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get edFreqDay;

  /// No description provided for @edFreqMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get edFreqMonth;

  /// No description provided for @edFreqWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get edFreqWeek;

  /// No description provided for @edFreqYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get edFreqYear;

  /// No description provided for @edFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get edFri;

  /// No description provided for @edFridayAcc.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get edFridayAcc;

  /// No description provided for @edInviteeHint.
  ///
  /// In en, this message translates to:
  /// **'Name from contacts or email'**
  String get edInviteeHint;

  /// No description provided for @edLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get edLocationHint;

  /// No description provided for @edMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get edMon;

  /// No description provided for @edMondayAcc.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get edMondayAcc;

  /// No description provided for @edMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get edMonthly;

  /// No description provided for @edNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get edNewEvent;

  /// No description provided for @edNoEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date'**
  String get edNoEndDate;

  /// No description provided for @edNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get edNone;

  /// No description provided for @edNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get edNotesHint;

  /// No description provided for @edOccurrences.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} occurrence} other{{count} occurrences}}'**
  String edOccurrences(int count);

  /// No description provided for @edOccurrencesLabel.
  ///
  /// In en, this message translates to:
  /// **'occurrences'**
  String get edOccurrencesLabel;

  /// No description provided for @edOnDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'on day {day}'**
  String edOnDayOfMonth(int day);

  /// No description provided for @edOrdinal1.
  ///
  /// In en, this message translates to:
  /// **'on the 1st'**
  String get edOrdinal1;

  /// No description provided for @edOrdinal2.
  ///
  /// In en, this message translates to:
  /// **'on the 2nd'**
  String get edOrdinal2;

  /// No description provided for @edOrdinal3.
  ///
  /// In en, this message translates to:
  /// **'on the 3rd'**
  String get edOrdinal3;

  /// No description provided for @edOrdinal4.
  ///
  /// In en, this message translates to:
  /// **'on the 4th'**
  String get edOrdinal4;

  /// No description provided for @edOrdinalLast.
  ///
  /// In en, this message translates to:
  /// **'on the last'**
  String get edOrdinalLast;

  /// No description provided for @edOrdinalN.
  ///
  /// In en, this message translates to:
  /// **'on the {number}th'**
  String edOrdinalN(int number);

  /// No description provided for @edRecurrenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurrence'**
  String get edRecurrenceTitle;

  /// No description provided for @edRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get edRepeat;

  /// No description provided for @edSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get edSat;

  /// No description provided for @edSaturdayAcc.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get edSaturdayAcc;

  /// No description provided for @edSeriesInstance.
  ///
  /// In en, this message translates to:
  /// **'Series instance — rule applies to the whole series'**
  String get edSeriesInstance;

  /// No description provided for @edShowAs.
  ///
  /// In en, this message translates to:
  /// **'Show as'**
  String get edShowAs;

  /// No description provided for @edStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get edStart;

  /// No description provided for @edSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get edSun;

  /// No description provided for @edSundayAcc.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get edSundayAcc;

  /// No description provided for @edThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get edThu;

  /// No description provided for @edThursdayAcc.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get edThursdayAcc;

  /// No description provided for @edTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get edTitleHint;

  /// No description provided for @edTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get edTue;

  /// No description provided for @edTuesdayAcc.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get edTuesdayAcc;

  /// No description provided for @edUnitDay.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get edUnitDay;

  /// No description provided for @edUnitMonth.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get edUnitMonth;

  /// No description provided for @edUnitWeek.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get edUnitWeek;

  /// No description provided for @edUnitYear.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get edUnitYear;

  /// No description provided for @edUntil.
  ///
  /// In en, this message translates to:
  /// **'Until date'**
  String get edUntil;

  /// No description provided for @edUntilDate.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String edUntilDate(String date);

  /// No description provided for @edUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get edUntitled;

  /// No description provided for @edVisDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get edVisDefault;

  /// No description provided for @edVisPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get edVisPrivate;

  /// No description provided for @edVisPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get edVisPublic;

  /// No description provided for @edVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get edVisibility;

  /// No description provided for @edWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get edWed;

  /// No description provided for @edWednesdayAcc.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get edWednesdayAcc;

  /// No description provided for @edWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get edWeekly;

  /// No description provided for @edYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get edYearly;

  /// No description provided for @setAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setAbout;

  /// No description provided for @setAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local-first calendar aggregator · MVP'**
  String get setAboutSubtitle;

  /// No description provided for @setAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get setAccounts;

  /// No description provided for @setAccountsAndConnections.
  ///
  /// In en, this message translates to:
  /// **'Accounts & connections'**
  String get setAccountsAndConnections;

  /// No description provided for @setAccountsConnected.
  ///
  /// In en, this message translates to:
  /// **'{count} connected'**
  String setAccountsConnected(int count);

  /// No description provided for @setCalendarNameHint.
  ///
  /// In en, this message translates to:
  /// **'Calendar name'**
  String get setCalendarNameHint;

  /// No description provided for @setCalendars.
  ///
  /// In en, this message translates to:
  /// **'Calendars'**
  String get setCalendars;

  /// No description provided for @setCalendarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which calendars to show in the grid'**
  String get setCalendarsSubtitle;

  /// No description provided for @setCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get setCancel;

  /// No description provided for @setColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Color: {name}'**
  String setColorTitle(String name);

  /// No description provided for @setCombine.
  ///
  /// In en, this message translates to:
  /// **'Merge meetings'**
  String get setCombine;

  /// No description provided for @setCombineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Merge identical events from different calendars. Turn off — each meeting stays separate, so you can work with every copy'**
  String get setCombineSubtitle;

  /// No description provided for @setCommitDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay before sending changes'**
  String get setCommitDelay;

  /// No description provided for @setCommitDelaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move/resize wait before going to the cloud: dashed outline + countdown + \"apply now\". 0 — instantly.'**
  String get setCommitDelaySubtitle;

  /// No description provided for @setDelayImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get setDelayImmediate;

  /// No description provided for @setDelayMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String setDelayMinutes(int count);

  /// No description provided for @setEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get setEvents;

  /// No description provided for @setFromSource.
  ///
  /// In en, this message translates to:
  /// **'From source: {name}'**
  String setFromSource(String name);

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get setLanguageSystem;

  /// No description provided for @setMaps.
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get setMaps;

  /// No description provided for @setMapsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Yandex Maps by default'**
  String get setMapsSubtitle;

  /// No description provided for @setNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts'**
  String get setNoAccounts;

  /// No description provided for @setNoCalendars.
  ///
  /// In en, this message translates to:
  /// **'no calendars'**
  String get setNoCalendars;

  /// No description provided for @setOpenPlacesIn.
  ///
  /// In en, this message translates to:
  /// **'Open places in'**
  String get setOpenPlacesIn;

  /// No description provided for @setReminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'at start'**
  String get setReminderAtStart;

  /// No description provided for @setReminderAtStartFull.
  ///
  /// In en, this message translates to:
  /// **'At start time'**
  String get setReminderAtStartFull;

  /// No description provided for @setReminderHours.
  ///
  /// In en, this message translates to:
  /// **'{count} h before'**
  String setReminderHours(int count);

  /// No description provided for @setReminderMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min before'**
  String setReminderMinutes(int count);

  /// No description provided for @setReminderNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get setReminderNone;

  /// No description provided for @setReminderNoneFull.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get setReminderNoneFull;

  /// No description provided for @setReminderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default for events in this calendar'**
  String get setReminderSubtitle;

  /// No description provided for @setReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder: {name}'**
  String setReminderTitle(String name);

  /// No description provided for @setRenameCalendar.
  ///
  /// In en, this message translates to:
  /// **'Rename calendar'**
  String get setRenameCalendar;

  /// No description provided for @setReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get setReset;

  /// No description provided for @setResetColor.
  ///
  /// In en, this message translates to:
  /// **'Reset to source color'**
  String get setResetColor;

  /// No description provided for @setSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get setSave;

  /// No description provided for @setShowCancelled.
  ///
  /// In en, this message translates to:
  /// **'Show deleted/cancelled'**
  String get setShowCancelled;

  /// No description provided for @setShowCancelledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'In a strikethrough style'**
  String get setShowCancelledSubtitle;

  /// No description provided for @setShowMonth.
  ///
  /// In en, this message translates to:
  /// **'Show month view'**
  String get setShowMonth;

  /// No description provided for @setShowMonthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The month is cramped on a phone — you can hide it'**
  String get setShowMonthSubtitle;

  /// No description provided for @setTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setTitle;

  /// No description provided for @setView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get setView;

  /// No description provided for @uiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uiCancel;

  /// No description provided for @uiError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String uiError(String error);

  /// No description provided for @uiMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get uiMove;

  /// No description provided for @uiMoveEventBody.
  ///
  /// In en, this message translates to:
  /// **'«{title}»\n\n{range}'**
  String uiMoveEventBody(String title, String range);

  /// No description provided for @uiMoveEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Move event?'**
  String get uiMoveEventTitle;

  /// No description provided for @uiNoTitle.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get uiNoTitle;

  /// No description provided for @uiNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated: {accounts}'**
  String uiNotUpdated(String accounts);

  /// No description provided for @uiReasonAuthError.
  ///
  /// In en, this message translates to:
  /// **'auth error'**
  String get uiReasonAuthError;

  /// No description provided for @uiReasonFailure.
  ///
  /// In en, this message translates to:
  /// **'failure'**
  String get uiReasonFailure;

  /// No description provided for @uiReasonNeedsReconnect.
  ///
  /// In en, this message translates to:
  /// **'reconnecting'**
  String get uiReasonNeedsReconnect;

  /// No description provided for @uiReasonOffline.
  ///
  /// In en, this message translates to:
  /// **'no network'**
  String get uiReasonOffline;

  /// No description provided for @uiRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get uiRetry;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return L10nDe();
    case 'en':
      return L10nEn();
    case 'es':
      return L10nEs();
    case 'fr':
      return L10nFr();
    case 'ru':
      return L10nRu();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
