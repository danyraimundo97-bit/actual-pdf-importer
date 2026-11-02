import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';
import '../match_categories.dart';

/// How many of the app's categories still need matching to the chosen
/// budget's Actual categories; 0 when Actual isn't connected. Drives the
/// "Match your categories" prompt on the Import tab.
final pendingCategoryMatchesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(categoryMemoryRevisionProvider);
  final budgetSyncId = ref.watch(appConfigProvider).budgetSyncId;
  if (budgetSyncId == null || await ref.watch(linkStateProvider.future) != LinkState.ready) return 0;
  final store = ref.watch(localCategoryStoreProvider);
  return pendingCategoryMatches(
    local: await store.allGroups(),
    links: await store.links(budgetSyncId),
    inUse: await store.categoriesInUse(budgetSyncId: budgetSyncId),
    skipped: ref.watch(settingsStoreProvider).skippedCategoryMatches(budgetSyncId),
  );
});

/// "Match your categories": links the app's own categories to the chosen
/// budget's Actual categories, so what the phone learned before Actual was
/// connected keeps working when importing into it.
class MatchCategoriesScreen extends ConsumerStatefulWidget {
  const MatchCategoriesScreen({super.key});

  @override
  ConsumerState<MatchCategoriesScreen> createState() => _MatchCategoriesScreenState();
}

class _MatchCategoriesScreenState extends ConsumerState<MatchCategoriesScreen> {
  MatchPlan? _plan;
  List<ActualCategoryGroup> _actual = [];
  String? _error;
  bool _saving = false;

  String? get _budgetSyncId => ref.read(appConfigProvider).budgetSyncId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final budgetSyncId = _budgetSyncId;
    setState(() {
      _error = null;
      _plan = null;
    });
    if (budgetSyncId == null) {
      setState(() => _error = 'Choose a budget first, in Settings.');
      return;
    }
    try {
      final store = ref.read(localCategoryStoreProvider);
      final actual = await ref.read(importerApiProvider).getActualCategories(budgetSyncId: budgetSyncId);
      final plan = planCategoryMatch(
        local: await store.allGroups(),
        actual: actual,
        links: await store.links(budgetSyncId),
        inUse: await store.categoriesInUse(budgetSyncId: budgetSyncId),
        skipped: ref.read(settingsStoreProvider).skippedCategoryMatches(budgetSyncId),
      );
      if (!mounted) return;
      setState(() {
        _actual = actual;
        _plan = plan;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _choose(int index, MatchChoice choice) {
    final plan = _plan!;
    final rows = [...plan.rows]..[index] = plan.rows[index].withChoice(choice);
    setState(() => _plan = MatchPlan(automatic: plan.automatic, rows: rows, alreadyLinked: plan.alreadyLinked));
  }

  Future<void> _pickActual(int index) async {
    final picked = await pickCategory(context, _actual);
    if (picked != null) _choose(index, LinkToActual(picked.id, picked.name));
  }

  Future<void> _save() async {
    final plan = _plan;
    final budgetSyncId = _budgetSyncId;
    if (plan == null || budgetSyncId == null) return;
    setState(() => _saving = true);
    try {
      final result = await applyCategoryMatch(
        plan,
        budgetSyncId: budgetSyncId,
        store: ref.read(localCategoryStoreProvider),
        api: ref.read(importerApiProvider),
        settings: ref.read(settingsStoreProvider),
      );
      ref.read(categoryMemoryRevisionProvider.notifier).state++;
      if (!mounted) return;
      final done = result.linked + result.created;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            done == 0
                ? 'Nothing linked.'
                : 'Linked $done ${done == 1 ? 'category' : 'categories'}'
                      '${result.created == 0 ? '' : ', ${result.created} created in Actual'}.',
          ),
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      // Links saved before the failure stay; reload so the list shows what's left.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final Widget body;
    if (_error != null) {
      body = ErrorRetry(title: 'Could not load the categories', message: _error!, onRetry: _load);
    } else if (plan == null) {
      body = const SkeletonRows(count: 6);
    } else if (plan.isEmpty) {
      body = EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing to match',
        message: plan.alreadyLinked == 0
            ? 'None of the categories the app remembered payees for needs an Actual category.'
            : 'Every category the app uses is linked to one in Actual.',
        actionLabel: 'Done',
        onAction: () => context.pop(),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.lg),
            child: Text(
              'The app remembered payees with its own categories. Link each one to a category in '
              'your Actual budget, so those payees get it when you import.',
              style: muted,
            ),
          ),
          if (plan.automatic.isNotEmpty)
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined, color: context.colors.primary),
              title: Text('${plan.automatic.length} matched by name', style: context.text.titleSmall),
              subtitle: const Text('Same name in Actual; linked when you save.'),
            ),
          for (final (i, row) in plan.rows.indexed)
            _MatchTile(
              row: row,
              onPick: () => _pickActual(i),
              onCreate: () => _choose(i, const CreateInActual()),
              onSkip: () => _choose(i, const SkipMatch()),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Match your categories')),
      body: body,
      bottomNavigationBar: plan == null || plan.isEmpty || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
                child: BusyButton(label: 'Save', busy: _saving, onPressed: _save),
              ),
            ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final MatchRow row;
  final VoidCallback onPick;
  final VoidCallback onCreate;
  final VoidCallback onSkip;

  const _MatchTile({required this.row, required this.onPick, required this.onCreate, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon) = switch (row.choice) {
      CreateInActual() => ('Create "${row.category.name}" in Actual', Icons.add_circle_outline_rounded),
      LinkToActual(:final actualName) => ('Link to $actualName', Icons.link_rounded),
      SkipMatch() => ('Skip: leave uncategorised in Actual', Icons.do_not_disturb_on_outlined),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.sm, Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.category.name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                Text(row.group.name, style: context.text.bodySmall),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Icon(icon, size: 16, color: context.colors.primary),
                    const SizedBox(width: Space.xs),
                    Flexible(child: Text(label, style: context.text.bodySmall)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'Change for ${row.category.name}',
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(value: onPick, child: const Text('Pick an Actual category')),
              PopupMenuItem(value: onCreate, child: const Text('Create it in Actual')),
              PopupMenuItem(value: onSkip, child: const Text('Skip')),
            ],
          ),
        ],
      ),
    );
  }
}
