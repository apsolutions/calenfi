import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Stable application identifier used by the native runners and data paths.
const String kApplicationId = 'ru.apsolutions.calenfi';

/// Name shared by the Flutter application and the agent CLI.
const String kDbFileName = 'calenfi.sqlite';

/// A persistent marker prevents the retained legacy copy from being imported
/// again after a user deliberately empties the canonical database.
const String kDbMigrationMarkerFileName = '$kDbFileName.app-id-migrated-v1';

const _databaseLockFileName = '$kDbFileName.app-id-migration.lock';
const _supportLockFileName = '.app-id-support-migration.lock';
const _coreTables = <String>{'accounts', 'calendars', 'events', 'outbox'};
const _dataTables = <String>{..._coreTables, 'contacts'};
const _ancillaryFileNames = <String>[
  'accounts.json',
  'secrets.dpapi',
  'secrets.json',
  'secrets.env',
  'locale',
];
final _inProcessLocks = <String, _AsyncLock>{};

/// Product names used by builds released before the AP Solutions rename.
///
/// Keep these values only for preferred one-way migration paths. Unnamed old
/// application/vendor directories are discovered from a tightly bounded set
/// of siblings and still have to pass the normal data-health checks. New files
/// must always be created below [kApplicationId].
const List<String> kLegacyApplicationIds = <String>['calenfi'];

