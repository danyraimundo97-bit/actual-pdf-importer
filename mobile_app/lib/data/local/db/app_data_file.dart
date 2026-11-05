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
///
/// Version 2 (docs/plans/local-ledger.md, Phase 8) adds `ledger`, the phone's own
/// budget: accounts, payees, transactions, budget amounts and the budget style.
/// A budget from Actual isn't in it: Actual's own backup has that.
const appDataSchemaVersion = 2;

class AppDataFileException implements Exception {
  /// `BACKUP_INVALID` or `BACKUP_TOO_NEW`, as the backend's codes.
  final String code;
  final String message;
  const AppDataFileException(this.code, this.message);

  @override
  String toString() => 'AppDataFileException($code): $message';
}

typedef AppDataImportResult = ({
  int categories,
  int mappings,
  int forgotten,
  int skipped,
  int accounts,
  int transactions,
});

/// The phone's categories, live category memory and own budget as an app-data
/// file. It holds amounts and isn't encrypted, so the screen says to keep it
/// somewhere safe.
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
    'ledger': await _ledgerSection(db),
  };
  return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(data))));
}

Future<Map<String, Object?>> _ledgerSection(AppDatabase db) async {
  final accounts = await (db.select(db.ledgerAccounts)..where((a) => a.scope.equals('') & a.deleted.equals(false))).get();
  final payees = await (db.select(db.ledgerPayees)..where((p) => p.scope.equals('') & p.deleted.equals(false))).get();
  final transactions = await (db.select(
    db.ledgerTransactions,
  )..where((t) => t.scope.equals('') & t.deleted.equals(false))).get();
  final budgets = await (db.select(db.ledgerBudgets)..where((b) => b.scope.equals(''))).get();
  final state = await (db.select(db.ledgerSyncState)..where((s) => s.scope.equals(''))).getSingleOrNull();
  return {
    'budgetMode': state?.budgetMode,
    'accounts': [for (final a in accounts) a.toJson()],
    'payees': [for (final p in payees) p.toJson()],
    'transactions': [for (final t in transactions) t.toJson()],
    'budgets': [for (final b in budgets) b.toJson()],
  };
}

