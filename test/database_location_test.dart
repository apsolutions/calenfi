import 'dart:io';

import 'package:calenfi/data/local/db/database_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temporaryRoot;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'calenfi-data-migration-',
    );
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('Linux data path always uses the canonical application id', () {
    final xdg = p.join(temporaryRoot.path, 'share');
    final directory = linuxApplicationSupportDirectory(
      environment: <String, String>{'XDG_DATA_HOME': xdg},
    );

    expect(directory.path, p.join(xdg, kApplicationId));
  });

  test('Windows migration includes the v0.3.1 lower-case product path', () {
    final canonical = Directory(
      p.join(temporaryRoot.path, 'apsolutions', 'Calenfi'),
    );

    final legacy = windowsLegacyApplicationSupportDirectories(canonical);

    expect(
      legacy.map((directory) => directory.path),
      contains(p.join(temporaryRoot.path, 'apsolutions', 'calenfi')),
    );
  });

  test(
    'Windows ancillary migration copies missing state without overwrites',
    () async {
      final canonical = Directory(
        p.join(temporaryRoot.path, 'apsolutions', 'calenfi'),
      )..createSync(recursive: true);
      final legacy = Directory(
        p.join(temporaryRoot.path, 'io.github.karpovilia', 'calenfi'),
      )..createSync(recursive: true);
      File(
        p.join(canonical.path, 'accounts.json'),
      ).writeAsStringSync('canonical');
      File(
        p.join(legacy.path, 'accounts.json'),
      ).writeAsStringSync(_accountsJson('legacy'));
      File(
        p.join(legacy.path, 'secrets.dpapi'),
      ).writeAsStringSync('ciphertext');
      File(p.join(legacy.path, 'secrets.json')).writeAsStringSync('{"K":"V"}');
      final tokens = Directory(p.join(legacy.path, '.tokens'))
        ..createSync(recursive: true);
      File(
        p.join(tokens.path, 'gcal_user.json'),
      ).writeAsStringSync('{"access_token":"token"}');

      await prepareWindowsAncillaryState(
        targetDirectory: canonical,
        legacyDirectories: <Directory>[legacy],
      );

      expect(
        File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
        'canonical',
      );
      expect(
        File(p.join(canonical.path, 'secrets.dpapi')).readAsStringSync(),
        'ciphertext',
      );
      expect(
        File(p.join(canonical.path, 'secrets.json')).readAsStringSync(),
        '{"K":"V"}',
      );
      expect(
        File(
          p.join(canonical.path, '.tokens', 'gcal_user.json'),
        ).readAsStringSync(),
        '{"access_token":"token"}',
      );
      expect(File(p.join(legacy.path, 'secrets.dpapi')).existsSync(), isTrue);
    },
  );

  test('Windows ancillary migration skips a newer corrupt profile', () async {
    final canonical = Directory(
      p.join(temporaryRoot.path, 'apsolutions', 'calenfi'),
    );
    final valid = Directory(p.join(temporaryRoot.path, 'valid', 'calenfi'))
      ..createSync(recursive: true);
    final corrupt = Directory(p.join(temporaryRoot.path, 'corrupt', 'calenfi'))
      ..createSync(recursive: true);

    final validAccounts = File(p.join(valid.path, 'accounts.json'))
      ..writeAsStringSync(_accountsJson('valid'));
    final validDpapi = File(p.join(valid.path, 'secrets.dpapi'))
      ..writeAsStringSync('valid ciphertext');
    final validTokens = Directory(p.join(valid.path, '.tokens'))
      ..createSync(recursive: true);
    final validToken = File(p.join(validTokens.path, 'gcal_user.json'))
      ..writeAsStringSync('{"refresh_token":"valid"}');

    final corruptAccounts = File(p.join(corrupt.path, 'accounts.json'))
      ..writeAsStringSync('{not json');
    final corruptDpapi = File(p.join(corrupt.path, 'secrets.dpapi'))
      ..writeAsStringSync('   \n');
    final corruptTokens = Directory(p.join(corrupt.path, '.tokens'))
      ..createSync(recursive: true);
    final corruptToken = File(p.join(corruptTokens.path, 'gcal_user.json'))
      ..writeAsStringSync('[]');

    for (final file in <File>[validAccounts, validDpapi, validToken]) {
      file.setLastModifiedSync(DateTime.utc(2025));
    }
    for (final file in <File>[corruptAccounts, corruptDpapi, corruptToken]) {
      file.setLastModifiedSync(DateTime.utc(2027));
    }

    await prepareWindowsAncillaryState(
      targetDirectory: canonical,
      legacyDirectories: <Directory>[corrupt, valid],
    );

    expect(
      File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
      _accountsJson('valid'),
    );
    expect(
      File(p.join(canonical.path, 'secrets.dpapi')).readAsStringSync(),
      'valid ciphertext',
    );
    expect(
      File(
        p.join(canonical.path, '.tokens', 'gcal_user.json'),
      ).readAsStringSync(),
      '{"refresh_token":"valid"}',
    );
  });

  test('Windows ancillary migration never mixes legacy profiles', () async {
    final canonical = Directory(
      p.join(temporaryRoot.path, 'apsolutions', 'calenfi'),
    );
    final profileA = Directory(p.join(temporaryRoot.path, 'profile-a'))
      ..createSync(recursive: true);
    final profileB = Directory(p.join(temporaryRoot.path, 'profile-b'))
      ..createSync(recursive: true);

    final accountsA = File(p.join(profileA.path, 'accounts.json'))
      ..writeAsStringSync(_accountsJson('profile-a'))
      ..setLastModifiedSync(DateTime.utc(2024));
    final dpapiA = File(p.join(profileA.path, 'secrets.dpapi'))
      ..writeAsStringSync('ciphertext-a')
      ..setLastModifiedSync(DateTime.utc(2027));
    final accountsB = File(p.join(profileB.path, 'accounts.json'))
      ..writeAsStringSync(_accountsJson('profile-b'))
      ..setLastModifiedSync(DateTime.utc(2028));
    final dpapiB = File(p.join(profileB.path, 'secrets.dpapi'))
      ..writeAsStringSync('ciphertext-b')
      ..setLastModifiedSync(DateTime.utc(2025));

    // Keep references alive and make the independent-file failure mode clear:
    // newest accounts is B, while newest DPAPI file is A.
    expect(
      accountsB.lastModifiedSync().isAfter(accountsA.lastModifiedSync()),
      isTrue,
    );
    expect(
      dpapiA.lastModifiedSync().isAfter(dpapiB.lastModifiedSync()),
      isTrue,
    );

    await prepareWindowsAncillaryState(
      targetDirectory: canonical,
      legacyDirectories: <Directory>[profileA, profileB],
    );

    expect(
      File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
      _accountsJson('profile-b'),
    );
    expect(
      File(p.join(canonical.path, 'secrets.dpapi')).readAsStringSync(),
      'ciphertext-b',
    );
  });

  test(
    'Windows ancillary profile matches existing canonical accounts',
    () async {
      final canonical = Directory(p.join(temporaryRoot.path, 'canonical'))
        ..createSync(recursive: true);
      File(
        p.join(canonical.path, 'accounts.json'),
      ).writeAsStringSync(_accountsJson('matching'));

      final matching = Directory(p.join(temporaryRoot.path, 'matching'))
        ..createSync(recursive: true);
      File(
        p.join(matching.path, 'accounts.json'),
      ).writeAsStringSync(_accountsJson('matching'));
      File(
        p.join(matching.path, 'secrets.dpapi'),
      ).writeAsStringSync('matching ciphertext');

      final newerDifferent = Directory(
        p.join(temporaryRoot.path, 'newer-different'),
      )..createSync(recursive: true);
      final differentAccounts = File(
        p.join(newerDifferent.path, 'accounts.json'),
      )..writeAsStringSync(_accountsJson('different'));
      final differentDpapi = File(p.join(newerDifferent.path, 'secrets.dpapi'))
        ..writeAsStringSync('different ciphertext');
      differentAccounts.setLastModifiedSync(DateTime.utc(2028));
      differentDpapi.setLastModifiedSync(DateTime.utc(2028));

      await prepareWindowsAncillaryState(
        targetDirectory: canonical,
        legacyDirectories: <Directory>[newerDifferent, matching],
      );

      expect(
        File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
        _accountsJson('matching'),
      );
      expect(
        File(p.join(canonical.path, 'secrets.dpapi')).readAsStringSync(),
        'matching ciphertext',
      );
    },
  );

  test(
    'Windows ancillary migration prefers primary state over locale-only',
    () async {
      final canonical = Directory(p.join(temporaryRoot.path, 'canonical'));
      final localeOnly = Directory(p.join(temporaryRoot.path, 'locale-only'))
        ..createSync(recursive: true);
      File(p.join(localeOnly.path, 'locale')).writeAsStringSync('ru');

      final accountProfile = Directory(
        p.join(temporaryRoot.path, 'account-profile'),
      )..createSync(recursive: true);
      File(
        p.join(accountProfile.path, 'accounts.json'),
      ).writeAsStringSync(_accountsJson('account-profile'));
      final tokens = Directory(p.join(accountProfile.path, '.tokens'))
        ..createSync(recursive: true);
      // One damaged optional token must not make a locale-only directory win.
      File(p.join(tokens.path, 'gcal_broken.json')).writeAsStringSync('');

      await prepareWindowsAncillaryState(
        targetDirectory: canonical,
        legacyDirectories: <Directory>[localeOnly, accountProfile],
      );

      expect(
        File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
        _accountsJson('account-profile'),
      );
      expect(File(p.join(canonical.path, 'locale')).existsSync(), isFalse);
    },
  );

  test(
    'valid empty Windows profile stays authoritative over populated legacy',
    () async {
      final canonical = Directory(p.join(temporaryRoot.path, 'canonical'));
      final populated = Directory(p.join(temporaryRoot.path, 'populated'))
        ..createSync(recursive: true);
      final oldAccounts = File(p.join(populated.path, 'accounts.json'))
        ..writeAsStringSync(_accountsJson('old'))
        ..setLastModifiedSync(DateTime.utc(2025));
      final oldSecrets = File(p.join(populated.path, 'secrets.json'))
        ..writeAsStringSync('{"OLD":"secret"}')
        ..setLastModifiedSync(DateTime.utc(2025));

      final emptied = Directory(p.join(temporaryRoot.path, 'emptied'))
        ..createSync(recursive: true);
      final emptyAccounts = File(p.join(emptied.path, 'accounts.json'))
        ..writeAsStringSync('[]')
        ..setLastModifiedSync(DateTime.utc(2026));
      final emptySecrets = File(p.join(emptied.path, 'secrets.json'))
        ..writeAsStringSync('{}')
        ..setLastModifiedSync(DateTime.utc(2026));

      expect(
        emptyAccounts.lastModifiedSync().isAfter(
          oldAccounts.lastModifiedSync(),
        ),
        isTrue,
      );
      expect(
        emptySecrets.lastModifiedSync().isAfter(oldSecrets.lastModifiedSync()),
        isTrue,
      );

      await prepareWindowsAncillaryState(
        targetDirectory: canonical,
        legacyDirectories: <Directory>[populated, emptied],
      );

      expect(
        File(p.join(canonical.path, 'accounts.json')).readAsStringSync(),
        '[]',
      );
      expect(
        File(p.join(canonical.path, 'secrets.json')).readAsStringSync(),
        '{}',
      );
    },
  );

  test(
    'migrates a legacy SQLite database without removing the source',
    () async {
      final legacyDirectory = Directory(p.join(temporaryRoot.path, 'legacy'))
        ..createSync(recursive: true);
      final legacyFile = File(p.join(legacyDirectory.path, kDbFileName));
      _writeCalenfiDatabase(legacyFile, 'legacy event');

      final canonicalDirectory = Directory(
        p.join(temporaryRoot.path, kApplicationId),
      );
      final result = await prepareDatabaseFile(
        targetDirectory: canonicalDirectory,
        legacyDirectories: <Directory>[legacyDirectory],
      );

      expect(result.path, p.join(canonicalDirectory.path, kDbFileName));
      expect(legacyFile.existsSync(), isTrue);
      expect(_readValues(result), <String>['legacy event']);
      expect(File('${result.path}.migrating').existsSync(), isFalse);
      expect(
        File(
          p.join(canonicalDirectory.path, kDbMigrationMarkerFileName),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('never overwrites a populated canonical database', () async {
    final legacyDirectory = Directory(p.join(temporaryRoot.path, 'legacy'))
      ..createSync(recursive: true);
    _writeCalenfiDatabase(
      File(p.join(legacyDirectory.path, kDbFileName)),
      'legacy event',
    );

    final canonicalDirectory = Directory(
      p.join(temporaryRoot.path, kApplicationId),
    )..createSync(recursive: true);
    final canonicalFile = File(p.join(canonicalDirectory.path, kDbFileName));
    _writeCalenfiDatabase(canonicalFile, 'canonical event');

    final result = await prepareDatabaseFile(
      targetDirectory: canonicalDirectory,
      legacyDirectories: <Directory>[legacyDirectory],
    );

    expect(result.path, canonicalFile.path);
    expect(_readValues(result), <String>['canonical event']);
  });

  test('replaces an unmarked schema-only v0.3.1 database', () async {
    final legacyDirectory = Directory(p.join(temporaryRoot.path, 'legacy'))
      ..createSync(recursive: true);
    _writeCalenfiDatabase(
      File(p.join(legacyDirectory.path, kDbFileName)),
      'legacy event',
    );
    final canonicalDirectory = Directory(
      p.join(temporaryRoot.path, kApplicationId),
    )..createSync(recursive: true);
    final canonicalFile = File(p.join(canonicalDirectory.path, kDbFileName));
    _writeCalenfiDatabase(canonicalFile);

    final result = await prepareDatabaseFile(
      targetDirectory: canonicalDirectory,
      legacyDirectories: <Directory>[legacyDirectory],
    );

    expect(_readValues(result), <String>['legacy event']);
    expect(
      File('${canonicalFile.path}.pre-app-id-migration').existsSync(),
      isTrue,
    );
  });

  test('marker prevents retained legacy data from being resurrected', () async {
    final legacyDirectory = Directory(p.join(temporaryRoot.path, 'legacy'))
      ..createSync(recursive: true);
    _writeCalenfiDatabase(
      File(p.join(legacyDirectory.path, kDbFileName)),
      'legacy event',
    );
    final canonicalDirectory = Directory(
      p.join(temporaryRoot.path, kApplicationId),
    );
    final canonical = await prepareDatabaseFile(
      targetDirectory: canonicalDirectory,
      legacyDirectories: <Directory>[legacyDirectory],
    );
    _clearDatabase(canonical);

    final result = await prepareDatabaseFile(
      targetDirectory: canonicalDirectory,
      legacyDirectories: <Directory>[legacyDirectory],
    );

    expect(result.path, canonical.path);
    expect(_readValues(result), isEmpty);
  });

  test(
    'skips a newer corrupt candidate and migrates the next valid one',
    () async {
      final validDirectory = Directory(p.join(temporaryRoot.path, 'valid'))
        ..createSync(recursive: true);
      final valid = File(p.join(validDirectory.path, kDbFileName));
      _writeCalenfiDatabase(valid, 'valid event');
      valid.setLastModifiedSync(DateTime(2026));

      final corruptDirectory = Directory(p.join(temporaryRoot.path, 'corrupt'))
        ..createSync(recursive: true);
      final corrupt = File(p.join(corruptDirectory.path, kDbFileName))
        ..writeAsStringSync('not a SQLite database');
      corrupt.setLastModifiedSync(DateTime(2027));

      final result = await prepareDatabaseFile(
        targetDirectory: Directory(p.join(temporaryRoot.path, kApplicationId)),
        legacyDirectories: <Directory>[corruptDirectory, validDirectory],
      );

      expect(_readValues(result), <String>['valid event']);
      expect(corrupt.readAsStringSync(), 'not a SQLite database');
    },
  );

  test(
    'prefers fresher SQLite content in WAL over a newer main-file mtime',
    () async {
      final freshDirectory = Directory(p.join(temporaryRoot.path, 'fresh'))
        ..createSync(recursive: true);
      final freshFile = File(p.join(freshDirectory.path, kDbFileName));
      final freshDatabase = sqlite3.open(freshFile.path);
      try {
        freshDatabase.execute('PRAGMA journal_mode = WAL');
        freshDatabase.execute('PRAGMA wal_autocheckpoint = 0');
        _createTimestampedCalenfiSchema(freshDatabase);
        freshDatabase.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        freshDatabase.execute('INSERT INTO accounts VALUES (?, ?)', <Object?>[
          'fresh WAL event',
          _seconds(DateTime.utc(2026, 8, 31)),
        ]);
        // The current data lives in WAL; make the main file deliberately older.
        freshFile.setLastModifiedSync(DateTime.utc(2024));
        expect(File('${freshFile.path}-wal').lengthSync(), greaterThan(0));

        final staleDirectory = Directory(p.join(temporaryRoot.path, 'stale'))
          ..createSync(recursive: true);
        final staleFile = File(p.join(staleDirectory.path, kDbFileName));
        _writeTimestampedCalenfiDatabase(
          staleFile,
          'stale event',
          DateTime.utc(2026, 8, 30),
        );
        staleFile.setLastModifiedSync(DateTime.utc(2027));
        expect(
          staleFile.lastModifiedSync().isAfter(freshFile.lastModifiedSync()),
          isTrue,
        );

        final result = await prepareDatabaseFile(
          targetDirectory: Directory(
            p.join(temporaryRoot.path, kApplicationId),
          ),
          legacyDirectories: <Directory>[staleDirectory, freshDirectory],
        );

        expect(_readValues(result), <String>['fresh WAL event']);
      } finally {
        freshDatabase.dispose();
      }
    },
  );

  test(
    'refuses a silent empty database when every source is corrupt',
    () async {
      final legacyDirectory = Directory(p.join(temporaryRoot.path, 'legacy'))
        ..createSync(recursive: true);
      final legacyFile = File(p.join(legacyDirectory.path, kDbFileName))
        ..writeAsStringSync('not a SQLite database');
      final canonicalDirectory = Directory(
        p.join(temporaryRoot.path, kApplicationId),
      );

      await expectLater(
        prepareDatabaseFile(
          targetDirectory: canonicalDirectory,
          legacyDirectories: <Directory>[legacyDirectory],
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(legacyFile.readAsStringSync(), 'not a SQLite database');
      expect(
        File(p.join(canonicalDirectory.path, kDbFileName)).existsSync(),
        isFalse,
      );
    },
  );
}

String _accountsJson(String id) =>
    '[{"id":"$id","provider":"caldav","email":"$id@example.test"}]';

int _seconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

void _createTimestampedCalenfiSchema(Database database) {
  database.execute('CREATE TABLE accounts (value TEXT, last_sync_utc INTEGER)');
  database.execute('CREATE TABLE calendars (value TEXT)');
  database.execute('CREATE TABLE events (value TEXT)');
  database.execute('CREATE TABLE outbox (value TEXT, created_at INTEGER)');
  database.execute('CREATE TABLE contacts (value TEXT)');
}

void _writeTimestampedCalenfiDatabase(
  File file,
  String value,
  DateTime lastSyncUtc,
) {
  file.parent.createSync(recursive: true);
  final database = sqlite3.open(file.path);
  try {
    _createTimestampedCalenfiSchema(database);
    database.execute('INSERT INTO accounts VALUES (?, ?)', <Object?>[
      value,
      _seconds(lastSyncUtc),
    ]);
  } finally {
    database.dispose();
  }
}

void _writeCalenfiDatabase(File file, [String? value]) {
  file.parent.createSync(recursive: true);
  final database = sqlite3.open(file.path);
  try {
    for (final table in <String>[
      'accounts',
      'calendars',
      'events',
      'outbox',
      'contacts',
    ]) {
      database.execute('CREATE TABLE $table (value TEXT)');
    }
    if (value != null) {
      database.execute('INSERT INTO accounts VALUES (?)', <Object?>[value]);
    }
  } finally {
    database.dispose();
  }
}

void _clearDatabase(File file) {
  final database = sqlite3.open(file.path);
  try {
    for (final table in <String>[
      'accounts',
      'calendars',
      'events',
      'outbox',
      'contacts',
    ]) {
      database.execute('DELETE FROM $table');
    }
  } finally {
    database.dispose();
  }
}

List<String> _readValues(File file) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return database
        .select('SELECT value FROM accounts')
        .map((row) => row['value'])
        .whereType<String>()
        .toList();
  } finally {
    database.dispose();
  }
}