/// Canonical Linux application-support directory.
///
/// `path_provider_linux` can deliberately fall back to a pre-existing
/// executable-name directory. That compatibility behaviour is undesirable
/// after an application-id rename because it makes the GUI and CLI disagree.
Directory linuxApplicationSupportDirectory({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final dataHome =
      env['XDG_DATA_HOME'] ?? p.join(env['HOME'] ?? '/root', '.local', 'share');
  return Directory(p.join(dataHome, kApplicationId));
}

List<Directory> linuxLegacyApplicationSupportDirectories({
  Map<String, String>? environment,
}) {
  final canonical = linuxApplicationSupportDirectory(environment: environment);
  final preferred = <Directory>[
    for (final id in kLegacyApplicationIds)
      Directory(p.join(canonical.parent.path, id)),
  ];
  final discovered = _directChildDirectories(
    canonical.parent,
  ).where(_hasDatabaseFile);
  return _orderedLegacyDirectories(
    canonical: canonical,
    preferred: preferred,
    discovered: discovered,
  );
}

/// Legacy Windows support directories derived from the support-path shape.
///
/// `path_provider_windows` builds the support path as
/// `%APPDATA%/<CompanyName>/<ProductName>`. The vendor is discovered among the
/// direct APPDATA children without embedding retired identifiers. Keep the
/// lower-case product name explicitly: it may be distinct on a case-sensitive
/// Windows volume or in tests even though normal NTFS installations treat both
/// paths as equal.
List<Directory> windowsLegacyApplicationSupportDirectories(
  Directory canonical,
) {
  final roaming = canonical.parent.parent;
  final preferred = <Directory>[
    Directory(p.join(canonical.parent.path, 'calenfi')),
    Directory(p.join(roaming.path, 'calenfi')),
  ];
  final productNames = <String>{
    p.basename(canonical.path),
    ...kLegacyApplicationIds,
  };
  final discovered = <Directory>[];
  for (final vendor in _directChildDirectories(roaming)) {
    for (final productName in productNames) {
      final candidate = Directory(p.join(vendor.path, productName));
      if (_isDirectoryWithoutFollowingLinks(candidate) &&
          _hasRecognizableSupportState(candidate)) {
        discovered.add(candidate);
      }
    }
  }
  return _orderedLegacyDirectories(
    canonical: canonical,
    preferred: preferred,
    discovered: discovered,
  );
}

/// Returns direct child directories only. Legacy discovery deliberately never
/// walks an entire user profile: Linux app ids are siblings below XDG data,
/// while Windows support paths have exactly one vendor level below APPDATA.
List<Directory> _directChildDirectories(Directory parent) {
  try {
    final result = parent
        .listSync(followLinks: false)
        .whereType<Directory>()
        .toList();
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  } on FileSystemException {
    return const <Directory>[];
  }
}

bool _isDirectoryWithoutFollowingLinks(Directory directory) {
  try {
    return FileSystemEntity.typeSync(directory.path, followLinks: false) ==
        FileSystemEntityType.directory;
  } on FileSystemException {
    return false;
  }
}

bool _isFileWithoutFollowingLinks(String path) {
  try {
    return FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.file;
  } on FileSystemException {
    return false;
  }
}

bool _hasDatabaseFile(Directory directory) =>
    _isFileWithoutFollowingLinks(p.join(directory.path, kDbFileName));

bool _hasRecognizableSupportState(Directory directory) {
  if (_hasDatabaseFile(directory)) return true;
  for (final name in _ancillaryFileNames) {
    if (_isFileWithoutFollowingLinks(p.join(directory.path, name))) return true;
  }
  return _isDirectoryWithoutFollowingLinks(
    Directory(p.join(directory.path, '.tokens')),
  );
}

List<Directory> _orderedLegacyDirectories({
  required Directory canonical,
  required Iterable<Directory> preferred,
  required Iterable<Directory> discovered,
}) {
  final result = <Directory>[];
  final seen = <String>{p.normalize(canonical.path)};
  for (final directory in <Directory>[...preferred, ...discovered]) {
    if (seen.add(p.normalize(directory.path))) result.add(directory);
  }
  return result;
}

/// Copies non-database Windows state from pre-v0.3.1 support directories.
///
/// `getApplicationSupportDirectory()` can change when Windows version-info is
/// updated. The database migration alone is insufficient because
/// `accounts.json` and DPAPI ciphertext live in that same directory and are
/// needed before `SecretStore` is initialized.
/// Existing canonical files always win; legacy files remain as rollback copies.
Future<void> prepareWindowsAncillaryState({
  required Directory targetDirectory,
  Iterable<Directory>? legacyDirectories,
}) async {
  await targetDirectory.create(recursive: true);
  final legacy =
      (legacyDirectories ??
              windowsLegacyApplicationSupportDirectories(targetDirectory))
          .where((directory) => !p.equals(directory.path, targetDirectory.path))
          .toList();

  await _withFileLock(
    File(p.join(targetDirectory.path, _supportLockFileName)),
    () async {
      final canonicalAccountIds = _readAccountIds(
        File(p.join(targetDirectory.path, 'accounts.json')),
      );
      final profiles = <_WindowsAncillaryProfile>[];
      for (final directory in legacy) {
        final profile = await _inspectWindowsAncillaryProfile(directory);
        if (profile != null) profiles.add(profile);
      }
      if (profiles.isEmpty) return;

      // All related state comes from one profile. Mixing a newer accounts file
      // with an older DPAPI blob can associate accounts with the wrong secrets.
      profiles.sort(
        (a, b) => _compareWindowsAncillaryProfiles(
          a,
          b,
          canonicalAccountIds: canonicalAccountIds,
        ),
      );
      final selected = profiles.first;

      for (final entry in selected.files.entries) {
        await _copyValidatedMissingFile(
          target: File(p.join(targetDirectory.path, entry.key)),
          source: entry.value,
          validator: (file) => _isValidAncillaryFile(entry.key, file),
        );
      }
      for (final entry in selected.tokens.entries) {
        await _copyValidatedMissingFile(
          target: File(p.join(targetDirectory.path, '.tokens', entry.key)),
          source: entry.value,
          validator: _isValidTokenFile,
        );
      }
    },
  );
}

/// Resolves the Linux database and migrates a populated legacy database found.
Future<File> prepareLinuxDatabaseFile({Map<String, String>? environment}) =>
    prepareDatabaseFile(
      targetDirectory: linuxApplicationSupportDirectory(
        environment: environment,
      ),
      legacyDirectories: linuxLegacyApplicationSupportDirectories(
        environment: environment,
      ),
    );

/// Returns the canonical database file, migrating legacy data if needed.
///
/// The operation is serialized across GUI/CLI processes. A schema-only
/// canonical database left by v0.3.1 does not hide populated legacy data, while
/// a populated canonical database or a migration marker is authoritative. Each
/// candidate must be a healthy Calenfi SQLite database; corrupt candidates are
/// skipped in favour of the next valid source. Legacy sources and any replaced
/// canonical file are retained as rollback copies.
Future<File> prepareDatabaseFile({
  required Directory targetDirectory,
  required Iterable<Directory> legacyDirectories,
}) async {
  await targetDirectory.create(recursive: true);
  return _withFileLock(
    File(p.join(targetDirectory.path, _databaseLockFileName)),
    () => _prepareDatabaseFileLocked(
      targetDirectory: targetDirectory,
      legacyDirectories: legacyDirectories,
    ),
  );
}

Future<File> _prepareDatabaseFileLocked({
  required Directory targetDirectory,
  required Iterable<Directory> legacyDirectories,
}) async {
  final target = File(p.join(targetDirectory.path, kDbFileName));
  final marker = File(p.join(targetDirectory.path, kDbMigrationMarkerFileName));
  final targetState = await _inspectDatabase(target);

  if (targetState.isCalenfi &&
      (await marker.exists() || targetState.hasUserData)) {
    await _writeMarkerBestEffort(marker);
    return target;
  }

  final validLegacy = <_DatabaseState>[];
  final invalidNonEmpty = <File>[];
  final seen = <String>{p.normalize(target.path)};
  for (final directory in legacyDirectories) {
    final candidate = File(p.join(directory.path, kDbFileName));
    final normalized = p.normalize(candidate.path);
    if (!seen.add(normalized)) continue;
    final state = await _inspectDatabase(candidate);
    if (!state.nonEmpty) continue;
    if (state.isCalenfi) {
      validLegacy.add(state);
    } else {
      invalidNonEmpty.add(candidate);
    }
  }
  if (targetState.nonEmpty && !targetState.isCalenfi) {
    invalidNonEmpty.add(target);
  }

  validLegacy.sort(_compareDatabaseFreshness);
  final populatedLegacy = validLegacy
      .where((state) => state.hasUserData)
      .toList();

  if (populatedLegacy.isEmpty) {
    if (targetState.isCalenfi) {
      if (invalidNonEmpty.isNotEmpty && !await marker.exists()) {
        throw FileSystemException(
          'No valid populated Calenfi legacy database; refusing to make an '
          'unmarked empty database authoritative',
          invalidNonEmpty.map((file) => file.path).join(', '),
        );
      }
      await _writeMarkerBestEffort(marker);
      return target;
    }
    if (invalidNonEmpty.isNotEmpty) {
      throw FileSystemException(
        'No valid Calenfi database found; refusing to create an empty database',
        invalidNonEmpty.map((file) => file.path).join(', '),
      );
    }
    return target;
  }

  for (final source in populatedLegacy) {
    if (await _migrateDatabase(source.file, target)) {
      await _writeMarkerBestEffort(marker);
      return target;
    }
  }

  // The source remains the safest usable choice if all copy/install attempts
  // failed (permissions, transient locks, full disk). A later launch retries.
  return populatedLegacy.first.file;
}

Future<bool> _migrateDatabase(File source, File target) async {
  final temporary = File('${target.path}.migrating');
  Database? sourceDatabase;
  Database? targetDatabase;
  try {
    if (await temporary.exists()) await temporary.delete();
    sourceDatabase = sqlite3.open(source.path, mode: OpenMode.readOnly);
    targetDatabase = sqlite3.open(temporary.path);
    await sourceDatabase.backup(targetDatabase, nPage: 256).drain<void>();
    sourceDatabase.dispose();
    sourceDatabase = null;
    targetDatabase.dispose();
    targetDatabase = null;

    final copied = await _inspectDatabase(temporary);
    if (!copied.isCalenfi || !copied.hasUserData) {
      throw const FileSystemException('Migrated SQLite database is invalid');
    }

    final preserved = await _preserveDatabaseFamily(target);
    try {
      await temporary.rename(target.path);
    } on Object {
      await preserved?.restore();
      rethrow;
    }
    return true;
  } on Object {
    sourceDatabase?.dispose();
    targetDatabase?.dispose();
    if (await temporary.exists()) {
      try {
        await temporary.delete();
      } on Object {
        // The source and any previous target are still retained.
      }
    }
    return false;
  }
}

Future<_PreservedDatabase?> _preserveDatabaseFamily(File target) async {
  const suffixes = <String>['', '-wal', '-shm', '-journal'];
  if (!await target.exists() &&
      !await File('${target.path}-wal').exists() &&
      !await File('${target.path}-shm').exists() &&
      !await File('${target.path}-journal').exists()) {
    return null;
  }

  var backupBase = '${target.path}.pre-app-id-migration';
  var number = 1;
  while (await Future.any([
    for (final suffix in suffixes) File('$backupBase$suffix').exists(),
  ])) {
    backupBase = '${target.path}.pre-app-id-migration.${number++}';
  }

  final moved = <({File original, File backup})>[];
  try {
    for (final suffix in suffixes) {
      final original = File('${target.path}$suffix');
      if (!await original.exists()) continue;
      final backup = await original.rename('$backupBase$suffix');
      moved.add((original: original, backup: backup));
    }
    return _PreservedDatabase(moved);
  } on Object {
    await _PreservedDatabase(moved).restore();
    rethrow;
  }
}

Future<_DatabaseState> _inspectDatabase(File file) async {
  if (!await file.exists()) return _DatabaseState.missing(file);
  // Read filesystem freshness before opening SQLite: a read-only WAL open can
  // itself touch the shared-memory file on some platforms.
  final familyModifiedAt = await _databaseFamilyModifiedAt(file);
  int length;
  try {
    length = await file.length();
  } on Object {
    return _DatabaseState.invalid(file, nonEmpty: true);
  }
  if (length == 0) return _DatabaseState.invalid(file, nonEmpty: false);

  Database? database;
  try {
    database = sqlite3.open(file.path, mode: OpenMode.readOnly);
    final check = database.select('PRAGMA quick_check');
    if (check.length != 1 || check.single.values.single != 'ok') {
      return _DatabaseState.invalid(file, nonEmpty: true);
    }
    final tables = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    if (!_coreTables.every(tables.contains)) {
      return _DatabaseState.invalid(file, nonEmpty: true);
    }

    var hasUserData = false;
    for (final table in _dataTables.where(tables.contains)) {
      if (database.select('SELECT 1 FROM "$table" LIMIT 1').isNotEmpty) {
        hasUserData = true;
        break;
      }
    }
    return _DatabaseState.valid(
      file,
      hasUserData: hasUserData,
      contentFreshness: _databaseContentFreshness(database),
      familyModifiedAt: familyModifiedAt,
    );
  } on Object {
    return _DatabaseState.invalid(file, nonEmpty: true);
  } finally {
    database?.dispose();
  }
}

int _compareDatabaseFreshness(_DatabaseState a, _DatabaseState b) {
  final byFreshness = b.freshnessAt.compareTo(a.freshnessAt);
  if (byFreshness != 0) return byFreshness;
  // Prefer an application timestamp over an equal filesystem fallback.
  final byContent = (b.contentFreshness == null ? 0 : 1).compareTo(
    a.contentFreshness == null ? 0 : 1,
  );
  if (byContent != 0) return byContent;
  final byFamilyMtime = b.familyModifiedAt.compareTo(a.familyModifiedAt);
  if (byFamilyMtime != 0) return byFamilyMtime;
  return a.file.path.compareTo(b.file.path);
}

Future<DateTime> _databaseFamilyModifiedAt(File database) async {
  var newest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final suffix in const <String>['', '-wal', '-shm']) {
    final member = File('${database.path}$suffix');
    try {
      if (!await member.exists()) continue;
      final modified = await member.lastModified();
      if (modified.isAfter(newest)) newest = modified;
    } on Object {
      // The content timestamp remains preferable; epoch is a safe fallback.
    }
  }
  return newest;
}

