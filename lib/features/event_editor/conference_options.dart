import '../../domain/models/account.dart';
import '../../domain/models/calendar.dart';
import '../../domain/providers/yandex_caldav.dart';

/// Returns the Yandex account that owns the selected calendar and can ask the
/// CalDAV server to create Telemost natively.
///
/// Matching by account id (not by e-mail domain or display name) keeps the
/// option scoped to the exact calendar account. This is important for Yandex
/// 360 organisation addresses such as `ki@apsolutions.ru`.
Account? yandexTelemostAccountForCalendar({
  required String? calendarId,
  required List<Calendar> calendars,
  required List<Account> accounts,
}) {
  String? accountId;
  for (final calendar in calendars) {
    if (calendar.id == calendarId) {
      accountId = calendar.accountId;
      break;
    }
  }
  if (accountId == null) return null;
  for (final account in accounts) {
    if (account.id == accountId && isYandexCalDavAccount(account)) {
      return account;
    }
  }
  return null;
}
