import '../../core/format/fold.dart';
import '../../data/local/db/local_category_store.dart';
import '../../data/models/actual_category.dart';
import '../../data/models/parsed_transaction.dart';

/// Names compared for matching: case-, accent- and spacing-insensitive. The
/// same rule as the backend's `categoryNameKey` (POST /actual/categories),
/// so a category this matches is one that endpoint would reuse.
String categoryNameKey(String name) => foldAccents(name).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Visible local categories whose name equals exactly one Actual category's
/// (after [categoryNameKey]): local id → Actual id. "Restaurantes" and
/// "Restaurants & cafés" don't match; the user links those by hand.
Map<String, String> autoMatchCategories(List<ManagedGroup> local, List<ActualCategoryGroup> actual) {
  final byKey = <String, List<String>>{};
  for (final g in actual) {
    for (final c in g.categories) {
      byKey.putIfAbsent(categoryNameKey(c.name), () => []).add(c.id);
    }
  }
  return {
    for (final g in local)
      for (final c in g.categories)
        if (!c.hidden && byKey[categoryNameKey(c.name)]?.length == 1) c.id: byKey[categoryNameKey(c.name)]!.single,
  };
}

/// Actual category id → name.
Map<String, String> actualCategoryNames(List<ActualCategoryGroup> groups) => {
  for (final g in groups)
    for (final c in g.categories) c.id: c.name,
};

/// A transaction whose suggestion is one of the app's own categories,
/// turned into the linked Actual category for importing; the suggestion is
/// dropped when that category isn't linked (Actual can't resolve local
/// ids). A user's own pick (override) is handled the same way.
ParsedTransaction toActualCategories(
  ParsedTransaction t, {
  required Map<String, String> links,
  required Map<String, String> actualNames,
}) {
  String? resolve(String? id) {
    if (id == null || !LocalCategoryStore.isLocalId(id)) return id;
    final actualId = links[id];
    return actualId != null && actualNames.containsKey(actualId) ? actualId : null;
  }

  var out = t;
  if (t.suggestedCategoryId != null && LocalCategoryStore.isLocalId(t.suggestedCategoryId!)) {
    final id = resolve(t.suggestedCategoryId);
    out = id == null
        ? out.withoutSuggestion()
        : out.copyWith(suggestedCategoryId: id, suggestedCategoryName: actualNames[id]);
  }
  return out;
}