DateTime? _databaseContentFreshness(Database database) {
  DateTime? newest;
  // last_sync_utc describes the newest complete remote snapshot, while an
  // Outbox row may represent a still-newer local edit not present remotely.
  for (final query in const <String>[
    'SELECT MAX(last_sync_utc) AS value FROM accounts',
    'SELECT MAX(created_at) AS value FROM outbox',
  ]) {
    try {
      final rows = database.select(query);
      if (rows.isEmpty) continue;
      final timestamp = _decodeDatabaseTimestamp(rows.single['value']);
      if (timestamp != null && (newest == null || timestamp.isAfter(newest))) {
        newest = timestamp;
      }
    } on SqliteException {
      // Older schemas may not have one of these columns. The DB/WAL/SHM mtime
      // remains available as a fallback for those versions.
    }
  }
  return newest;
}

DateTime? _decodeDatabaseTimestamp(Object? raw) {
  if (raw == null) return null;
  DateTime? result;
  if (raw is num) {
    final value = raw.toDouble();
    final magnitude = value.abs();
    try {
      if (magnitude < 100000000000) {
        result = DateTime.fromMillisecondsSinceEpoch(
          (value * 1000).round(),
          isUtc: true,
        );
      } else if (magnitude < 100000000000000) {
        result = DateTime.fromMillisecondsSinceEpoch(
          value.round(),
          isUtc: true,
        );
      } else {
        result = DateTime.fromMicrosecondsSinceEpoch(
          value.round(),
          isUtc: true,
        );
      }
    } on RangeError {
      return null;
    }
  } else if (raw is String) {
    final numeric = num.tryParse(raw);
    result = numeric == null
        ? DateTime.tryParse(raw)?.toUtc()
        : _decodeDatabaseTimestamp(numeric);
  }
  if (result == null) return null;
  final latestPlausible = DateTime.now().toUtc().add(const Duration(days: 366));
  if (result.isBefore(DateTime.utc(2000)) || result.isAfter(latestPlausible)) {
    return null;
  }
  return result;
}

