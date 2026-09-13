import '../../../domain/models/account.dart';
import '../../../domain/models/calendar.dart';
import '../../../domain/models/calendar_event.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/providers/calendar_provider.dart';
import '../../../domain/providers/provider_capabilities.dart';

/// Заглушка для реального аккаунта, у которого ещё нет кредов (напр. O365 до
/// авторизации). Не отдаёт событий и не падает — аккаунт виден, но пуст,
/// без мок-шума.
class EmptyProvider implements CalendarProvider {
  EmptyProvider(this.type);

  @override
  final ProviderType type;

  @override
  ProviderCapabilities get caps => const ProviderCapabilities(
        crud: false,
        incrementalSync: false,
        rsvp: false,
        createNativeConference: false,
        serverReminders: false,
        attendees: false,
      );

  @override
  Future<AuthResult> authenticate(AccountConfig cfg) async =>
      const AuthResult(success: true);
  @override
  Future<void> refreshAuth(Account acc) async {}
  @override
  Future<List<Calendar>> listCalendars(Account acc) async => const [];
  @override
  Future<List<CalendarEvent>> fetchEvents(Account a, Calendar c, DateRange r) async => const [];
  @override
  Future<SyncResult> incrementalSync(Account a, Calendar c, String? s) async =>
      const SyncResult(upserts: [], deletedIds: [], newSyncState: null);
  @override
  Future<CalendarEvent> createEvent(Account a, Calendar c, CalendarEvent e) async =>
      throw UnsupportedError('аккаунт не подключён');
  @override
  Future<CalendarEvent> updateEvent(
    Account a,
    CalendarEvent e, {
    RecurrenceScope scope = RecurrenceScope.thisOnly,
    DateTime? originalStartUtc,
  }) async => throw UnsupportedError('аккаунт не подключён');
  @override
  Future<void> deleteEvent(Account a, CalendarEvent e, RecurrenceScope s) async =>
      throw UnsupportedError('аккаунт не подключён');
  @override
  Future<void> respondToInvite(Account a, CalendarEvent e, ResponseStatus r) async =>
      throw UnsupportedError('аккаунт не подключён');
}
