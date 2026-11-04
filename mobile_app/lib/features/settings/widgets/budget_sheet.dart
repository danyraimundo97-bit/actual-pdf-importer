import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_budget.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/inline_note.dart';
import '../connection_controller.dart';
import 'connection_widgets.dart';

/// The budgets on the Actual server in a bottom sheet, loaded when it opens.
/// Returns the chosen budget's name, or null when nothing changed.
Future<String?> showBudgetSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.sheet(context),
    builder: (_) => const _BudgetSheet(),
  );
}

class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet();

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    if (!mounted || !ref.read(connectionControllerProvider).actualConfigured) return;
    await ref.read(connectionControllerProvider.notifier).loadBudgets();
  }

  Future<void> _select(ActualBudget budget) async {
    if (budget.syncId == ref.read(appConfigProvider).budgetSyncId) {
      Navigator.pop(context);
      return;
    }
    final chosen = await chooseBudget(context, ref, budget);
    if (chosen && mounted) Navigator.pop(context, budget.name);
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(connectionControllerProvider);
    final selected = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
    final host = Uri.tryParse(check.actual?.serverUrl ?? '')?.host;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Budget', style: context.text.titleLarge)),
                IconButton(
                  tooltip: 'Reload budgets',
                  onPressed: check.loadingBudgets ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              host == null || host.isEmpty
                  ? 'Imports and category memory follow the budget you pick.'
                  : 'Budgets on $host. Imports and category memory follow the one you pick.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: Space.lg),
            if (check.budgetsError != null)
              InlineNote(message: check.budgetsError!, tone: NoteTone.error)
            else if (!check.loadingBudgets && check.budgets.isEmpty)
              const InlineNote(message: noBudgetsMessage)
            else
              BudgetList(
                budgets: check.budgets,
                loading: check.loadingBudgets,
                selectedSyncId: selected,
                onSelect: _select,
              ),
          ],
        ),
      ),
    );
  }
}