Future<_WindowsAncillaryProfile?> _inspectWindowsAncillaryProfile(
  Directory directory,
) async {
  final files = <String, File>{};
  final tokens = <String, File>{};
  var invalidCount = 0;
  var sawState = false;

  for (final name in _ancillaryFileNames) {
    final file = File(p.join(directory.path, name));
    if (!await file.exists()) continue;
    sawState = true;
    if (_isValidAncillaryFile(name, file)) {
      files[name] = file;
    } else {
      invalidCount++;
    }
  }

  final tokenDirectory = Directory(p.join(directory.path, '.tokens'));
  if (await tokenDirectory.exists()) {
    try {
      await for (final entity in tokenDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
          continue;
        }
        final relative = p.relative(entity.path, from: tokenDirectory.path);
        if (p.isAbsolute(relative) || p.split(relative).contains('..')) {
          continue;
        }
        sawState = true;
        if (_isValidTokenFile(entity)) {
          tokens[relative] = entity;
        } else {
          invalidCount++;
        }
      }
    } on FileSystemException {
      sawState = true;
      invalidCount++;
    }
  }

  if (!sawState || (files.isEmpty && tokens.isEmpty)) return null;
  final primaryFiles = <File>[
    for (final entry in files.entries)
      if (entry.key != 'locale') entry.value,
    ...tokens.values,
  ];
  final freshnessFiles = primaryFiles.isNotEmpty
      ? primaryFiles
      : files.values.toList();
  var freshest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final file in freshnessFiles) {
    try {
      final modified = await file.lastModified();
      if (modified.isAfter(freshest)) freshest = modified;
    } on Object {
      invalidCount++;
    }
  }
  return _WindowsAncillaryProfile(
    directory: directory,
    files: files,
    tokens: tokens,
    invalidCount: invalidCount,
    freshest: freshest,
    hasPrimaryState: primaryFiles.isNotEmpty,
    hasValidAccounts: files.containsKey('accounts.json'),
    accountIds: files.containsKey('accounts.json')
        ? _readAccountIds(files['accounts.json']!)
        : null,
  );
}

