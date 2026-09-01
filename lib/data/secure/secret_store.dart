import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'data_dir.dart';

/// Хранилище секретов (пароли приложений, OAuth-токены) в **системном keyring**.
///
/// Все секреты лежат одной JSON-записью `{"KEY": "value", …}` под именем
/// `calenfi/secrets`. Один blob вместо записи-на-ключ выбран сознательно:
/// системные хранилища не дают перечислить значения по атрибуту, а нам нужен
/// синхронный доступ ко всему набору из уже существующего кода.
///
/// Бэкенды (см. [KeyringBackend]) вызывают штатные утилиты ОС, а не Flutter-плагин.
/// Благодаря этому **и приложение, и агентский CLI `tools/calenfi`** (обычный Dart
/// без Flutter engine) читают один и тот же keyring. На Android/iOS утилит нет —
/// туда из UI-слоя подставляется [SecretStore.backend] на flutter_secure_storage
/// (см. `secret_store_mobile.dart`).
///
/// Использование: один раз `await SecretStore.instance.warmUp()` на старте
/// (main.dart / bin/calenfi.dart), дальше синхронное чтение [value] / [all].
class SecretStore {
  SecretStore._();

  static final SecretStore instance = SecretStore._();
  static const _fallbackImportedKey = '_calenfi_fallback_imported_v1';
  static const _deletedKeysKey = '_calenfi_deleted_keys_v1';

  /// Бэкенд хранения. По умолчанию выбирается по платформе; на мобиле UI-слой
  /// подменяет его до [warmUp].
  static KeyringBackend backend = KeyringBackend.forPlatform();

  /// Запасное хранилище, когда системный keyring недоступен (см. [warmUp]).
  /// Отдельным полем — чтобы тесты не трогали реальный файл пользователя.
  static KeyringBackend fallbackBackend = FileFallbackBackend();

  final Map<String, String> _cache = {};
  final Set<String> _deletedKeys = {};
  bool _loaded = false;

  /// Загружен ли keyring (после [warmUp]).
  bool get isLoaded => _loaded;

  /// Все секреты (копия кеша).
  Map<String, String> get all => Map.unmodifiable(_cache);

