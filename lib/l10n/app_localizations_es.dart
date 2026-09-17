// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class L10nEs extends L10n {
  L10nEs([String locale = 'es']) : super(locale);

  @override
  String get accAddAccount => 'Añadir cuenta';

  @override
  String get accAppPassword => 'Contraseña de aplicación';

  @override
  String get accAppPasswordHelper =>
      'NO la contraseña principal del correo: crea una contraseña de aplicación';

  @override
  String get accAutoRefresh => 'Actualización automática';

  @override
  String get accCaldavPasswordHelper =>
      'Para CalDAV: una contraseña de aplicación, no la principal del correo';

  @override
  String get accCancel => 'Cancelar';

  @override
  String get accChangePassword => 'Cambiar contraseña';

  @override
  String accCompleteSignIn(String name) {
    return '$name: completa el inicio de sesión en el navegador abierto…';
  }

  @override
  String get accConnect => 'Conectar';

  @override
  String get accConnectAccount => 'Conectar cuenta';

  @override
  String accConnected(String email) {
    return 'Conectado: $email';
  }

  @override
  String get accConnecting => 'Conectando…';

  @override
  String get accDelete => 'Eliminar';

  @override
  String get accEmail => 'Correo electrónico';

  @override
  String accError(String error) {
    return 'Error: $error';
  }

  @override
  String get accEwsUrlLabel => 'URL de EWS (opcional)';

  @override
  String accFailed(String error) {
    return 'Error: $error';
  }

  @override
  String get accFillEmailPassword => 'Rellena el correo y la contraseña';

  @override
  String get accHidden => 'oculto';

  @override
  String get accHost => 'Host';

  @override
  String get accHour1 => '1 h';

  @override
  String get accLoginIfDifferent => 'Usuario (si es distinto)';

  @override
  String get accLoginPassword => 'Usuario y contraseña';

  @override
  String get accManual => 'Manual';

  @override
  String accMinutes(int count) {
    return '$count min';
  }

  @override
  String get accNewPassword => 'Nueva contraseña';

  @override
  String get accNoCalendars => 'Sin calendarios';

  @override
  String accOAuthNotConfiguredTitle(String name) {
    return 'El inicio de sesión de $name no está configurado';
  }

  @override
  String accOAuthNotConfiguredBody(String name) {
    return 'Esta versión de Calenfi no incluye un cliente OAuth de $name, así que no se puede iniciar sesión en el navegador. Introduce el cliente de tu aplicación OAuth (URI de redirección http://localhost); se guardará en el almacenamiento seguro del dispositivo.';
  }

  @override
  String get accOAuthClientId => 'ID de cliente';

  @override
  String get accOAuthClientSecret => 'Secreto de cliente';

  @override
  String get accSaveAndSignIn => 'Guardar e iniciar sesión';

  @override
  String get accPassword => 'Contraseña';

  @override
  String get accPasswordSaved => 'Contraseña guardada, sincronizando…';

  @override
  String get accReconnect => 'Volver a conectar';

  @override
  String get accPort => 'Puerto';

  @override
  String get accSave => 'Guardar';

  @override
  String get accSectionCalendars => 'Calendarios';

  @override
  String get accSectionVideoMeetings => 'Videollamadas';

  @override
  String get accSignInBrowser => 'Iniciar sesión en el navegador';

  @override
  String get accStatusAuthError => 'error de autorización';

  @override
  String get accStatusNeedsReconnect => 'requiere reconexión';

  @override
  String get accStatusOffline => 'sin conexión';

  @override
  String get accStatusOk => 'conectado';

  @override
  String get accStatusSyncError => 'error de sincronización';

  @override
  String get accTitle => 'Cuentas';

  @override
  String get accVisibilityHint =>
      'Visibilidad de calendarios: en Ajustes → Calendarios';

  @override
  String get appTitle => 'Calenfi';

  @override
  String get calCancel => 'Cancelar';

  @override
  String get calCombineOff =>
      'Combinar eventos idénticos (desactivado — cada uno por separado)';

  @override
  String get calCombineOn => 'Combinar eventos idénticos (activado)';

  @override
  String get calDay => 'Día';

  @override
  String get calDayShort => 'D';

  @override
  String get calMonth => 'Mes';

  @override
  String get calMonthShort => 'M';

  @override
  String get calMoveModeHint =>
      'Modo de mover: arrastra los eventos. Toca para ver detalles.';

  @override
  String get calNoTitle => 'Sin título';

  @override
  String get calNothingFound => 'No se encontró nada';

  @override
  String calPendingCount(int count) {
    return 'No enviado a la nube: $count';
  }

  @override
  String get calPinEvents => 'Fijar eventos';

  @override
  String calSearchFound(int count) {
    return 'Encontrados: $count';
  }

  @override
  String get calSearchHint => 'Buscar: título, participante, id';

  @override
  String get calSettings => 'Ajustes';

  @override
  String get calShowCancelled => 'Mostrar eliminados/cancelados';

  @override
  String get calSortDate => 'Fecha';

  @override
  String get calSortRelevance => 'Relevancia';

  @override
  String get calSynced => 'Sincronizado';

  @override
  String get calToCloud => 'A la nube';

  @override
  String get calToday => 'Hoy';

  @override
  String get calUnpinEvents => 'Desfijar eventos (mover arrastrando)';

  @override
  String get calViewInDev => 'Vista en desarrollo';

  @override
  String get calWeek => 'Semana';

  @override
  String get calWeekShort => 'S';

  @override
  String get detAccept => 'Aceptar';

  @override
  String get detAllDay => 'todo el día';

  @override
  String get detAttendeeCopied => 'Asistente copiado';

  @override
  String detAttendeesCount(int total, int accepted) {
    return 'Asistentes: $total  ·  $accepted han aceptado';
  }

  @override
  String get detCancel => 'Cancelar';

  @override
  String get detCancelledDeleted => 'Cancelado / eliminado';

  @override
  String get detConfVideoCall => 'videollamada';

  @override
  String get detCopied => 'Copiado';

  @override
  String get detCopy => 'Copiar';

  @override
  String get detDecline => 'Rechazar';

  @override
  String get detDelete => 'Eliminar';

  @override
  String get detDeleteEventQ => '¿Eliminar evento?';

  @override
  String get detEdit => 'Editar';

  @override
  String get detEditTitle => 'Editar título';

  @override
  String detFieldCopied(String label) {
    return '$label copiado';
  }

  @override
  String get detId => 'ID';

  @override
  String detInMultipleCalendars(int count) {
    return 'En varios calendarios ($count):';
  }

  @override
  String detJoin(String label) {
    return 'Unirse · $label';
  }

  @override
  String get detMeetingLinkCopied => 'Enlace de la reunión copiado';

  @override
  String get detOpenInCloud => 'Abrir en la nube';

  @override
  String get detOptional => 'opcional';

  @override
  String get detOrganizer => 'organizador';

  @override
  String get detRecurringWhatDelete => 'Evento periódico: ¿qué eliminar?';

  @override
  String get detRecurringWhatEdit => 'Evento periódico: ¿qué cambiar?';

  @override
  String get detEditWholeSeries => 'Toda la serie (todas las repeticiones)';

  @override
  String get detResponseAccepted => 'Aceptado';

  @override
  String get detResponseDeclined => 'Rechazado';

  @override
  String get detResponseNeedsAction => 'Esperando respuesta';

  @override
  String get detResponseOrganizer => 'Eres el organizador';

  @override
  String get detResponseTentative => 'Quizás';

  @override
  String get detSave => 'Guardar';

  @override
  String get detTentative => 'Quizás';

  @override
  String get detThisAndFollowing => 'Este y los siguientes';

  @override
  String get detThisEventOnly => 'Solo este evento';

  @override
  String get detTitleChanged => 'Título cambiado';

  @override
  String get detUnknownCalendar => 'Calendario desconocido';

  @override
  String get detWholeSeries => 'Toda la serie';

  @override
  String get edAllDay => 'Todo el día';

  @override
  String get edAttendees => 'Participantes';

  @override
  String get edBusy => 'Ocupado';

  @override
  String get edCalendar => 'Calendario';

  @override
  String get edCancel => 'Cancelar';

  @override
  String get edChoose => 'elegir…';

  @override
  String get edConference => 'Videollamada';

  @override
  String get edConnectAccount => 'Conectar cuenta';

  @override
  String get edDaily => 'Diariamente';

  @override
  String get edDoNotRepeat => 'No repetir';

  @override
  String get edDone => 'Hecho';

  @override
  String get edEditEvent => 'Editar evento';

  @override
  String get edEnd => 'Fin';

  @override
  String get edEndAfter => 'Finalizar después de';

  @override
  String get edEvery => 'Cada';

  @override
  String edEveryNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count días',
      one: 'Cada $count día',
    );
    return '$_temp0';
  }

  @override
  String edEveryNMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count meses',
      one: 'Cada $count mes',
    );
    return '$_temp0';
  }

  @override
  String edEveryNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count semanas',
      one: 'Cada $count semana',
    );
    return '$_temp0';
  }

  @override
  String edEveryNYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cada $count años',
      one: 'Cada $count año',
    );
    return '$_temp0';
  }

  @override
  String get edFree => 'Libre';

  @override
  String get edFreqDay => 'Día';

  @override
  String get edFreqMonth => 'Mes';

  @override
  String get edFreqWeek => 'Semana';

  @override
  String get edFreqYear => 'Año';

  @override
  String get edFri => 'Vie';

  @override
  String get edFridayAcc => 'viernes';

  @override
  String get edInviteeHint => 'Nombre de contactos o correo';

  @override
  String get edLocationHint => 'Ubicación';

  @override
  String get edMon => 'Lun';

  @override
  String get edMondayAcc => 'lunes';

  @override
  String get edMonthly => 'Mensualmente';

  @override
  String get edNewEvent => 'Nuevo evento';

  @override
  String get edNoEndDate => 'Sin fecha de fin';

  @override
  String get edNone => 'Ninguna';

  @override
  String get edNotesHint => 'Notas';

  @override
  String edOccurrences(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repeticiones',
      one: '$count repetición',
    );
    return '$_temp0';
  }

  @override
  String get edOccurrencesLabel => 'repeticiones';

  @override
  String edOnDayOfMonth(int day) {
    return 'el día $day';
  }

  @override
  String get edOrdinal1 => 'el 1.º';

  @override
  String get edOrdinal2 => 'el 2.º';

  @override
  String get edOrdinal3 => 'el 3.º';

  @override
  String get edOrdinal4 => 'el 4.º';

  @override
  String get edOrdinalLast => 'el último';

  @override
  String edOrdinalN(int number) {
    return 'el $number.º';
  }

  @override
  String get edRecurrenceTitle => 'Repetición';

  @override
  String get edRepeat => 'Repetir';

  @override
  String get edSat => 'Sáb';

  @override
  String get edSaturdayAcc => 'sábado';

  @override
  String get edSeriesInstance =>
      'Instancia de la serie: la regla se aplica a toda la serie';

  @override
  String get edShowAs => 'Mostrar como';

  @override
  String get edStart => 'Inicio';

  @override
  String get edSun => 'Dom';

  @override
  String get edSundayAcc => 'domingo';

  @override
  String get edThu => 'Jue';

  @override
  String get edThursdayAcc => 'jueves';

  @override
  String get edTitleHint => 'Título';

  @override
  String get edTue => 'Mar';

  @override
  String get edTuesdayAcc => 'martes';

  @override
  String get edUnitDay => 'días';

  @override
  String get edUnitMonth => 'meses';

  @override
  String get edUnitWeek => 'semanas';

  @override
  String get edUnitYear => 'años';

  @override
  String get edUntil => 'Hasta la fecha';

  @override
  String edUntilDate(String date) {
    return 'hasta $date';
  }

  @override
  String get edUntitled => 'Sin título';

  @override
  String get edVisDefault => 'Predeterminada';

  @override
  String get edVisPrivate => 'Privada';

  @override
  String get edVisPublic => 'Pública';

  @override
  String get edVisibility => 'Visibilidad';

  @override
  String get edWed => 'Mié';

  @override
  String get edWednesdayAcc => 'miércoles';

  @override
  String get edWeekly => 'Semanalmente';

  @override
  String get edYearly => 'Anualmente';

  @override
  String get setAbout => 'Acerca de';

  @override
  String get setAboutSubtitle => 'Agregador de calendarios local-first · MVP';

  @override
  String get setAccounts => 'Cuentas';

  @override
  String get setAccountsAndConnections => 'Cuentas y conexiones';

  @override
  String setAccountsConnected(int count) {
    return '$count conectadas';
  }

  @override
  String get setCalendarNameHint => 'Nombre del calendario';

  @override
  String get setCalendars => 'Calendarios';

  @override
  String get setCalendarsSubtitle => 'Qué calendarios mostrar en la cuadrícula';

  @override
  String get setCancel => 'Cancelar';

  @override
  String setColorTitle(String name) {
    return 'Color: $name';
  }

  @override
  String get setCombine => 'Combinar reuniones';

  @override
  String get setCombineSubtitle =>
      'Unir eventos idénticos de distintos calendarios. Desactiva para mantener cada reunión por separado y poder trabajar con cada copia';

  @override
  String get setCommitDelay => 'Retraso antes de enviar cambios';

  @override
  String get setCommitDelaySubtitle =>
      'Mover/redimensionar esperan antes de subir a la nube: contorno punteado + cuenta atrás + «aplicar ahora». 0: al instante.';

  @override
  String get setDelayImmediate => 'Al instante';

  @override
  String setDelayMinutes(int count) {
    return '$count min';
  }

  @override
  String get setEvents => 'Eventos';

  @override
  String setFromSource(String name) {
    return 'Del origen: $name';
  }

  @override
  String get setLanguage => 'Idioma';

  @override
  String get setLanguageSystem => 'Del sistema';

  @override
  String get setMaps => 'Mapas';

  @override
  String get setMapsSubtitle => 'Yandex Maps por defecto';

  @override
  String get setNoAccounts => 'Sin cuentas';

  @override
  String get setNoCalendars => 'sin calendarios';

  @override
  String get setOpenPlacesIn => 'Abrir lugares en';

  @override
  String get setReminderAtStart => 'al inicio';

  @override
  String get setReminderAtStartFull => 'A la hora de inicio';

  @override
  String setReminderHours(int count) {
    return '$count h antes';
  }

  @override
  String setReminderMinutes(int count) {
    return '$count min antes';
  }

  @override
  String get setReminderNone => 'ninguno';

  @override
  String get setReminderNoneFull => 'Sin recordatorio';

  @override
  String get setReminderSubtitle =>
      'Predeterminado para los eventos de este calendario';

  @override
  String setReminderTitle(String name) {
    return 'Recordatorio: $name';
  }

  @override
  String get setRenameCalendar => 'Renombrar calendario';

  @override
  String get setReset => 'Restablecer';

  @override
  String get setResetColor => 'Restablecer al color del origen';

  @override
  String get setSave => 'Guardar';

  @override
  String get setShowCancelled => 'Mostrar eliminados/cancelados';

  @override
  String get setShowCancelledSubtitle => 'Con estilo tachado';

  @override
  String get setShowMonth => 'Mostrar vista de mes';

  @override
  String get setShowMonthSubtitle =>
      'En el teléfono el mes queda apretado; puedes ocultarlo';

  @override
  String get setTitle => 'Ajustes';

  @override
  String get setView => 'Vista';

  @override
  String get uiCancel => 'Cancelar';

  @override
  String uiError(String error) {
    return 'Error: $error';
  }

  @override
  String get uiMove => 'Mover';

  @override
  String uiMoveEventBody(String title, String range) {
    return '«$title»\n\n$range';
  }

  @override
  String get uiMoveEventTitle => '¿Mover evento?';

  @override
  String get uiNoTitle => 'Sin título';

  @override
  String uiNotUpdated(String accounts) {
    return 'No actualizado: $accounts';
  }

  @override
  String get uiReasonAuthError => 'error de autenticación';

  @override
  String get uiReasonFailure => 'fallo';

  @override
  String get uiReasonNeedsReconnect => 'reconexión';

  @override
  String get uiReasonOffline => 'sin conexión';

  @override
  String get uiRetry => 'Reintentar';
}