int _compareWindowsAncillaryProfiles(
  _WindowsAncillaryProfile a,
  _WindowsAncillaryProfile b, {
  Set<String>? canonicalAccountIds,
}) {
  if (canonicalAccountIds != null) {
    final byCompatibility =
        _accountProfileCompatibility(
          b.accountIds,
          canonicalAccountIds,
        ).compareTo(
          _accountProfileCompatibility(a.accountIds, canonicalAccountIds),
        );
    if (byCompatibility != 0) return byCompatibility;
  }
  // A coherent account profile is more useful than a pristine locale-only
  // directory. In particular, a corrupt newer accounts.json must not outrank
  // an older structurally valid one (including an intentional empty list).
  final byAccounts = (b.hasValidAccounts ? 1 : 0).compareTo(
    a.hasValidAccounts ? 1 : 0,
  );
  if (byAccounts != 0) return byAccounts;
  final byPrimary = (b.hasPrimaryState ? 1 : 0).compareTo(
    a.hasPrimaryState ? 1 : 0,
  );
  if (byPrimary != 0) return byPrimary;
  final byValidity = a.invalidCount.compareTo(b.invalidCount);
  if (byValidity != 0) return byValidity;
  final byFreshness = b.freshest.compareTo(a.freshest);
  if (byFreshness != 0) return byFreshness;
  final byFileCount = b.validFileCount.compareTo(a.validFileCount);
  if (byFileCount != 0) return byFileCount;
  return a.directory.path.compareTo(b.directory.path);
}