  /// Значение секрета из кеша (null, если нет).
  String? value(String key) {
    final v = _cache[key];
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Активный бэкенд после [warmUp]: keyring или файловый фолбэк.
  KeyringBackend? _active;

  /// Хранятся ли секреты в системном keyring (false — сработал фолбэк).
  bool get usesKeyring =>
      _active != null && !identical(_active, fallbackBackend);

  /// Наполняет кеш: системный keyring → файловый фолбэк → импорт файлов,
  /// оставленных внешними скриптами (`secrets.env`, `.tokens/*.json`).
  ///
  /// Импорт идёт **при каждом старте** и добавляет только те ключи, которых в
  /// хранилище ещё нет: так свежий токен, только что записанный
  /// `tools/google_calendar_auth.py`, подхватывается автоматически.
  ///
  /// Системный keyring есть не везде: под KDE/GNOME его даёт демон
  /// org.freedesktop.secrets, но он может быть не запущен (или, как KeePassXC,
  /// не поддерживать поиск по атрибутам). Тогда молча падать нельзя — секреты
  /// уезжают в файл `<config>/secrets.json` с правами 0600, о чём пишем в stderr.
  /// Идемпотентна: повторный вызов ничего не делает, если не задан [force].
  Future<void> warmUp({bool force = false}) async {
    if (_loaded && !force) return;

    final fallback = fallbackBackend;
    final stored = await _readBlobFrom(backend);
    final fallbackStored = await _readBlobFrom(fallback);
    final fromKeyring = stored.isValid;

    // Fallback импортируется в keyring ровно один раз. Постоянный merge сделал
    // бы старый plaintext-файл вечным источником удалённых паролей и токенов.
    // Tombstones дополнительно блокируют legacy-файлы, которые по-прежнему
    // проверяются на каждом старте для совместимости с auth-скриптами.
    _deletedKeys
      ..clear()
      ..addAll(fallbackStored.deletedKeys)
      ..addAll(stored.deletedKeys);
    _cache.clear();
    if (!stored.fallbackImported) {
      _cache.addAll(fallbackStored.values);
    }
    _cache.addAll(stored.values);
    for (final key in _deletedKeys) {
      _cache.remove(key);
    }
    final before = _cache.length;

    for (final e in (await _importLegacyFiles()).entries) {
      if (_deletedKeys.contains(e.key)) continue;
      _cache.putIfAbsent(e.key, () => e.value);
    }
    final imported = _cache.length - before;

    var needsPersist = false;
    if (fromKeyring) {
      _active = backend;
      needsPersist =
          !stored.fallbackImported ||
          imported > 0 ||
          fallbackStored.deletedKeys.difference(stored.deletedKeys).isNotEmpty;
    } else {
      // Куда писать: пробуем keyring и проверяем, читается ли записанное обратно.
      _active = await _keyringWorks() ? backend : fallback;
      needsPersist =
          !usesKeyring &&
          (_cache.isNotEmpty || _deletedKeys.isNotEmpty || imported > 0);
      if (!usesKeyring &&
          _cache.isNotEmpty &&
          fallback is FileFallbackBackend) {
        stderr.writeln(
          'calenfi: системный keyring недоступен — секреты в '
          '${fallback.path} (права 0600)',
        );
      }
    }
    if (needsPersist) {
      try {
        await _writeBlob();
      } on Object {
        // Cache уже содержит объединённые значения и остаётся пригодным для
        // текущего запуска. Следующий запуск повторит self-heal.
        stderr.writeln(
          'calenfi: не удалось обновить хранилище секретов; '
          'используется восстановленный кеш текущего запуска',
        );
      }
    }
    _loaded = true;
  }

  /// Проверка «keyring реально работает»: пишем метку и читаем обратно.
  Future<bool> _keyringWorks() async {
    try {
      await backend.write(_encodeBlob(forKeyring: true));
      final back = await _readBlobFrom(backend);
      return back.isValid && back.fallbackImported;
    } on Object {
      return false;
    }
  }

  /// Пишет секрет в keyring и в кеш.
  Future<void> write(String key, String value) async {
    if (!_loaded) await warmUp();
    if (usesKeyring) {
      await _updateFallbackEntry(key, tombstone: false);
    }
    _deletedKeys.remove(key);
    _cache[key] = value;
    await _writeBlob();
  }

  /// Удаляет секрет.
  Future<void> delete(String key) async {
    if (!_loaded) await warmUp();
    if (usesKeyring) {
      // Scrub the old plaintext value before updating keyring. Only metadata is
      // added; keyring-only secret values are never mirrored into fallback.
      await _updateFallbackEntry(key, tombstone: true);
    }
    _cache.remove(key);
    _deletedKeys.add(key);
    await _writeBlob();
  }

  Future<_StoredBlob> _readBlobFrom(KeyringBackend b) async {
    String? raw;
    try {
      raw = await b.read();
    } on Object {
      return const _StoredBlob.invalid();
    }
    if (raw == null || raw.trim().isEmpty) {
      return const _StoredBlob.invalid();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const _StoredBlob.invalid();
      }
      final deleted = decoded[_deletedKeysKey];
      return _StoredBlob(
        isValid: true,
        fallbackImported:
            decoded[_fallbackImportedKey] == true ||
            decoded[_fallbackImportedKey] == '1',
        deletedKeys: deleted is List
            ? deleted.whereType<String>().toSet()
            : const <String>{},
        values: {
          for (final e in decoded.entries)
            if (e.value is String &&
                e.key != '_probe' &&
                e.key != _fallbackImportedKey &&
                e.key != _deletedKeysKey)
              e.key: e.value as String,
        },
      );
    } on Object {
      return const _StoredBlob.invalid();
    }
  }

