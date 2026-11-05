import 'package:drift/drift.dart';

import 'app_database.dart';

// The app's own groups, categories and links as the backend stores them
// (`app_categories`: kind, id, opaque data, updatedAt). Shared by the sync
// (category_sync.dart) and app-data files (app_data_file.dart).

/// The phone's groups, categories and links changed after [watermark]
/// (-1 = all). Copies of Actual categories are left out: they're rebuilt
/// from Actual.
Future<List<Map<String, Object?>>> appCategoryRows(AppDatabase db, {int watermark = -1}) async {
  final groups = await (db.select(
    db.categoryGroups,
  )..where((g) => g.updatedAt.isBiggerThanValue(watermark) & g.source.isNotValue('actual'))).get();
  final categories = await (db.select(
    db.categories,
  )..where((c) => c.updatedAt.isBiggerThanValue(watermark) & c.source.isNotValue('actual'))).get();
  final links = await (db.select(
    db.categoryLinks,
  )..where((l) => l.updatedAt.isBiggerThanValue(watermark) & l.categoryId.like('actual:%').not())).get();
  return [
    for (final g in groups)
      {
        'kind': 'group',
        'id': g.id,
        'updatedAt': g.updatedAt,
        'data': {
          'name': g.name,
          'sort': g.sort,
          'isIncome': g.isIncome,
          'source': g.source,
          'presetKey': g.presetKey,
          'hidden': g.hidden,
        },
      },
    for (final c in categories)
      {
        'kind': 'category',
        'id': c.id,
        'updatedAt': c.updatedAt,
        'data': {
          'groupId': c.groupId,
          'name': c.name,
          'sort': c.sort,
          'source': c.source,
          'presetKey': c.presetKey,
          'hidden': c.hidden,
          'emoji': c.emoji,
        },
      },
    for (final l in links)
      {
        'kind': 'link',
        'id': '${l.categoryId}|${l.budgetSyncId}',
        'updatedAt': l.updatedAt,
        'data': {'categoryId': l.categoryId, 'budgetSyncId': l.budgetSyncId, 'actualCategoryId': l.actualCategoryId},
      },
  ];
}

/// Writes rows where they're newer than the phone's (newest `updatedAt`
/// wins). Groups first, then categories, then links (each needs the one
/// before). Returns how many were written.
Future<int> applyAppCategoryRows(AppDatabase db, List<Map<String, dynamic>> rows) async {
  const order = {'group': 0, 'category': 1, 'link': 2};
  final sorted = [...rows]..sort((a, b) => (order[a['kind']] ?? 9).compareTo(order[b['kind']] ?? 9));
  var applied = 0;
  await db.transaction(() async {
    for (final row in sorted) {
      if (await _applyAppCategory(db, row)) applied++;
    }
  });
  return applied;
}

Future<bool> _applyAppCategory(AppDatabase db, Map<String, dynamic> row) async {
  final id = row['id'] as String;
  final updatedAt = row['updatedAt'] as int;
  final data = (row['data'] as Map).cast<String, dynamic>();
  switch (row['kind']) {
    case 'group':
      final current = await (db.select(db.categoryGroups)..where((g) => g.id.equals(id))).getSingleOrNull();
      if (current != null && current.updatedAt >= updatedAt) return false;
      await db
          .into(db.categoryGroups)
          .insertOnConflictUpdate(
            CategoryGroupsCompanion.insert(
              id: id,
              name: data['name'] as String,
              sort: data['sort'] as int,
              isIncome: Value(data['isIncome'] as bool? ?? false),
              source: data['source'] as String,
              presetKey: Value(data['presetKey'] as String?),
              hidden: Value(data['hidden'] as bool? ?? false),
              updatedAt: updatedAt,
            ),
          );
      return true;
    case 'category':
      final groupId = data['groupId'] as String;
      final group = await (db.select(db.categoryGroups)..where((g) => g.id.equals(groupId))).getSingleOrNull();
      if (group == null) return false;
      final current = await (db.select(db.categories)..where((c) => c.id.equals(id))).getSingleOrNull();
      if (current != null && current.updatedAt >= updatedAt) return false;
      await db
          .into(db.categories)
          .insertOnConflictUpdate(
            CategoriesCompanion.insert(
              id: id,
              groupId: groupId,
              name: data['name'] as String,
              sort: data['sort'] as int,
              source: data['source'] as String,
              presetKey: Value(data['presetKey'] as String?),
              hidden: Value(data['hidden'] as bool? ?? false),
              emoji: Value(data['emoji'] as String?),
              updatedAt: updatedAt,
            ),
          );
      return true;
    case 'link':
      final categoryId = data['categoryId'] as String;
      final budget = data['budgetSyncId'] as String;
      final category = await (db.select(db.categories)..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (category == null) return false;
      final current = await (db.select(
        db.categoryLinks,
      )..where((l) => l.categoryId.equals(categoryId) & l.budgetSyncId.equals(budget))).getSingleOrNull();
      if (current != null && current.updatedAt >= updatedAt) return false;
      await db
          .into(db.categoryLinks)
          .insertOnConflictUpdate(
            CategoryLinksCompanion.insert(
              categoryId: categoryId,
              budgetSyncId: budget,
              actualCategoryId: data['actualCategoryId'] as String,
              updatedAt: Value(updatedAt),
            ),
          );
      return true;
  }
  return false;
}