int _accountProfileCompatibility(
  Set<String>? candidate,
  Set<String> canonical,
) {
  if (candidate == null) return 1;
  return candidate.length == canonical.length &&
          candidate.every(canonical.contains)
      ? 2
      : 0;
}

bool _isValidAncillaryFile(String name, File file) => switch (name) {
  'accounts.json' => _isValidAccountsFile(file),
  'secrets.json' => _isValidSecretsJsonFile(file),
  'secrets.dpapi' => _hasNonWhitespaceContent(file),
  'secrets.env' => _isValidSecretsEnvFile(file),
  'locale' => _isValidLocaleFile(file),
  _ => false,
};

Object? _readJsonFile(File file) {
  try {
    final raw = file.readAsStringSync();
    if (raw.trim().isEmpty) return null;
    return jsonDecode(raw);
  } on Object {
    return null;
  }
}

bool _isValidAccountsFile(File file) => _readAccountIds(file) != null;

Set<String>? _readAccountIds(File file) {
  final decoded = _readJsonFile(file);
  if (decoded is! List) return null;
  const providers = <String>{
    'google',
    'graph',
    'o365',
    'office365',
    'caldav',
    'ews',
    'exchange',
  };
  final ids = <String>{};
  for (final entry in decoded) {
    if (entry is! Map<String, dynamic>) return null;
    final id = entry['id'];
    final provider = entry['provider'];
    final email = entry['email'];
    if (id is! String || id.trim().isEmpty || !ids.add(id)) return null;
    if (provider is! String || !providers.contains(provider)) return null;
    if (email is! String || email.trim().isEmpty) return null;
    final displayName = entry['displayName'];
    if (displayName != null && displayName is! String) return null;
    final config = entry['config'];
    if (config != null) {
      if (config is! Map<String, dynamic>) return null;
      if (config['ewsUrl'] != null && config['ewsUrl'] is! String) return null;
      if (config['caldavHost'] != null && config['caldavHost'] is! String) {
        return null;
      }
      if (config['caldavPort'] != null && config['caldavPort'] is! num) {
        return null;
      }
      if (config['caldavPrincipalPath'] != null &&
          config['caldavPrincipalPath'] is! String) {
        return null;
      }
      final scopes = config['scopes'];
      if (scopes != null &&
          (scopes is! List || !scopes.every((scope) => scope is String))) {
        return null;
      }
    }
  }
  return ids;
}

bool _isValidSecretsJsonFile(File file) {
  final decoded = _readJsonFile(file);
  if (decoded is! Map<String, dynamic>) return false;
  for (final entry in decoded.entries) {
    if (entry.key == '_calenfi_fallback_imported_v1') {
      if (entry.value is! bool && entry.value is! String) return false;
      continue;
    }
    if (entry.key == '_calenfi_deleted_keys_v1') {
      final value = entry.value;
      if (value is! List || !value.every((item) => item is String)) {
        return false;
      }
      continue;
    }
    if (entry.value is! String) return false;
  }
  return true;
}

bool _isValidTokenFile(File file) {
  final decoded = _readJsonFile(file);
  return decoded is Map<String, dynamic> && decoded.isNotEmpty;
}

bool _hasNonWhitespaceContent(File file) {
  try {
    return file.readAsBytesSync().any(
      (byte) => byte != 0x09 && byte != 0x0A && byte != 0x0D && byte != 0x20,
    );
  } on Object {
    return false;
  }
}

bool _isValidSecretsEnvFile(File file) {
  try {
    for (final line in const LineSplitter().convert(file.readAsStringSync())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final equals = trimmed.indexOf('=');
      if (equals > 0 && trimmed.substring(equals + 1).trim().isNotEmpty) {
        return true;
      }
    }
  } on Object {
    return false;
  }
  return false;
}

bool _isValidLocaleFile(File file) {
  try {
    return const <String>{
      'en',
      'ru',
      'es',
      'de',
      'zh',
      'fr',
    }.contains(file.readAsStringSync().trim());
  } on Object {
    return false;
  }
}

Future<bool> _copyValidatedMissingFile({
  required File target,
  required File source,
  required bool Function(File) validator,
}) async {
  if (await target.exists()) return true;
  final temporary = File('${target.path}.migrating');
  try {
    if (!validator(source)) return false;
    await target.parent.create(recursive: true);
    if (await temporary.exists()) await temporary.delete();
    await source.copy(temporary.path);
    if (!validator(temporary)) {
      await temporary.delete();
      return false;
    }
    if (await target.exists()) {
      await temporary.delete();
      return true;
    }
    await temporary.rename(target.path);
    return true;
  } on Object {
    if (await temporary.exists()) {
      try {
        await temporary.delete();
      } on Object {
        // A later launch retries from the retained source profile.
      }
    }
    return false;
  }
}

