import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'preset_categories.dart';

part 'app_database.g.dart';

// The app's own categories and payee → category memory
// (docs/plans/dart-parser.md, Phase 4). Times are epoch milliseconds, so
// the backend sync (newest wins) compares them exactly.

/// `source`: 'preset' (seeded from [presetGroups]) or 'user'.
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

  @override
  Set<Column> get primaryKey => {id};
}

/// A local category's Actual counterpart in one budget ("Match your
/// categories", Phase 4c), so one phone can serve several budgets.
class CategoryLinks extends Table {
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get budgetSyncId => text()();
  TextColumn get actualCategoryId => text()();

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

@DriftDatabase(tables: [CategoryGroups, Categories, CategoryLinks, PayeeCategories])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'app'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
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
  Future<void> seedPresets({DateTime? now}) => transaction(() async {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
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