  String _encodeBlob({required bool forKeyring}) => jsonEncode({
    ..._cache,
    if (forKeyring) _fallbackImportedKey: true,
    if (_deletedKeys.isNotEmpty)
      _deletedKeysKey: (_deletedKeys.toList()..sort()),
  });

  Future<void> _writeBlob() {
    final active = _active ?? backend;
    return active.write(_encodeBlob(forKeyring: usesKeyring));
  }

  Future<void> _updateFallbackEntry(
    String key, {
    required bool tombstone,
  }) async {
    final fallback = await _readBlobFrom(fallbackBackend);
    final values = Map<String, String>.of(fallback.values)..remove(key);
    final deleted = Set<String>.of(fallback.deletedKeys);
    if (tombstone) {
      deleted.add(key);
    } else {
      deleted.remove(key);
    }
    await fallbackBackend.write(
      jsonEncode({
        ...values,
        if (deleted.isNotEmpty) _deletedKeysKey: (deleted.toList()..sort()),
      }),
    );
  }

  /// Разовая миграция из dev-формата: `secrets.env` (KEY=value) и
  /// `.tokens/{gcal,graph}_*.json` (содержимое файла кладём строкой как есть).
  Future<Map<String, String>> _importLegacyFiles() async {
    final out = <String, String>{};

    final envFile = File(legacySecretsPath());
    if (envFile.existsSync()) {
      for (final line in const LineSplitter().convert(
        envFile.readAsStringSync(),
      )) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final eq = t.indexOf('=');
        if (eq <= 0) continue;
        var v = t.substring(eq + 1);
        final hash = v.indexOf(' #');
        if (hash >= 0) v = v.substring(0, hash);
        out[t.substring(0, eq).trim()] = v.trim();
      }
    }

    final tokensDir = Directory(legacyTokensDir());
    if (tokensDir.existsSync()) {
      for (final f in tokensDir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.json')) continue;
        if (!name.startsWith('gcal_') && !name.startsWith('graph_')) continue;
        out[tokenKey(name.substring(0, name.length - 5))] = f
            .readAsStringSync();
      }
    }
    return out;
  }

  /// Ключ секрета для OAuth-токена: `token:gcal_USER_GMAIL_COM`.
  static String tokenKey(String name) => 'token:$name';
}

class _StoredBlob {
  const _StoredBlob({
    required this.isValid,
    required this.fallbackImported,
    required this.deletedKeys,
    required this.values,
  });

  const _StoredBlob.invalid()
    : isValid = false,
      fallbackImported = false,
      deletedKeys = const <String>{},
      values = const <String, String>{};

  final bool isValid;
  final bool fallbackImported;
  final Set<String> deletedKeys;
  final Map<String, String> values;
}

/// Доступ к системному хранилищу секретов через штатные утилиты ОС.
abstract class KeyringBackend {
  const KeyringBackend();

  /// Имя записи — общее для всех платформ.
  static const service = 'calenfi';
  static const account = 'secrets';

  /// Возвращает сохранённый blob или null, если записи нет.
  Future<String?> read();

  /// Перезаписывает blob.
  Future<void> write(String value);

  static KeyringBackend forPlatform() {
    if (Platform.isLinux) return const LinuxSecretToolBackend();
    if (Platform.isMacOS) return const MacKeychainBackend();
    if (Platform.isWindows) return const WindowsDpapiBackend();
    // Android/iOS: подменяется из UI-слоя на flutter_secure_storage.
    return const UnsupportedBackend();
  }
}

/// Linux: libsecret через `secret-tool` (GNOME Keyring, KWallet, KeePassXC —
/// любой демон, реализующий org.freedesktop.secrets).
class LinuxSecretToolBackend extends KeyringBackend {
  const LinuxSecretToolBackend();

  @override
  Future<String?> read() async {
    final r = await Process.run('secret-tool', [
      'lookup',
      'service',
      KeyringBackend.service,
      'account',
      KeyringBackend.account,
    ]);
    if (r.exitCode != 0) return null;
    final out = (r.stdout as String);
    return out.isEmpty ? null : out;
  }