Future<T> _withFileLock<T>(File lockFile, Future<T> Function() action) async {
  final key = p.normalize(lockFile.absolute.path);
  final processLock = _inProcessLocks.putIfAbsent(key, _AsyncLock.new);
  await processLock.acquire();
  try {
    return await _withOsFileLock(lockFile, action);
  } finally {
    processLock.release();
    if (processLock.isIdle && identical(_inProcessLocks[key], processLock)) {
      _inProcessLocks.remove(key);
    }
  }
}

Future<T> _withOsFileLock<T>(File lockFile, Future<T> Function() action) async {
  await lockFile.parent.create(recursive: true);
  final handle = await lockFile.open(mode: FileMode.append);
  var locked = false;
  try {
    await handle.lock(FileLock.exclusive);
    locked = true;
    return await action();
  } finally {
    if (locked) {
      try {
        await handle.unlock();
      } on Object {
        // Closing the handle also releases the OS lock.
      }
    }
    await handle.close();
  }
}

class _AsyncLock {
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  bool _locked = false;

  bool get isIdle => !_locked && _waiters.isEmpty;

  Future<void> acquire() async {
    if (!_locked) {
      _locked = true;
      return;
    }
    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    await waiter.future;
  }

  void release() {
    if (_waiters.isEmpty) {
      _locked = false;
    } else {
      _waiters.removeFirst().complete();
    }
  }
}

Future<void> _writeMarkerBestEffort(File marker) async {
  if (await marker.exists()) return;
  final temporary = File('${marker.path}.migrating');
  try {
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString('1\n', flush: true);
    await temporary.rename(marker.path);
  } on Object {
    if (await temporary.exists()) {
      try {
        await temporary.delete();
      } on Object {
        // A populated canonical DB is still authoritative without the marker.
      }
    }
  }
}

class _DatabaseState {
  const _DatabaseState._({
    required this.file,
    required this.nonEmpty,
    required this.isCalenfi,
    required this.hasUserData,
    required this.contentFreshness,
    required this.familyModifiedAt,
  });

  factory _DatabaseState.missing(File file) => _DatabaseState._(
    file: file,
    nonEmpty: false,
    isCalenfi: false,
    hasUserData: false,
    contentFreshness: null,
    familyModifiedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  factory _DatabaseState.invalid(File file, {required bool nonEmpty}) =>
      _DatabaseState._(
        file: file,
        nonEmpty: nonEmpty,
        isCalenfi: false,
        hasUserData: false,
        contentFreshness: null,
        familyModifiedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  factory _DatabaseState.valid(
    File file, {
    required bool hasUserData,
    required DateTime? contentFreshness,
    required DateTime familyModifiedAt,
  }) => _DatabaseState._(
    file: file,
    nonEmpty: true,
    isCalenfi: true,
    hasUserData: hasUserData,
    contentFreshness: contentFreshness,
    familyModifiedAt: familyModifiedAt,
  );

  final File file;
  final bool nonEmpty;
  final bool isCalenfi;
  final bool hasUserData;
  final DateTime? contentFreshness;
  final DateTime familyModifiedAt;

  DateTime get freshnessAt => contentFreshness ?? familyModifiedAt;
}

class _WindowsAncillaryProfile {
  const _WindowsAncillaryProfile({
    required this.directory,
    required this.files,
    required this.tokens,
    required this.invalidCount,
    required this.freshest,
    required this.hasPrimaryState,
    required this.hasValidAccounts,
    required this.accountIds,
  });

  final Directory directory;
  final Map<String, File> files;
  final Map<String, File> tokens;
  final int invalidCount;
  final DateTime freshest;
  final bool hasPrimaryState;
  final bool hasValidAccounts;
  final Set<String>? accountIds;

  int get validFileCount => files.length + tokens.length;
}

class _PreservedDatabase {
  const _PreservedDatabase(this.files);

  final List<({File original, File backup})> files;

  Future<void> restore() async {
    for (final pair in files.reversed) {
      if (await pair.backup.exists() && !await pair.original.exists()) {
        await pair.backup.rename(pair.original.path);
      }
    }
  }
}
