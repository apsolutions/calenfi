// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get accAddAccount => 'Ajouter un compte';

  @override
  String get accAppPassword => 'Mot de passe d\'application';

  @override
  String get accAppPasswordHelper =>
      'PAS le mot de passe principal de la messagerie — créez un mot de passe d\'application';

  @override
  String get accAutoRefresh => 'Actualisation automatique';

  @override
  String get accCaldavPasswordHelper =>
      'Pour CalDAV — un mot de passe d\'application, pas celui de la messagerie';

  @override
  String get accCancel => 'Annuler';

  @override
  String get accChangePassword => 'Modifier le mot de passe';

  @override
  String accCompleteSignIn(String name) {
    return '$name : terminez la connexion dans le navigateur qui s\'est ouvert…';
  }

  @override
  String get accConnect => 'Connecter';

  @override
  String get accConnectAccount => 'Connecter un compte';

  @override
  String accConnected(String email) {
    return 'Connecté : $email';
  }

  @override
  String get accConnecting => 'Connexion…';

  @override
  String get accDelete => 'Supprimer';

  @override
  String get accEmail => 'E-mail';

  @override
  String accError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get accEwsUrlLabel => 'URL EWS (facultatif)';

  @override
  String accFailed(String error) {
    return 'Échec : $error';
  }

  @override
  String get accFillEmailPassword => 'Renseignez l\'e-mail et le mot de passe';

  @override
  String get accHidden => 'masqué';

  @override
  String get accHost => 'Hôte';

  @override
  String get accHour1 => '1 h';

  @override
  String get accLoginIfDifferent => 'Identifiant (si différent)';

  @override
  String get accLoginPassword => 'Identifiant et mot de passe';

  @override
  String get accManual => 'Manuel';

  @override
  String accMinutes(int count) {
    return '$count min';
  }

  @override
  String get accNewPassword => 'Nouveau mot de passe';

  @override
  String get accNoCalendars => 'Aucun calendrier';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return 'La connexion à $name n\'est pas configurée';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return 'Cette version de Calenfi ne contient pas de client OAuth pour $name : la connexion dans le navigateur ne peut pas démarrer. Saisissez le client de votre application OAuth (URI de redirection http://localhost) ; il sera conservé dans le stockage sécurisé de l\'appareil.';
  }

  @override
  String get accOAuthClientId => 'ID client';

  @override
  String get accOAuthClientSecret => 'Secret client';

  @override
  String get accSaveAndSignIn => 'Enregistrer et se connecter';

  @override
  String get accPassword => 'Mot de passe';

  @override
  String get accPasswordSaved => 'Mot de passe enregistré, synchronisation…';

  @override
  String get accPort => 'Port';

  @override
  String get accSave => 'Enregistrer';

  @override
  String get accSectionCalendars => 'Calendriers';

  @override
  String get accSectionVideoMeetings => 'Visioconférences';

  @override
  String get accSignInBrowser => 'Connexion via le navigateur';

  @override
  String get accStatusAuthError => 'erreur d\'autorisation';

  @override
  String get accStatusNeedsReconnect => 'reconnexion requise';

  @override
  String get accStatusOffline => 'hors ligne';

  @override
  String get accStatusOk => 'connecté';

  @override
  String get accStatusSyncError => 'échec de synchronisation';

  @override
  String get accTitle => 'Comptes';

  @override
  String get accVisibilityHint =>
      'Visibilité des calendriers — dans Réglages → Calendriers';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => 'Annuler';

  @override
  String get calCombineOff =>
      'Fusionner les événements identiques (désactivé — chacun séparément)';

  @override
  String get calCombineOn => 'Fusionner les événements identiques (activé)';

  @override
  String get calDay => 'Jour';

  @override
  String get calDayShort => 'J';

  @override
  String get calMonth => 'Mois';

  @override
  String get calMonthShort => 'M';

  @override
  String get calMoveModeHint =>
      'Mode déplacement : faites glisser les événements. Touchez pour les détails.';

  @override
  String get calNoTitle => 'Sans titre';

  @override
  String get calNothingFound => 'Aucun résultat';

  @override
  String calPendingCount(int count) {
    return 'Non envoyé au cloud : $count';
  }

  @override
  String get calPinEvents => 'Épingler les événements';

  @override
  String calSearchFound(int count) {
    return 'Trouvés : $count';
  }

  @override
  String get calSearchHint => 'Rechercher : titre, participant, id';

  @override
  String get calSettings => 'Paramètres';

  @override
  String get calShowCancelled => 'Afficher les supprimés/annulés';

  @override
  String get calSortDate => 'Date';

  @override
  String get calSortRelevance => 'Pertinence';

  @override
  String get calSynced => 'Synchronisé';

  @override
  String get calToCloud => 'Vers le cloud';

  @override
  String get calToday => 'Aujourd\'hui';

  @override
  String get calUnpinEvents =>
      'Désépingler les événements (déplacer en glissant)';

  @override
  String get calViewInDev => 'Vue en développement';

  @override
  String get calWeek => 'Semaine';

  @override
  String get calWeekShort => 'S';

  @override
  String get detAccept => 'Accepter';

  @override
  String get detAllDay => 'toute la journée';

  @override
  String get detAttendeeCopied => 'Participant copié';

  @override
  String detAttendeesCount(int total, int accepted) {
    return 'Participants : $total  ·  $accepted ont accepté';
  }

  @override
  String get detCancel => 'Annuler';

  @override
  String get detCancelledDeleted => 'Annulé / supprimé';

  @override
  String get detConfVideoCall => 'visioconférence';

  @override
  String get detCopied => 'Copié';

  @override
  String get detCopy => 'Copier';

  @override
  String get detDecline => 'Refuser';

  @override
  String get detDelete => 'Supprimer';

  @override
  String get detDeleteEventQ => 'Supprimer l\'événement ?';

  @override
  String get detEdit => 'Modifier';

  @override
  String get detEditTitle => 'Modifier le titre';

  @override
  String detFieldCopied(String label) {
    return '$label copié';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return 'Dans plusieurs agendas ($count) :';
  }

  @override
  String detJoin(String label) {
    return 'Rejoindre · $label';
  }

  @override
  String get detMeetingLinkCopied => 'Lien de la réunion copié';

  @override
  String get detOpenInCloud => 'Ouvrir dans le cloud';

  @override
  String get detOptional => 'facultatif';

  @override
  String get detOrganizer => 'organisateur';

  @override
  String get detRecurringWhatDelete => 'Événement récurrent — que supprimer ?';

  @override
  String get detRecurringWhatEdit => 'Événement récurrent — que modifier ?';

  @override
  String get detEditWholeSeries => 'Toute la série (toutes les occurrences)';

  @override
  String get detResponseAccepted => 'Accepté';

  @override
  String get detResponseDeclined => 'Refusé';

  @override
  String get detResponseNeedsAction => 'En attente de réponse';

  @override
  String get detResponseOrganizer => 'Vous êtes l\'organisateur';

  @override
  String get detResponseTentative => 'Peut-être';

  @override
  String get detSave => 'Enregistrer';

  @override
  String get detTentative => 'Peut-être';

  @override
  String get detThisAndFollowing => 'Cet événement et les suivants';

  @override
  String get detThisEventOnly => 'Cet événement uniquement';

  @override
  String get detTitleChanged => 'Titre modifié';

  @override
  String get detUnknownCalendar => 'Agenda inconnu';

  @override
  String get detWholeSeries => 'Toute la série';

  @override
  String get edAllDay => 'Toute la journée';

  @override
  String get edAttendees => 'Participants';

  @override
  String get edBusy => 'Occupé';

  @override
  String get edCalendar => 'Agenda';

  @override
  String get edCancel => 'Annuler';

  @override
  String get edChoose => 'choisir…';

  @override
  String get edConference => 'Visioconférence';

  @override
  String get edConnectAccount => 'Connecter un compte';

  @override
  String get edDaily => 'Tous les jours';

  @override
  String get edDoNotRepeat => 'Ne pas répéter';

  @override
  String get edDone => 'Terminé';

  @override
  String get edEditEvent => 'Modifier l\'événement';

  @override
  String get edEnd => 'Fin';

  @override
  String get edEndAfter => 'Se termine après';

  @override
  String get edEvery => 'Tous les';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tous les $count jours',
      one: 'Tous les $count jour',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tous les $count mois',
      one: 'Tous les $count mois',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toutes les $count semaines',
      one: 'Toutes les $count semaine',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tous les $count ans',
      one: 'Tous les $count an',
    );
    return '$_temp0';
  }

  @override
  String get edFree => 'Libre';

  @override
  String get edFreqDay => 'Jour';

  @override
  String get edFreqMonth => 'Mois';

  @override
  String get edFreqWeek => 'Semaine';

  @override
  String get edFreqYear => 'Année';

  @override
  String get edFri => 'Ven';

  @override
  String get edFridayAcc => 'vendredi';

  @override
  String get edInviteeHint => 'Nom du contact ou e-mail';

  @override
  String get edLocationHint => 'Lieu';

  @override
  String get edMon => 'Lun';

  @override
  String get edMondayAcc => 'lundi';

  @override
  String get edMonthly => 'Tous les mois';

  @override
  String get edNewEvent => 'Nouvel événement';

  @override
  String get edNoEndDate => 'Sans date de fin';

  @override
  String get edNone => 'Aucune';

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
    return 'le $day';
  }

  @override
  String get edOrdinal1 => 'le 1er';

  @override
  String get edOrdinal2 => 'le 2e';

  @override
  String get edOrdinal3 => 'le 3e';

  @override
  String get edOrdinal4 => 'le 4e';

  @override
  String get edOrdinalLast => 'le dernier';

  @override
  String edOrdinalN(int number) {
    return 'le ${number}e';
  }

  @override
  String get edRecurrenceTitle => 'Récurrence';

  @override
  String get edRepeat => 'Répéter';

  @override
  String get edSat => 'Sam';

  @override
  String get edSaturdayAcc => 'samedi';

  @override
  String get edSeriesInstance =>
      'Occurrence de la série — la règle s\'applique à toute la série';

  @override
  String get edShowAs => 'Afficher comme';

  @override
  String get edStart => 'Début';

  @override
  String get edSun => 'Dim';

  @override
  String get edSundayAcc => 'dimanche';

  @override
  String get edThu => 'Jeu';

  @override
  String get edThursdayAcc => 'jeudi';

  @override
  String get edTitleHint => 'Titre';

  @override
  String get edTue => 'Mar';

  @override
  String get edTuesdayAcc => 'mardi';

  @override
  String get edUnitDay => 'jours';

  @override
  String get edUnitMonth => 'mois';

  @override
  String get edUnitWeek => 'semaines';

  @override
  String get edUnitYear => 'ans';

  @override
  String get edUntil => 'Jusqu\'à la date';

  @override
  String edUntilDate(String date) {
    return 'jusqu\'au $date';
  }

  @override
  String get edUntitled => 'Sans titre';

  @override
  String get edVisDefault => 'Par défaut';

  @override
  String get edVisPrivate => 'Privé';

  @override
  String get edVisPublic => 'Public';

  @override
  String get edVisibility => 'Visibilité';

  @override
  String get edWed => 'Mer';

  @override
  String get edWednesdayAcc => 'mercredi';

  @override
  String get edWeekly => 'Toutes les semaines';

  @override
  String get edYearly => 'Tous les ans';

  @override
  String get setAbout => 'À propos';

  @override
  String get setAboutSubtitle => 'Agrégateur de calendriers local-first · MVP';

  @override
  String get setAccounts => 'Comptes';

  @override
  String get setAccountsAndConnections => 'Comptes et connexions';

  @override
  String setAccountsConnected(int count) {
    return '$count connecté(s)';
  }

  @override
  String get setCalendarNameHint => 'Nom du calendrier';

  @override
  String get setCalendars => 'Calendriers';

  @override
  String get setCalendarsSubtitle =>
      'Quels calendriers afficher dans la grille';

  @override
  String get setCancel => 'Annuler';

  @override
  String setColorTitle(String name) {
    return 'Couleur : $name';
  }

  @override
  String get setCombine => 'Fusionner les réunions';

  @override
  String get setCombineSubtitle =>
      'Regrouper les événements identiques de différents calendriers. Désactivez pour garder chaque réunion séparée et travailler sur chaque copie';

  @override
  String get setCommitDelay => 'Délai avant l\'envoi des modifications';

  @override
  String get setCommitDelaySubtitle =>
      'Le déplacement/redimensionnement attend avant l\'envoi vers le cloud : contour pointillé + compte à rebours + « appliquer maintenant ». 0 — immédiatement.';

  @override
  String get setDelayImmediate => 'Immédiatement';

  @override
  String setDelayMinutes(int count) {
    return '$count min';
  }

  @override
  String get setEvents => 'Événements';

  @override
  String setFromSource(String name) {
    return 'Depuis la source : $name';
  }

  @override
  String get setLanguage => 'Langue';

  @override
  String get setLanguageSystem => 'Système';

  @override
  String get setMaps => 'Cartes';

  @override
  String get setMapsSubtitle => 'Yandex Maps par défaut';

  @override
  String get setNoAccounts => 'Aucun compte';

  @override
  String get setNoCalendars => 'aucun calendrier';

  @override
  String get setOpenPlacesIn => 'Ouvrir les lieux dans';

  @override
  String get setReminderAtStart => 'au début';

  @override
  String get setReminderAtStartFull => 'À l\'heure de début';

  @override
  String setReminderHours(int count) {
    return '$count h avant';
  }

  @override
  String setReminderMinutes(int count) {
    return '$count min avant';
  }

  @override
  String get setReminderNone => 'aucun';

  @override
  String get setReminderNoneFull => 'Aucun rappel';

  @override
  String get setReminderSubtitle =>
      'Par défaut pour les événements de ce calendrier';

  @override
  String setReminderTitle(String name) {
    return 'Rappel : $name';
  }

  @override
  String get setRenameCalendar => 'Renommer le calendrier';

  @override
  String get setReset => 'Réinitialiser';

  @override
  String get setResetColor => 'Réinitialiser à la couleur source';

  @override
  String get setSave => 'Enregistrer';

  @override
  String get setShowCancelled => 'Afficher les supprimés/annulés';

  @override
  String get setShowCancelledSubtitle => 'En style barré';

  @override
  String get setShowMonth => 'Afficher la vue mensuelle';

  @override
  String get setShowMonthSubtitle =>
      'Sur téléphone, le mois est à l\'étroit — vous pouvez le masquer';

  @override
  String get setTitle => 'Paramètres';

  @override
  String get setView => 'Affichage';

  @override
  String get uiCancel => 'Annuler';

  @override
  String uiError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get uiMove => 'Déplacer';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => 'Déplacer l\'événement ?';

  @override
  String get uiNoTitle => 'Sans titre';

  @override
  String uiNotUpdated(String accounts) {
    return 'Non mis à jour : $accounts';
  }

  @override
  String get uiReasonAuthError => 'erreur d\'authentification';

  @override
  String get uiReasonFailure => 'échec';

  @override
  String get uiReasonNeedsReconnect => 'reconnexion';

  @override
  String get uiReasonOffline => 'hors ligne';

  @override
  String get uiRetry => 'Réessayer';
}
