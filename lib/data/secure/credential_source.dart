import 'build_credentials.dart';
import 'secret_store.dart';

/// Источник секретов (паролей приложений, ключей API) поверх системного keyring.
///
/// Значения берутся из синхронного кеша [SecretStore], который наполняется один
/// раз на старте (`await SecretStore.instance.warmUp()` в `main()` и в CLI).
/// Имена ключей — как раньше: email в ВЕРХНЕМ регистре, не-алфанум → '_'
/// (совпадает с `tools/extract_contacts.py`), поэтому старый `secrets.env`
/// импортируется в keyring один-в-один.
class CredentialSource {
  CredentialSource._(this._values);

  /// Пустой источник (для тестов / когда секретов заведомо нет).
  factory CredentialSource.empty() => CredentialSource._({});

  /// Источник с явными значениями (тесты).
  factory CredentialSource.fromMap(Map<String, String> values) =>
      CredentialSource._(Map.of(values));

  final Map<String, String> _values;

  /// OAuth-клиенты, зашитые в сборку (см. [BuildCredentials]). Поле, чтобы
  /// тесты могли подставить свои значения.
  static Map<String, String> buildDefaults = BuildCredentials.values;

  /// Снимок секретов из keyring-кеша поверх значений сборки: непустой ключ в
  /// keyring (свой OAuth-клиент пользователя) важнее зашитого.
  static CredentialSource load() => CredentialSource._({
        ...buildDefaults,
        for (final e in SecretStore.instance.all.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      });

  /// Значение произвольного ключа (null, если нет или пусто).
  String? value(String key) => _nonEmpty(_values[key]);

  /// Нормализованный префикс переменных для e-mail (ВЕРХНИЙ регистр,
  /// не-алфанум → '_'). Совпадает с `tools/extract_contacts.py`.
  static String keyFor(String email) =>
      email.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');

  /// Имена ключей пароля — используются и на запись.
  static String caldavPasswordVar(String email) => '${keyFor(email)}_CALDAV_PASSWORD';
  static String ewsPasswordVar(String email) => '${keyFor(email)}_EWS_PASSWORD';

  String _key(String email) => keyFor(email);

  /// Пароль приложения для CalDAV/CardDAV (Yandex и т.п.).
  String? caldavPassword(String email) {
    final k = _key(email);
    return _nonEmpty(_values['${k}_CALDAV_PASSWORD']) ??
        _nonEmpty(_values['${k}_APP_PASSWORD']);
  }

  /// Пароль для Exchange EWS.
  String? ewsPassword(String email) => _nonEmpty(_values['${_key(email)}_EWS_PASSWORD']);
  String? ewsUrl(String email) => _nonEmpty(_values['${_key(email)}_EWS_URL']);
  String? ewsUser(String email) => _nonEmpty(_values['${_key(email)}_EWS_USER']);

  /// Zoom. Поддержаны два режима:
  ///  • Server-to-Server OAuth — [zoomAccountId] + [zoomClientId] +
  ///    [zoomClientSecret] (Calenfi создаёт встречи от имени аккаунта, без
  ///    браузерного входа);
  ///  • User-managed OAuth — то же client_id/secret + сохранённый после входа
  ///    в браузере [zoomUserToken] (встречи от имени пользователя).
  String? get zoomAccountId => _nonEmpty(_values['ZOOM_ACCOUNT_ID']);
  String? get zoomClientId => _nonEmpty(_values['ZOOM_CLIENT_ID']);
  String? get zoomClientSecret => _nonEmpty(_values['ZOOM_CLIENT_SECRET']);
  String? get zoomUserToken => _nonEmpty(_values['ZOOM_USER_TOKEN']);

  /// OAuth-клиент Google (для in-app подключения аккаунта). Тип «installed»,
  /// client_secret не конфиденциален, но нужен при обмене кода. Задаётся ключами
  /// GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET в хранилище.
  String? get googleClientId => _nonEmpty(_values['GOOGLE_OAUTH_CLIENT_ID']);
  String? get googleClientSecret =>
      _nonEmpty(_values['GOOGLE_OAUTH_CLIENT_SECRET']);

  /// OAuth-клиент Microsoft Graph (public client, PKCE без секрета).
  String? get graphClientId => _nonEmpty(_values['GRAPH_CLIENT_ID']);
  String get graphTenant => _nonEmpty(_values['GRAPH_TENANT']) ?? 'common';

  /// Yandex Telemost: OAuth-токен со scope `telemost-api:conferences.create`
  /// (создание видеовстреч) и, опционально, OAuth-клиент для получения токена
  /// прямо в приложении.
  String? get telemostToken => _nonEmpty(_values['TELEMOST_OAUTH_TOKEN']);
  String? get yandexClientId => _nonEmpty(_values['YANDEX_OAUTH_CLIENT_ID']);
  String? get yandexClientSecret =>
      _nonEmpty(_values['YANDEX_OAUTH_CLIENT_SECRET']);

  static String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;
}

/// Запись/обновление одного секрета в системном keyring.
///
/// После записи нужно пере-создать провайдеры (invalidate
/// `providerRegistryProvider`), чтобы новый пароль подхватился.
Future<void> writeSecret(String key, String value) =>
    SecretStore.instance.write(key, value);
