import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/budget_month.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "Nov 2026"-style label for `YYYY-MM`.
String monthLabel(String yyyyMm) =>
    '${_months[int.parse(yyyyMm.substring(5, 7)) - 1]} ${yyyyMm.substring(0, 4)}';

/// `YYYY-MM` [delta] months away.
String shiftMonth(String yyyyMm, int delta) {
  final d = DateTime(int.parse(yyyyMm.substring(0, 4)), int.parse(yyyyMm.substring(5, 7)) + delta);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// This month's budget: how much is left in each category. Read-only;
/// budgeting itself still happens in Actual.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  /// Null = the current month (the backend decides which that is).
  String? _month;

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetMonthProvider(_month));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RequiresActual(
          child: budget.when(
            skipLoadingOnRefresh: true,
            loading: () => const _BudgetSkeleton(),
            error: (error, _) => isActualNotConnected(error)
                ? const ConnectActualState(state: LinkState.noActual)
                : ErrorRetry(
                    title: 'Could not load the budget',
                    message: error is ApiException ? error.message : 'Something unexpected went wrong.',
                    onRetry: () => ref.invalidate(budgetMonthProvider(_month)),
                  ),
            data: (data) => RefreshIndicator(
              onRefresh: () => ref.refresh(budgetMonthProvider(_month).future),
              child: _BudgetBody(data: data, onMonth: (m) => setState(() => _month = m)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetBody extends StatelessWidget {
  final BudgetMonth data;
  final ValueChanged<String> onMonth;

  const _BudgetBody({required this.data, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    final canBack = data.month.compareTo(data.firstMonth) > 0;
    final canForward = data.month.compareTo(data.lastMonth) < 0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom: room for the quick-add button.
      padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl * 3),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: canBack ? () => onMonth(shiftMonth(data.month, -1)) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(monthLabel(data.month), textAlign: TextAlign.center, style: context.text.titleLarge),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: canForward ? () => onMonth(shiftMonth(data.month, 1)) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _Summary(data: data),
        ),
        const SizedBox(height: Space.xl),
        if (data.groups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              'No categories with a budget this month.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        for (final group in data.groups) _GroupSection(group: group),
        if (data.income.isNotEmpty) _IncomeSection(income: data.income),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final BudgetMonth data;

  const _Summary({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final toBudget = data.toBudgetCents;
    Widget stat(String label, int cents, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: muted),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatCents(cents), style: figures(context.text.titleMedium).copyWith(color: color)),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          decoration: BoxDecoration(
            color: toBudget < 0 ? colors.errorContainer : colors.primary.withValues(alpha: 0.08),
            borderRadius: Radii.controlAll,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  toBudget < 0 ? 'Overbudgeted' : 'To budget',
                  style: context.text.titleSmall?.copyWith(
                    color: toBudget < 0 ? colors.onErrorContainer : colors.primary,
                  ),
                ),
              ),
              Text(
                formatCents(toBudget),
                style: figures(context.text.titleMedium).copyWith(
                  fontWeight: FontWeight.w600,
                  color: toBudget < 0 ? colors.onErrorContainer : colors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            stat('Budgeted', data.totalBudgetedCents.abs()),
            const SizedBox(width: Space.md),
            stat('Spent', data.totalSpentCents),
            const SizedBox(width: Space.md),
            stat('Left', data.totalBalanceCents, color: data.totalBalanceCents < 0 ? colors.error : null),
          ],
        ),
      ],
    );
  }
}

class _GroupSection extends StatefulWidget {
  final BudgetGroup group;

  const _GroupSection({required this.group});

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.sm),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0 : -0.25,
                  duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 160),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: Space.xs),
                Expanded(child: Text(group.name, style: context.text.titleSmall)),
                Text(
                  formatCents(group.balanceCents),
                  style: figures(context.text.bodyMedium).copyWith(
                    color: group.balanceCents < 0 ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(children: [for (final c in group.categories) _CategoryRow(category: c)])
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final BudgetCategory category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final over = category.overspent;
    final barColor = over ? colors.error : (category.usedFraction > 0.9 ? colors.tertiary : colors.primary);
    return Semantics(
      label: '${category.name}: ${formatCents(category.balanceCents)} left'
          '${over ? ', overspent' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xl, Space.sm, Space.gutter, Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyLarge),
                ),
                const SizedBox(width: Space.md),
                Text(
                  formatCents(category.balanceCents),
                  style: figures(context.text.bodyLarge).copyWith(
                    fontWeight: FontWeight.w500,
                    color: over ? colors.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: category.usedFraction,
                minHeight: 4,
                color: barColor,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              over
                  ? 'Overspent: spent ${formatCents(category.spentCents)} of ${formatCents(category.budgetedCents)}'
                  : 'Spent ${formatCents(category.spentCents)} of ${formatCents(category.budgetedCents)}'
                      '${category.carryover ? ' · rolls over' : ''}',
              style: context.text.bodySmall?.copyWith(color: over ? colors.error : colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeSection extends StatelessWidget {
  final List<({String id, String name, int receivedCents})> income;

  const _IncomeSection({required this.income});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Income', style: context.text.titleSmall),
          const SizedBox(height: Space.sm),
          for (final i in income)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
              child: Row(
                children: [
                  Expanded(child: Text(i.name, style: context.text.bodyLarge)),
                  Text(
                    formatCents(i.receivedCents),
                    style: figures(context.text.bodyLarge).copyWith(color: context.tokens.inflow),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetSkeleton extends StatelessWidget {
  const _BudgetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading budget',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
        children: const [
          Center(child: Skeleton(width: 160, height: 20)),
          SizedBox(height: Space.xl),
          Skeleton(height: 44, radius: Radii.control),
          SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(child: Skeleton(height: 34, radius: 8)),
              SizedBox(width: Space.md),
              Expanded(child: Skeleton(height: 34, radius: 8)),
              SizedBox(width: Space.md),
              Expanded(child: Skeleton(height: 34, radius: 8)),
            ],
          ),
          SizedBox(height: Space.xl),
          SkeletonRows(count: 6, padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}
