/// OAuth-клиенты приложения, зашитые в сборку.
///
/// Значения приходят при сборке из переменных окружения с теми же именами:
/// `tools/oauth_dart_defines.sh` превращает их в `--dart-define=KEY=VALUE`, в
/// релизах GitHub это секреты репозитория. Без них скачанная сборка не может
/// начать вход через браузер: ключей нет ни в сборке, ни в keyring нового
/// устройства.
///
/// Сюда попадают только идентификаторы OAuth-приложений: у Desktop-клиента
/// Google секрет по документации Google не конфиденциален, Microsoft — public
/// client без секрета. Пароли, refresh-токены пользователей и ключи Zoom
/// Server-to-Server в сборку не зашиваются: они живут только в keyring.
class BuildCredentials {
  const BuildCredentials._();

  /// Ключи, которые разрешено зашивать в сборку. Тот же список — в
  /// `tools/oauth_dart_defines.sh`, тест сверяет их между собой.
  static const keys = [
    'GOOGLE_OAUTH_CLIENT_ID',
    'GOOGLE_OAUTH_CLIENT_SECRET',
    'GRAPH_CLIENT_ID',
    'GRAPH_TENANT',
    'YANDEX_OAUTH_CLIENT_ID',
    'YANDEX_OAUTH_CLIENT_SECRET',
  ];

  static const _defined = <String, String>{
    'GOOGLE_OAUTH_CLIENT_ID': String.fromEnvironment('GOOGLE_OAUTH_CLIENT_ID'),
    'GOOGLE_OAUTH_CLIENT_SECRET':
        String.fromEnvironment('GOOGLE_OAUTH_CLIENT_SECRET'),
    'GRAPH_CLIENT_ID': String.fromEnvironment('GRAPH_CLIENT_ID'),
    'GRAPH_TENANT': String.fromEnvironment('GRAPH_TENANT'),
    'YANDEX_OAUTH_CLIENT_ID': String.fromEnvironment('YANDEX_OAUTH_CLIENT_ID'),
    'YANDEX_OAUTH_CLIENT_SECRET':
        String.fromEnvironment('YANDEX_OAUTH_CLIENT_SECRET'),
  };

  /// Непустые значения, заданные при сборке.
  static Map<String, String> get values => {
        for (final e in _defined.entries)
          if (e.value.isNotEmpty) e.key: e.value,
      };
}
