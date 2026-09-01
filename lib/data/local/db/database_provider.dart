import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'database_location.dart';

/// Единственный инстанс локальной БД на всё приложение.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(_openConnection());
  ref.onDispose(db.close);
  return db;
});

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final Directory dir;
    final Iterable<Directory> legacyDirectories;
    if (Platform.isLinux) {
      dir = linuxApplicationSupportDirectory();
      legacyDirectories = linuxLegacyApplicationSupportDirectories();
    } else {
      dir = await getApplicationSupportDirectory();
      legacyDirectories = _legacyDesktopDirectories(dir);
    }
    final file = await prepareDatabaseFile(
      targetDirectory: dir,
      legacyDirectories: legacyDirectories,
    );
    return NativeDatabase.createInBackground(file);
  });
}

Iterable<Directory> _legacyDesktopDirectories(Directory canonical) sync* {
  if (Platform.isMacOS) {
    for (final id in kLegacyApplicationIds) {
      yield Directory(p.join(canonical.parent.path, id));
    }
  } else if (Platform.isWindows) {
    // path_provider_windows derives this path from CompanyName/ProductName.
    // v0.3.1 used apsolutions/calenfi; older builds used the identifiers below.
    yield* windowsLegacyApplicationSupportDirectories(canonical);
  }
}
