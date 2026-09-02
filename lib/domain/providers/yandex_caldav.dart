import '../models/account.dart';
import '../models/enums.dart';

/// Canonical CalDAV endpoint used by Yandex Calendar, including Yandex 360
/// accounts on organisation domains (for example `user@example.org`).
const yandexCalDavHost = 'caldav.yandex.ru';

/// Whether [account] is backed by Yandex Calendar rather than an arbitrary
/// CalDAV server.
///
/// The e-mail domain is deliberately irrelevant: Yandex 360 business users
/// normally have an organisation address. A missing host means Yandex too,
/// because the CalDAV provider uses [yandexCalDavHost] as its default.
bool isYandexCalDavAccount(Account? account) {
  if (account == null || account.provider != ProviderType.caldav) return false;
  final configured = account.config.caldavHost?.trim().toLowerCase();
  if (configured == null || configured.isEmpty) return true;
  final host = configured.endsWith('.')
      ? configured.substring(0, configured.length - 1)
      : configured;
  return host == yandexCalDavHost;
}
