import 'dart:convert';
import 'dart:io' show gzip;

import 'package:drift/drift.dart';

import '../../category_suggestions.dart';
import 'app_category_rows.dart';
import 'app_database.dart';

/// The app-data file format, shared with the backend's app-data backups
/// (backend_app/src/backup.ts, docs/plans/backups.md Phase 1a): gzipped JSON
/// with a manifest, the app's category rows, the category memory and (from
/// a backend) its removal log. A phone with no backend exports and imports
/// these by hand; one file restores onto either side.
const appDataSchemaVersion = 1;

class AppDataFileException implements Exception {
  /// `BACKUP_INVALID` or `BACKUP_TOO_NEW`, as the backend's codes.
  final String code;
  final String message;
  const AppDataFileException(this.code, this.message);

  @override
  String toString() => 'AppDataFileException($code): $message';
}

typedef AppDataImportResult = ({int categories, int mappings, int forgotten, int skipped});

/// The phone's categories and live category memory as an app-data file.
Future<Uint8List> exportAppDataFile(AppDatabase db, {required String appVersion, DateTime? now}) async {
  final rows = await appCategoryRows(db);
  final mappings = await (db.select(db.payeeCategories)..where((p) => p.deleted.equals(false))).get();
  final data = {
    'manifest': {
      'kind': 'app-data',
      'schemaVersion': appDataSchemaVersion,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'appVersion': appVersion,
      'source': 'phone',
    },
    'appCategories': rows,
    'mappings': [
      for (final m in mappings)
        {'budgetSyncId': m.budgetSyncId, 'payee': m.payeeLabel, 'categoryId': m.categoryId, 'updatedAt': m.updatedAt},
    ],
    'removals': const <Object>[],
  };
  return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(data))));
}

Map<String, dynamic> _read(Uint8List bytes) {
  Object? data;
  try {
    data = jsonDecode(utf8.decode(gzip.decode(bytes)));
  } catch (_) {
    throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
  }
  if (data is! Map<String, dynamic>) {
    throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
  }
  final manifest = data['manifest'];
  if (manifest is! Map || manifest['kind'] != 'app-data' || manifest['schemaVersion'] is! int) {
    throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
  }
  if ((manifest['schemaVersion'] as int) > appDataSchemaVersion) {
    throw const AppDataFileException(
      'BACKUP_TOO_NEW',
      'This backup was made by a newer version of the app. Update the app first.',
    );
  }
  if (data['appCategories'] is! List || data['mappings'] is! List) {
    throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
  }
  return data;
}

/// Puts an app-data file back on this phone, as the backend's restore does:
/// everything in the file is written as a new edit (so a later sync carries
/// it), and live mappings not in the file are forgotten. A mapping is kept
/// when its category exists here, or (a backend backup, with Actual ids)
/// through a link to that Actual category in its budget; otherwise skipped.
Future<AppDataImportResult> importAppDataFile(AppDatabase db, Uint8List bytes, {DateTime? now}) async {
  final data = _read(bytes);
  final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final rows = [
    for (final r in (data['appCategories'] as List).whereType<Map>()) {...r.cast<String, dynamic>(), 'updatedAt': at},
  ];
  return db.transaction(() async {
    final categories = await applyAppCategoryRows(db, rows);

    final known = {for (final c in await db.select(db.categories).get()) c.id};
    final links = await db.select(db.categoryLinks).get();
    String? resolve(String budget, String categoryId) {
      if (known.contains(categoryId)) return categoryId;
      for (final l in links) {
        if (l.budgetSyncId == budget && l.actualCategoryId == categoryId) return l.categoryId;
      }
      return null;
    }

    final keep = <(String, String)>{};
    var mappings = 0, skipped = 0;
    for (final raw in (data['mappings'] as List).whereType<Map>()) {
      final payee = raw['payee'];
      final budget = raw['budgetSyncId'] is String ? raw['budgetSyncId'] as String : '';
      final categoryId = raw['categoryId'];
      if (payee is! String || payee.trim().isEmpty || categoryId is! String) {
        skipped++;
        continue;
      }
      final local = resolve(budget, categoryId);
      if (local == null) {
        skipped++;
        continue;
      }
      final key = categoryMemoryKey(payee);
      keep.add((budget, key));
      await db
          .into(db.payeeCategories)
          .insertOnConflictUpdate(
            PayeeCategoriesCompanion.insert(
              budgetSyncId: budget,
              payeeKey: key,
              payeeLabel: payee.trim(),
              categoryId: local,
              updatedAt: at,
              deleted: const Value(false),
            ),
          );
      mappings++;
    }

    var forgotten = 0;
    for (final row in await (db.select(db.payeeCategories)..where((p) => p.deleted.equals(false))).get()) {
      if (keep.contains((row.budgetSyncId, row.payeeKey))) continue;
      await (db.update(db.payeeCategories)
            ..where((p) => p.budgetSyncId.equals(row.budgetSyncId) & p.payeeKey.equals(row.payeeKey)))
          .write(PayeeCategoriesCompanion(deleted: const Value(true), updatedAt: Value(at)));
      forgotten++;
    }
    return (categories: categories, mappings: mappings, forgotten: forgotten, skipped: skipped);
  });
}
