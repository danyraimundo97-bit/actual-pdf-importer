import 'package:drift/drift.dart';

import 'ledger_tables.dart';
import 'preset_categories.dart';

export 'ledger_tables.dart';

part 'app_database.g.dart';

// The app's own categories and payee → category memory
// (docs/plans/dart-parser.md, Phase 4). Times are epoch milliseconds, so
// the backend sync (newest wins) compares them exactly.

/// `source`: 'preset' (seeded from [presetGroups]), 'user', or 'actual' (a
/// copy of an Actual category the phone learned a mapping for, id
/// `actual:<Actual id>`; see CategorySync).
class CategoryGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sort => integer()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  TextColumn get source => text()();
  TextColumn get presetKey => text().nullable().unique()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().references(CategoryGroups, #id)();
  TextColumn get name => text()();
  IntColumn get sort => integer()();
  TextColumn get source => text()();
  TextColumn get presetKey => text().nullable().unique()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  /// Schema 6. Null = not chosen (a preset then shows its own), '' = none.
  TextColumn get emoji => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A local category's Actual counterpart in one budget ("Match your
/// categories", Phase 4c), so one phone can serve several budgets.
class CategoryLinks extends Table {
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get budgetSyncId => text()();
  TextColumn get actualCategoryId => text()();

  /// Epoch ms, for the sync (schema 2; 0 for links made before).
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {categoryId, budgetSyncId};
}

/// The category memory. `budgetSyncId` '' is the unscoped bucket, as on the
/// backend; `payeeKey` is [categoryMemoryKey]. A forgotten mapping is a
/// tombstone (`deleted`), so the sync can carry the forgetting across.
class PayeeCategories extends Table {
  TextColumn get budgetSyncId => text()();
  TextColumn get payeeKey => text()();
  TextColumn get payeeLabel => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {budgetSyncId, payeeKey};
}

@DriftDatabase(
  tables: [
    CategoryGroups,
    Categories,
    CategoryLinks,
    PayeeCategories,
    LedgerAccounts,
    LedgerPayees,
    LedgerTransactions,
    LedgerBudgets,
    LedgerOutbox,
    LedgerSyncState,
    LedgerCategories,
    LedgerIdAliases,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// The app opens it with `openAppDatabaseConnection` (encrypted); tests
  /// pass `NativeDatabase.memory()`.
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(categoryLinks, categoryLinks.updatedAt);
      if (from < 3) {
        // The local ledger (docs/plans/local-ledger.md, Phases 2 and 5).
        for (final TableInfo table in [
          ledgerAccounts,
          ledgerPayees,
          ledgerTransactions,
          ledgerBudgets,
          ledgerOutbox,
          ledgerSyncState,
          ledgerCategories,
          ledgerIdAliases,
        ]) {
          await m.createTable(table);
        }
        for (final index in [ledgerTransactionsAccountDate, ledgerTransactionsScopeDate, ledgerTransactionsAccountImported]) {
          await m.createIndex(index);
        }
      } else {
        if (from < 4) {
          // The sync with Actual (Phase 5): an Actual budget's categories, and
          // importedId no longer unique (rebuilding the table drops the
          // constraint; its indexes are made again if the rebuild lost them).
          await m.alterTable(TableMigration(ledgerTransactions));
          await customStatement(
            'CREATE INDEX IF NOT EXISTS ledger_transactions_account_date ON ledger_transactions (account_id, date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS ledger_transactions_scope_date ON ledger_transactions (scope, date)',
          );
          await m.createIndex(ledgerTransactionsAccountImported);
          await m.createTable(ledgerCategories);
        }
        if (from < 5) {
          // Sending the phone's changes (Phase 5b).
          await m.addColumn(ledgerOutbox, ledgerOutbox.revision);
          await m.createTable(ledgerIdAliases);
        }
      }
      if (from < 6) await m.addColumn(categories, categories.emoji);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Every open, not just the first: a newer app version may ship
      // presets this database hasn't seen. Existing ones are left alone.
      await seedPresets();
    },
  );

  /// Inserts presets missing by `presetKey`. Never touches one that exists,
  /// so a rename or a hidden preset survives app updates; a preset the user
  /// deleted isn't possible (presets are hidden, not deleted).
  ///
  /// Seeded rows get `updatedAt` 0, older than any real edit: on a new phone
  /// the sync then brings back the user's renames instead of the defaults
  /// winning.
  Future<void> seedPresets() => transaction(() async {
    const at = 0;
    final knownGroups = {
      for (final g in await select(categoryGroups).get())
        if (g.presetKey != null) g.presetKey!: g.id,
    };
    final knownCategories = {
      for (final c in await select(categories).get())
        if (c.presetKey != null) c.presetKey!,
    };
    for (final (gi, group) in presetGroups.indexed) {
      final groupId = knownGroups[group.key] ?? presetId(group.key);
      if (!knownGroups.containsKey(group.key)) {
        await into(categoryGroups).insert(
          CategoryGroupsCompanion.insert(
            id: groupId,
            name: group.name,
            sort: gi,
            isIncome: Value(group.isIncome),
            source: 'preset',
            presetKey: Value(group.key),
            updatedAt: at,
          ),
        );
      }
      for (final (ci, category) in group.categories.indexed) {
        if (knownCategories.contains(category.key)) continue;
        await into(categories).insert(
          CategoriesCompanion.insert(
            id: presetId(category.key),
            groupId: groupId,
            name: category.name,
            sort: ci,
            source: 'preset',
            presetKey: Value(category.key),
            updatedAt: at,
          ),
        );
      }
    }
  });
}
