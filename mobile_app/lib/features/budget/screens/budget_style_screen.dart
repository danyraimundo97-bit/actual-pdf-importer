import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/ledger_builders.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/budget_style_cards.dart';

const _log = AppLog('ledger');

/// Saves the phone's own budget style. Amounts aren't touched: only the totals
/// are worked out differently.
Future<void> setPhoneBudgetStyle(WidgetRef ref, BudgetStyle style) async {
  await ref.read(ledgerStoreProvider).setBudgetMode(phoneScope, style.name);
  ref.invalidate(budgetStyleProvider);
  ref.invalidate(phoneBudgetStyleProvider);
  _log.info('Budget style changed', {'style': style.name});
}

/// Settings › Budget style. The phone's own budget chooses here; a budget from
/// Actual has its mode set in Actual, so this only says which it is.
class BudgetStyleScreen extends ConsumerWidget {
  const BudgetStyleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(budgetStyleProvider).valueOrNull;
    final scope = ref.watch(ledgerScopeProvider).valueOrNull;
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final small = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final name = ref.watch(appConfigProvider).budgetName ?? 'This budget';
    return Scaffold(
      appBar: AppBar(title: const Text('Budget style')),
      body: style == null || scope == null
          ? const SkeletonRows(count: 3)
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
              children: [
                if (scope == phoneScope) ...[
                  const BudgetStyleExample(),
                  const SizedBox(height: Space.lg),
                  BudgetStyleChooser(selected: style, onChanged: (s) => setPhoneBudgetStyle(ref, s)),
                  const SizedBox(height: Space.md),
                  Text(
                    'You can switch any time: your amounts stay as they are and only the totals change. '
                    "With Actual connected, the app follows that budget's own style.",
                    style: small,
                  ),
                ] else ...[
                  Text("$name uses this style. It's set in Actual, so that's where to change it.", style: muted),
                  const SizedBox(height: Space.lg),
                  BudgetStyleCard(style: style, selected: true, detailed: true),
                ],
                const SizedBox(height: Space.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/settings/budget-guide'),
                    child: const Text('How budgeting works'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Settings › Help › How budgeting works: the same example as setup, for later.
class BudgetGuideScreen extends StatelessWidget {
  const BudgetGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('How budgeting works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text(
            'A budget is an amount per category per month. The two styles store the same amounts and differ in '
            'what happens to what\'s left.',
            style: muted,
          ),
          const SizedBox(height: Space.lg),
          const BudgetStyleExample(),
          const SizedBox(height: Space.lg),
          const BudgetStyleCard(style: BudgetStyle.tracking, detailed: true),
          const SizedBox(height: Space.md),
          const BudgetStyleCard(style: BudgetStyle.envelope, detailed: true),
          const SizedBox(height: Space.lg),
          Text(
            'Limits suit you if you want to see whether each month stayed under. Envelopes suit you if you save '
            'up in categories, or plan with the money you already have. Actual calls simple limits "tracking".',
            style: muted,
          ),
        ],
      ),
    );
  }
}