/// Puts the phone's own budget back, as the rest of the file: rows in it are
/// written as new edits, and live rows not in it are removed. A row that has
/// since gone into a budget from Actual stays there: taking it back would
/// pull it out of that budget, or send it twice. Returns what was written.
Future<({int accounts, int transactions, int skipped})> _restoreLedger(
  AppDatabase db,
  Map<String, dynamic> ledger,
  int at,
) async {
  List<Map<String, dynamic>> rows(String key) => [
    for (final r in (ledger[key] as List? ?? const [])) (r as Map).cast<String, dynamic>(),
  ];
  final aliases = {for (final a in await db.select(db.ledgerIdAliases).get()) a.phoneId};
  final elsewhereAccounts = {
    for (final a in await (db.select(db.ledgerAccounts)..where((a) => a.scope.equals('').not())).get()) a.id,
    ...aliases,
  };
  final elsewhereTransactions = {
    for (final t in await (db.select(db.ledgerTransactions)..where((t) => t.scope.equals('').not())).get()) t.id,
    ...aliases,
  };
  final elsewherePayees = {
    for (final p in await (db.select(db.ledgerPayees)..where((p) => p.scope.equals('').not())).get()) p.id,
    ...aliases,
  };

  final accountIds = <String>{};
  for (final raw in rows('accounts')) {
    final a = LedgerAccount.fromJson(raw);
    if (elsewhereAccounts.contains(a.id)) continue;
    accountIds.add(a.id);
    await db
        .into(db.ledgerAccounts)
        .insertOnConflictUpdate(
          a.toCompanion(false).copyWith(scope: const Value(''), updatedAt: Value(at), deleted: const Value(false)),
        );
  }
  final payeeIds = <String>{};
  for (final raw in rows('payees')) {
    final p = LedgerPayee.fromJson(raw);
    if (elsewherePayees.contains(p.id)) continue;
    payeeIds.add(p.id);
    await db
        .into(db.ledgerPayees)
        .insertOnConflictUpdate(
          p.toCompanion(false).copyWith(scope: const Value(''), updatedAt: Value(at), deleted: const Value(false)),
        );
  }
  final transactionIds = <String>{};
  var skipped = 0;
  for (final raw in rows('transactions')) {
    final t = LedgerTransaction.fromJson(raw);
    if (elsewhereTransactions.contains(t.id) || !accountIds.contains(t.accountId)) {
      skipped++;
      continue;
    }
    transactionIds.add(t.id);
    await db
        .into(db.ledgerTransactions)
        .insertOnConflictUpdate(
          t
              .toCompanion(false)
              .copyWith(
                scope: const Value(''),
                payeeId: Value(payeeIds.contains(t.payeeId) ? t.payeeId : null),
                updatedAt: Value(at),
                deleted: const Value(false),
              ),
        );
  }

  // What the file doesn't have goes. Removals leave a tombstone, as anywhere.
  for (final t in await (db.select(db.ledgerTransactions)..where((t) => t.scope.equals('') & t.deleted.equals(false))).get()) {
    if (transactionIds.contains(t.id)) continue;
    await (db.update(db.ledgerTransactions)..where((x) => x.id.equals(t.id))).write(
      LedgerTransactionsCompanion(deleted: const Value(true), updatedAt: Value(at)),
    );
  }
  for (final a in await (db.select(db.ledgerAccounts)..where((a) => a.scope.equals('') & a.deleted.equals(false))).get()) {
    if (accountIds.contains(a.id)) continue;
    await (db.update(db.ledgerAccounts)..where((x) => x.id.equals(a.id))).write(
      LedgerAccountsCompanion(deleted: const Value(true), updatedAt: Value(at)),
    );
  }
  await (db.delete(db.ledgerBudgets)..where((b) => b.scope.equals(''))).go();
  for (final raw in rows('budgets')) {
    final b = LedgerBudget.fromJson(raw);
    await db
        .into(db.ledgerBudgets)
        .insertOnConflictUpdate(b.toCompanion(false).copyWith(scope: const Value(''), updatedAt: Value(at)));
  }
  await db
      .into(db.ledgerSyncState)
      .insert(
        LedgerSyncStateCompanion.insert(scope: '', budgetMode: Value(ledger['budgetMode'] as String?)),
        onConflict: DoUpdate((_) => LedgerSyncStateCompanion(budgetMode: Value(ledger['budgetMode'] as String?))),
      );
  return (accounts: accountIds.length, transactions: transactionIds.length, skipped: skipped);
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
  final ledger = data['ledger'];
  if (ledger != null && ledger is! Map) {
    throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
  }
  return data;
}

/// Puts an app-data file back on this phone, as the backend's restore does:
/// everything in the file is written as a new edit (so a later sync carries
/// it), and live mappings not in the file are forgotten. A mapping is kept
/// when its category exists here, or (a backend backup, with Actual ids)
/// through a link to that Actual category in its budget; otherwise skipped.
/// A file with no `ledger` (version 1, or a backend's) leaves the phone's own
/// budget alone. Nothing changes if any of it can't be read.
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
    final ledger = data['ledger'];
    var restored = (accounts: 0, transactions: 0, skipped: 0);
    if (ledger != null) {
      try {
        restored = await _restoreLedger(db, (ledger as Map).cast<String, dynamic>(), at);
      } on TypeError {
        throw const AppDataFileException('BACKUP_INVALID', "This file isn't an app-data backup, or it's damaged.");
      }
    }
    return (
      categories: categories,
      mappings: mappings,
      forgotten: forgotten,
      skipped: skipped + restored.skipped,
      accounts: restored.accounts,
      transactions: restored.transactions,
    );
  });
}
