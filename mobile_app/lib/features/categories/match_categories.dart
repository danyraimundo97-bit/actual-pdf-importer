import '../../core/log/app_log.dart';
import '../../data/api/importer_api.dart';
import '../../data/local/db/local_category_store.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/actual_category.dart';
import 'category_matching.dart';

const _log = AppLog('categories');

/// What to do with one local category ("Match your categories").
sealed class MatchChoice {
  const MatchChoice();
}

/// Create a category with the same name (and group) in Actual, then link it.
class CreateInActual extends MatchChoice {
  const CreateInActual();
}

/// Link to an existing Actual category.
class LinkToActual extends MatchChoice {
  final String actualId;
  final String actualName;
  const LinkToActual(this.actualId, this.actualName);
}

/// Leave unlinked; don't ask again for this budget.
class SkipMatch extends MatchChoice {
  const SkipMatch();
}

class MatchRow {
  final ManagedGroup group;
  final ManagedCategory category;
  final MatchChoice choice;

  const MatchRow({required this.group, required this.category, required this.choice});

  MatchRow withChoice(MatchChoice choice) => MatchRow(group: group, category: category, choice: choice);
}

class MatchPlan {
  /// Matched by name, linked without asking: local id → Actual id.
  final Map<String, String> automatic;

  /// Local categories in use that need the user's choice.
  final List<MatchRow> rows;

  /// How many local categories are already linked to this budget.
  final int alreadyLinked;

  const MatchPlan({required this.automatic, required this.rows, required this.alreadyLinked});

  bool get isEmpty => automatic.isEmpty && rows.isEmpty;
}

/// Works out what to link. Every visible category whose name matches an
/// Actual one exactly is linked automatically (unused presets included:
/// hints point at presets). Of the rest, only categories the memory uses
/// are asked about, so an unused preset never gets created in Actual. A
/// category skipped before starts as skipped.
MatchPlan planCategoryMatch({
  required List<ManagedGroup> local,
  required List<ActualCategoryGroup> actual,
  required Map<String, String> links,
  required Set<String> inUse,
  required Set<String> skipped,
}) {
  final automatic = {
    for (final e in autoMatchCategories(local, actual).entries)
      if (!links.containsKey(e.key)) e.key: e.value,
  };
  return MatchPlan(
    automatic: automatic,
    alreadyLinked: links.length,
    rows: [
      for (final g in local)
        for (final c in g.categories)
          if (!c.hidden && inUse.contains(c.id) && !links.containsKey(c.id) && !automatic.containsKey(c.id))
            MatchRow(
              group: g,
              category: c,
              choice: skipped.contains(c.id) ? const SkipMatch() : const CreateInActual(),
            ),
    ],
  );
}

/// Local categories still waiting for a choice: in use, visible, not linked,
/// not skipped. Drives the "Match your categories" prompt.
int pendingCategoryMatches({
  required List<ManagedGroup> local,
  required Map<String, String> links,
  required Set<String> inUse,
  required Set<String> skipped,
}) => [
  for (final g in local)
    for (final c in g.categories)
      if (!c.hidden && inUse.contains(c.id) && !links.containsKey(c.id) && !skipped.contains(c.id)) c,
].length;

/// Saves a plan: automatic links, the user's choices, and the skipped set.
/// Links are written one by one as they succeed, so a failure half-way (the
/// backend going away while creating categories) keeps what was done; the
/// next run only asks about the rest.
Future<({int linked, int created, int skipped})> applyCategoryMatch(
  MatchPlan plan, {
  required String budgetSyncId,
  required LocalCategoryStore store,
  required ImporterApi api,
  required SettingsStore settings,
}) async {
  var linked = 0, created = 0;
  for (final e in plan.automatic.entries) {
    await store.link(e.key, budgetSyncId, e.value);
    linked++;
  }
  final skipped = settings.skippedCategoryMatches(budgetSyncId);
  for (final row in plan.rows) {
    switch (row.choice) {
      case LinkToActual(:final actualId):
        await store.link(row.category.id, budgetSyncId, actualId);
        skipped.remove(row.category.id);
        linked++;
      case CreateInActual():
        final id = await api.ensureActualCategory(
          budgetSyncId: budgetSyncId,
          groupName: row.group.name,
          name: row.category.name,
          isIncome: row.group.isIncome,
        );
        await store.link(row.category.id, budgetSyncId, id);
        skipped.remove(row.category.id);
        created++;
      case SkipMatch():
        skipped.add(row.category.id);
    }
  }
  await settings.setSkippedCategoryMatches(budgetSyncId, skipped);
  final count = plan.rows.where((r) => r.choice is SkipMatch).length;
  _log.info('Categories matched with Actual', {'linked': linked, 'created': created, 'skipped': count});
  return (linked: linked, created: created, skipped: count);
}
