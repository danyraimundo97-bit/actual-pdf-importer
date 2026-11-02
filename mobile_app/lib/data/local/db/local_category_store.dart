import 'dart:math';

import 'package:drift/drift.dart';

import '../../category_suggestions.dart';
import '../../models/actual_category.dart';
import 'app_database.dart';
import 'preset_hints.dart';

/// Where a suggestion came from, best first.
enum SuggestionSource { memory, hint }

typedef LocalSuggestion = ({String categoryId, String categoryName, SuggestionSource source});

/// A category as the Categories screen shows it, hidden ones included.
typedef ManagedCategory = ({String id, String name, bool hidden, bool isPreset});

typedef ManagedGroup = ({
  String id,
  String name,
  bool isIncome,
  bool hidden,
  bool isPreset,
  List<ManagedCategory> categories,
});

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
                    _db.payeeCategories.deleted.equals(false) &
                    // A hidden category isn't suggested; its mappings stay
                    // and work again once it's shown.
                    _db.categories.hidden.equals(false),
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
  Future<List<({String payee, String categoryId, String categoryName, String updatedAt})>> mappings({
    String? budgetSyncId,
  }) async {
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
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            r.readTable(_db.payeeCategories).updatedAt,
            isUtc: true,
          ).toIso8601String(),
        ),
    ];
  }

  /// Forgets every live mapping of one scope (tombstones). Returns how many.
  Future<int> clear({String? budgetSyncId}) {
    return (_db.update(_db.payeeCategories)
          ..where((p) => p.budgetSyncId.equals(budgetSyncId ?? '') & p.deleted.equals(false)))
        .write(PayeeCategoriesCompanion(deleted: const Value(true), updatedAt: Value(_at)));
  }

  // --- Links to Actual ("Match your categories", Phase 4c) --------------

  /// Local category id → Actual category id, for one budget.
  Future<Map<String, String>> links(String budgetSyncId) async {
    final rows = await (_db.select(_db.categoryLinks)..where((l) => l.budgetSyncId.equals(budgetSyncId))).get();
    return {for (final r in rows) r.categoryId: r.actualCategoryId};
  }

  Future<void> link(String categoryId, String budgetSyncId, String actualCategoryId) => _db
      .into(_db.categoryLinks)
      .insertOnConflictUpdate(
        CategoryLinksCompanion.insert(
          categoryId: categoryId,
          budgetSyncId: budgetSyncId,
          actualCategoryId: actualCategoryId,
        ),
      );

  /// Ids of the categories the memory points to, in this budget's scope or
  /// the unscoped one: the ones worth matching.
  Future<Set<String>> categoriesInUse({String? budgetSyncId}) async {
    final rows =
        await (_db.selectOnly(_db.payeeCategories, distinct: true)
              ..addColumns([_db.payeeCategories.categoryId])
              ..where(
                _db.payeeCategories.deleted.equals(false) &
                    _db.payeeCategories.budgetSyncId.isIn({budgetSyncId ?? '', ''}),
              ))
            .get();
    return {for (final r in rows) r.read(_db.payeeCategories.categoryId)!};
  }

  // --- Managing the categories themselves (Settings → Categories) -------

  /// Every group and category, hidden ones included, in order.
  Future<List<ManagedGroup>> allGroups() async {
    final groups = await (_db.select(
      _db.categoryGroups,
    )..orderBy([(g) => OrderingTerm(expression: g.isIncome), (g) => OrderingTerm(expression: g.sort)])).get();
    final categories = await (_db.select(_db.categories)..orderBy([(c) => OrderingTerm(expression: c.sort)])).get();
    return [
      for (final g in groups)
        (
          id: g.id,
          name: g.name,
          isIncome: g.isIncome,
          hidden: g.hidden,
          isPreset: g.source == 'preset',
          categories: [
            for (final c in categories)
              if (c.groupId == g.id) (id: c.id, name: c.name, hidden: c.hidden, isPreset: c.source == 'preset'),
          ],
        ),
    ];
  }

  Future<void> renameCategory(String id, String name) => (_db.update(
    _db.categories,
  )..where((c) => c.id.equals(id))).write(CategoriesCompanion(name: Value(_checkedName(name)), updatedAt: Value(_at)));

  Future<void> renameGroup(String id, String name) => (_db.update(_db.categoryGroups)..where((g) => g.id.equals(id)))
      .write(CategoryGroupsCompanion(name: Value(_checkedName(name)), updatedAt: Value(_at)));

  /// Hidden categories leave the picker and stop being suggested, but keep
  /// their mappings: nothing is deleted, so showing one again restores all.
  Future<void> setCategoryHidden(String id, bool hidden) => (_db.update(
    _db.categories,
  )..where((c) => c.id.equals(id))).write(CategoriesCompanion(hidden: Value(hidden), updatedAt: Value(_at)));

  /// A user category at the end of [groupId]. Returns its id.
  Future<String> addCategory(String groupId, String name) async {
    final id = 'local:${_uuid()}';
    final sort = await _nextSort(_db.categories, _db.categories.sort, _db.categories.groupId.equals(groupId));
    await _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            groupId: groupId,
            name: _checkedName(name),
            sort: sort,
            source: 'user',
            updatedAt: _at,
          ),
        );
    return id;
  }

  /// A user group, after the other expense groups. Returns its id.
  Future<String> addGroup(String name) async {
    final id = 'local:${_uuid()}';
    final sort = await _nextSort(
      _db.categoryGroups,
      _db.categoryGroups.sort,
      _db.categoryGroups.isIncome.equals(false),
    );
    await _db
        .into(_db.categoryGroups)
        .insert(
          CategoryGroupsCompanion.insert(id: id, name: _checkedName(name), sort: sort, source: 'user', updatedAt: _at),
        );
    return id;
  }

  /// Brings back hidden presets. Names, user categories and mappings are
  /// left as they are. Returns how many came back.
  Future<int> restoreHiddenPresets() async {
    final at = _at;
    final categories =
        await (_db.update(_db.categories)..where((c) => c.source.equals('preset') & c.hidden.equals(true))).write(
          CategoriesCompanion(hidden: const Value(false), updatedAt: Value(at)),
        );
    await (_db.update(_db.categoryGroups)..where((g) => g.source.equals('preset') & g.hidden.equals(true))).write(
      CategoryGroupsCompanion(hidden: const Value(false), updatedAt: Value(at)),
    );
    return categories;
  }

  Future<int> _nextSort(TableInfo table, GeneratedColumn<int> sort, Expression<bool> where) async {
    final max = sort.max();
    final row =
        await (_db.selectOnly(table)
              ..addColumns([max])
              ..where(where))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  static String _checkedName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    return trimmed;
  }

  static final _random = Random.secure();

  /// A random (version 4) UUID.
  static String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// True for an id from this store, as opposed to one of Actual's: presets
  /// are `preset:<key>` (see presetId), user categories (Phase 4b) will be
  /// `local:<uuid>`.
  static bool isLocalId(String id) => id.startsWith('preset:') || id.startsWith('local:');
}