  @override
  Future<void> write(String value) async {
    // Значение уходит через stdin — не светится в списке процессов.
    final p = await Process.start('secret-tool', [
      'store',
      '--label=Calenfi secrets',
      'service',
      KeyringBackend.service,
      'account',
      KeyringBackend.account,
    ]);
    p.stdin.write(value);
    await p.stdin.close();
    final code = await p.exitCode;
    if (code != 0) {
      throw SecretStoreException(
        'secret-tool store завершился с кодом $code — keyring недоступен?',
      );
    }
  }
}

/// macOS: Keychain через `security`.
class MacKeychainBackend extends KeyringBackend {
  const MacKeychainBackend();

  @override
  Future<String?> read() async {
    final r = await Process.run('security', [
      'find-generic-password',
      '-s',
      KeyringBackend.service,
      '-a',
      KeyringBackend.account,
      '-w',
    ]);
    if (r.exitCode != 0) return null;
    final out = (r.stdout as String).trim();
    return out.isEmpty ? null : utf8.decode(base64Decode(out));
  }

  @override
  Future<void> write(String value) async {
    // `security` принимает секрет только аргументом, поэтому кладём base64 —
    // так в списке процессов не видно ни паролей, ни токенов в открытом виде.
    final r = await Process.run('security', [
      'add-generic-password',
      '-U', // обновить, если запись уже есть
      '-s', KeyringBackend.service,
      '-a', KeyringBackend.account,
      '-w', base64Encode(utf8.encode(value)),
    ]);
    if (r.exitCode != 0) {
      throw SecretStoreException('security add-generic-password: ${r.stderr}');
    }
  }
}

/// Windows: DPAPI (привязка к учётной записи пользователя) через PowerShell.
/// Шифротекст лежит в каталоге данных приложения — расшифровать его может
/// только тот же пользователь на той же машине.
class WindowsDpapiBackend extends KeyringBackend {
  const WindowsDpapiBackend();

  String get _path => '${configDir()}\\secrets.dpapi';

  @override
  Future<String?> read() async {
    final f = File(_path);
    if (!f.existsSync()) return null;
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      r'''$e = Get-Content -Raw -Path "''' +
          _path +
          r'''"; ''' +
          r'''[System.Runtime.InteropServices.Marshal]::PtrToStringAuto(''' +
          r'''[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(''' +
          r'''(ConvertTo-SecureString $e)))''',
    ]);
    if (r.exitCode != 0) return null;
    final out = (r.stdout as String).trim();
    return out.isEmpty ? null : utf8.decode(base64Decode(out));
  }

  @override
  Future<void> write(String value) async {
    Directory(configDir()).createSync(recursive: true);
    final b64 = base64Encode(utf8.encode(value));
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '(ConvertTo-SecureString -String "$b64" -AsPlainText -Force | '
          'ConvertFrom-SecureString) | Set-Content -NoNewline -Path "$_path"',
    ]);
    if (r.exitCode != 0) {
      throw SecretStoreException('DPAPI write: ${r.stderr}');
    }
  }
}

/// Фолбэк, когда системного keyring нет: файл `<config>/secrets.json` только для
/// владельца (0600). Хуже keyring (нет шифрования на диске), зато секреты не
/// лежат в дереве проекта и не попадают в git — и работает везде одинаково.
class FileFallbackBackend extends KeyringBackend {
  FileFallbackBackend();

  String get path => '${configDir()}${Platform.pathSeparator}secrets.json';

  @override
  Future<String?> read() async {
    final f = File(path);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String value) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(value);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', path]);
    }
  }
}

/// Платформа без штатной утилиты (Android/iOS до подмены бэкенда).
class UnsupportedBackend extends KeyringBackend {
  const UnsupportedBackend();
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async => throw const SecretStoreException(
    'нет бэкенда keyring для этой платформы',
  );
}

class SecretStoreException implements Exception {
  const SecretStoreException(this.message);
  final String message;
  @override
  String toString() => 'SecretStoreException: $message';
}
