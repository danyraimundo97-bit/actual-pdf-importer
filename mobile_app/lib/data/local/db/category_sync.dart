import 'package:drift/drift.dart';

import '../../api/categories_api.dart';
import '../../api/importer_api.dart';
import '../../category_suggestions.dart';
import '../../models/actual_category.dart';
import '../settings_store.dart';
import 'app_category_rows.dart';
import 'app_database.dart';

typedef CategorySyncResult = ({int sent, int received});

/// Two-way sync of the phone's categories and category memory with the
/// backend (docs/plans/dart-parser.md, Phase 4d; `POST /categories/sync`).
///
/// - The app's own groups, categories and links travel whole (opaque to the
///   backend), so backups and a new phone get them back. Copies of Actual
///   categories don't: they're rebuilt from Actual.
/// - Mappings travel only with Actual connected and a budget chosen, and
///   with Actual's ids: a mapping to a local category goes up through its
///   link; one to an unlinked category waits until it's linked. A mapping
///   that comes down for an Actual category no local one is linked to gets
///   a local copy of that category (`actual:<id>`), so the phone can show
///   and suggest it offline.
/// - Newest `updatedAt` wins, per row, on both sides; tombstones carry
///   forgetting. Nothing is replaced wholesale, so a first sync on a phone
///   with offline edits merges them.
class CategorySync {
  CategorySync(this._db, this._api, this._importer, this._settings, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final CategoriesApi _api;
  final ImporterApi _importer;
  final SettingsStore _settings;
  final DateTime Function() _now;

  /// [budgetSyncId] with [actualReady] syncs that budget's mappings too.
  Future<CategorySyncResult> run({String? budgetSyncId, required bool actualReady}) async {
    final mappingsBudget = actualReady ? budgetSyncId : null;
    final key = mappingsBudget ?? '';
    final since = _settings.categorySyncCursor(key);
    // A first sync (no cursor) sends everything.
    final watermark = since == null ? -1 : (_settings.categorySyncWatermark(key) ?? -1);
    final startedAt = _now().millisecondsSinceEpoch;
    final actual = _ActualCategories(_importer, mappingsBudget);

    final appOut = await _appChanges(watermark);
    final mappingsOut = mappingsBudget == null
        ? const <Map<String, Object?>>[]
        : await _mappingChanges(mappingsBudget, watermark, actual);
    final response = await _api.sync(
      budgetSyncId: mappingsBudget,
      since: since,
      mappings: mappingsOut,
      appCategories: appOut,
    );
    var received = await _applyAppCategories(response.appCategories);
    if (mappingsBudget != null) received += await _applyMappings(mappingsBudget, response.mappings, actual);
    await _settings.setCategorySync(key, cursor: response.now, watermark: startedAt);
    return (sent: appOut.length + mappingsOut.length, received: received);
  }

  // --- Out --------------------------------------------------------------

  Future<List<Map<String, Object?>>> _appChanges(int watermark) => appCategoryRows(_db, watermark: watermark);

  /// The budget's mappings and the unscoped ones (learned before a budget
  /// was chosen), changed since [watermark] or whose link is newer, as
  /// Actual ids, in the budget's scope. One per payee: the newer wins.
  Future<List<Map<String, Object?>>> _mappingChanges(String budget, int watermark, _ActualCategories actual) async {
    final links = {
      for (final l in await (_db.select(_db.categoryLinks)..where((l) => l.budgetSyncId.equals(budget))).get())
        l.categoryId: l,
    };
    if (links.isEmpty) return const [];
    final rows = await (_db.select(_db.payeeCategories)..where((p) => p.budgetSyncId.isIn([budget, '']))).get();
    final newest = <String, PayeeCategory>{};
    for (final row in rows) {
      final link = links[row.categoryId];
      if (link == null) continue; // unlinked: held back until it's matched
      if (row.updatedAt <= watermark && link.updatedAt <= watermark) continue;
      final seen = newest[row.payeeKey];
      if (seen == null || row.updatedAt > seen.updatedAt) newest[row.payeeKey] = row;
    }
    if (newest.isEmpty) return const [];
    final names = await actual.names();
    return [
      for (final row in newest.values)
        {
          'payee': row.payeeLabel,
          'categoryId': links[row.categoryId]!.actualCategoryId,
          'categoryName': names[links[row.categoryId]!.actualCategoryId],
          'updatedAt': row.updatedAt,
          'deleted': row.deleted,
        },
    ];
  }

  // --- In ---------------------------------------------------------------

  Future<int> _applyAppCategories(List<Map<String, dynamic>> rows) => applyAppCategoryRows(_db, rows);

  Future<int> _applyMappings(String budget, List<Map<String, dynamic>> rows, _ActualCategories actual) async {
    if (rows.isEmpty) return 0;
    // Actual id → the phone's category for it: a linked local one first,
    // then an existing copy.
    final reverse = <String, String>{};
    for (final l in await (_db.select(_db.categoryLinks)..where((l) => l.budgetSyncId.equals(budget))).get()) {
      final current = reverse[l.actualCategoryId];
      if (current == null || current.startsWith('actual:')) reverse[l.actualCategoryId] = l.categoryId;
    }
    var applied = 0;
    for (final row in rows) {
      final payee = row['payee'] as String;
      final key = categoryMemoryKey(payee);
      final updatedAt = row['updatedAt'] as int;
      final deleted = row['deleted'] as bool;
      final current = await (_db.select(
        _db.payeeCategories,
      )..where((p) => p.budgetSyncId.equals(budget) & p.payeeKey.equals(key))).getSingleOrNull();
      if (current != null && current.updatedAt >= updatedAt) continue;

      final actualId = row['categoryId'] as String;
      final localId = reverse[actualId] ?? await _copyOfActual(budget, actualId, actual);
      if (localId != null) reverse[actualId] = localId;
      final categoryId = localId ?? (deleted ? current?.categoryId : null);
      if (categoryId == null) continue; // an Actual category that no longer exists

      await _db
          .into(_db.payeeCategories)
          .insertOnConflictUpdate(
            PayeeCategoriesCompanion.insert(
              budgetSyncId: budget,
              payeeKey: key,
              payeeLabel: payee.trim(),
              categoryId: categoryId,
              updatedAt: updatedAt,
              deleted: Value(deleted),
            ),
          );
      applied++;
    }
    return applied;
  }

  /// The phone's copy of an Actual category (and its group), linked to it in
  /// [budget]. Null when Actual doesn't have that category (any more).
  Future<String?> _copyOfActual(String budget, String actualId, _ActualCategories actual) async {
    final groups = await actual.groups();
    for (final (gi, g) in groups.indexed) {
      for (final (ci, c) in g.categories.indexed) {
        if (c.id != actualId) continue;
        final groupId = 'actual:${g.id}';
        final categoryId = 'actual:${c.id}';
        await _db
            .into(_db.categoryGroups)
            .insertOnConflictUpdate(
              CategoryGroupsCompanion.insert(
                id: groupId,
                name: g.name,
                sort: 1000 + gi,
                source: 'actual',
                updatedAt: 0,
              ),
            );
        await _db
            .into(_db.categories)
            .insertOnConflictUpdate(
              CategoriesCompanion.insert(
                id: categoryId,
                groupId: groupId,
                name: c.name,
                sort: ci,
                source: 'actual',
                updatedAt: 0,
              ),
            );
        await _db
            .into(_db.categoryLinks)
            .insertOnConflictUpdate(
              CategoryLinksCompanion.insert(categoryId: categoryId, budgetSyncId: budget, actualCategoryId: c.id),
            );
        return categoryId;
      }
    }
    return null;
  }
}

/// Actual's categories for one budget, fetched at most once per sync and
/// only when needed. Empty when there's no budget or the call fails: names
/// are then left out and no copies are made.
class _ActualCategories {
  _ActualCategories(this._importer, this._budget);

  final ImporterApi _importer;
  final String? _budget;
  Future<List<ActualCategoryGroup>>? _groups;

  Future<List<ActualCategoryGroup>> groups() => _groups ??= _load();

  Future<Map<String, String>> names() async => {
    for (final g in await groups())
      for (final c in g.categories) c.id: c.name,
  };

  Future<List<ActualCategoryGroup>> _load() async {
    final budget = _budget;
    if (budget == null) return const [];
    try {
      return await _importer.getActualCategories(budgetSyncId: budget);
    } catch (_) {
      return const [];
    }
  }
}
