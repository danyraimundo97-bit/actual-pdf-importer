import 'package:drift/drift.dart';

import '../../category_suggestions.dart';
import '../../models/actual_category.dart';
import 'app_database.dart';
import 'preset_hints.dart';

/// Where a suggestion came from, best first.
enum SuggestionSource { memory, hint }

typedef LocalSuggestion = ({String categoryId, String categoryName, SuggestionSource source});

/// The app's own categories and category memory, for when Actual isn't
/// connected. Lookups follow the backend's order: the budget's mapping,
/// then the unscoped one ('' — also the only scope without a budget).
class LocalCategoryStore {
  LocalCategoryStore(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  int get _at => _now().millisecondsSinceEpoch;

  /// Visible groups and categories, in their order, shaped like Actual's so
  /// the same picker shows either. Empty groups are left out.
  Future<List<ActualCategoryGroup>> groups() async {
    final groups =
        await (_db.select(_db.categoryGroups)
              ..where((g) => g.hidden.equals(false))
              ..orderBy([(g) => OrderingTerm(expression: g.isIncome), (g) => OrderingTerm(expression: g.sort)]))
            .get();
    final categories =
        await (_db.select(_db.categories)
              ..where((c) => c.hidden.equals(false))
              ..orderBy([(c) => OrderingTerm(expression: c.sort)]))
            .get();
    return [
      for (final g in groups)
        if (categories.any((c) => c.groupId == g.id))
          ActualCategoryGroup(
            id: g.id,
            name: g.name,
            categories: [
              for (final c in categories)
                if (c.groupId == g.id) ActualCategory(id: c.id, name: c.name),
            ],
          ),
    ];
  }

  /// The category memory first, then a merchant hint. Null when neither.
  Future<LocalSuggestion?> suggest(String payee, {String? budgetSyncId}) async {
    final key = categoryMemoryKey(payee);
    for (final scope in {budgetSyncId ?? '', ''}) {
      final row =
          await (_db.select(_db.payeeCategories).join([
                innerJoin(_db.categories, _db.categories.id.equalsExp(_db.payeeCategories.categoryId)),
              ])..where(
                _db.payeeCategories.budgetSyncId.equals(scope) &
                    _db.payeeCategories.payeeKey.equals(key) &
                    _db.payeeCategories.deleted.equals(false),
              ))
              .getSingleOrNull();
      if (row != null) {
        final category = row.readTable(_db.categories);
        return (categoryId: category.id, categoryName: category.name, source: SuggestionSource.memory);
      }
    }
    final presetKey = hintPresetKey(payee);
    if (presetKey == null) return null;
    final category = await (_db.select(
      _db.categories,
    )..where((c) => c.presetKey.equals(presetKey) & c.hidden.equals(false))).getSingleOrNull();
    if (category == null) return null;
    return (categoryId: category.id, categoryName: category.name, source: SuggestionSource.hint);
  }

  /// Remembers (or re-points) a payee's category.
  Future<void> remember(String payee, String categoryId, {String? budgetSyncId}) {
    return _db
        .into(_db.payeeCategories)
        .insertOnConflictUpdate(
          PayeeCategoriesCompanion.insert(
            budgetSyncId: budgetSyncId ?? '',
            payeeKey: categoryMemoryKey(payee),
            payeeLabel: payee.trim(),
            categoryId: categoryId,
            updatedAt: _at,
            deleted: const Value(false),
          ),
        );
  }

  /// Forgets a mapping, leaving a tombstone for the sync.
  Future<void> forget(String payee, {String? budgetSyncId}) {
    return (_db.update(_db.payeeCategories)
          ..where((p) => p.budgetSyncId.equals(budgetSyncId ?? '') & p.payeeKey.equals(categoryMemoryKey(payee))))
        .write(PayeeCategoriesCompanion(deleted: const Value(true), updatedAt: Value(_at)));
  }

  /// Live mappings of one scope, by payee.
  Future<List<({String payee, String categoryId, String categoryName})>> mappings({String? budgetSyncId}) async {
    final rows =
        await (_db.select(_db.payeeCategories).join([
                innerJoin(_db.categories, _db.categories.id.equalsExp(_db.payeeCategories.categoryId)),
              ])
              ..where(
                _db.payeeCategories.budgetSyncId.equals(budgetSyncId ?? '') & _db.payeeCategories.deleted.equals(false),
              )
              ..orderBy([OrderingTerm(expression: _db.payeeCategories.payeeLabel)]))
            .get();
    return [
      for (final r in rows)
        (
          payee: r.readTable(_db.payeeCategories).payeeLabel,
          categoryId: r.readTable(_db.categories).id,
          categoryName: r.readTable(_db.categories).name,
        ),
    ];
  }

  /// True for an id from this store, as opposed to one of Actual's: presets
  /// are `preset:<key>` (see presetId), user categories (Phase 4b) will be
  /// `local:<uuid>`.
  static bool isLocalId(String id) => id.startsWith('preset:') || id.startsWith('local:');
}
