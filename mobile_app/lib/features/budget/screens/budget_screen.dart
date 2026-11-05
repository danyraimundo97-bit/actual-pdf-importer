import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/log/app_log.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/budget_month.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../shared/widgets/ledger_status.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/budget_amount_sheet.dart';

const _log = AppLog('budget');

/// `YYYY-MM` [delta] months away.
String shiftMonth(String yyyyMm, int delta) {
  final d = DateTime(int.parse(yyyyMm.substring(0, 4)), int.parse(yyyyMm.substring(5, 7)) + delta);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// This month's budget: how much is left in each category. With Actual
/// it's read-only (budgeting happens there); without, it's the phone's own
/// budget and tapping a category sets its amount
/// (docs/plans/local-ledger.md, Phase 4).
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  /// Null = the current month.
  String? _month;

  /// The month on screen stays there while the next one is read, so changing
  /// month never flashes the skeleton.
  BudgetMonth? _shown;

  /// Which way the last month change went: 1 forward, -1 back.
  int _direction = 1;

  /// Groups folded away; kept per screen, so they stay folded across months.
  final Set<String> _collapsed = {};

  void _goTo(String month, String from) => setState(() {
    _direction = month.compareTo(from) >= 0 ? 1 : -1;
    _month = month;
  });

  void _toggle(String groupId) => setState(() {
    if (!_collapsed.remove(groupId)) _collapsed.add(groupId);
  });

  Future<void> _edit(String month, BudgetCategory category) async {
    final cents = await showBudgetAmountSheet(
      context,
      categoryName: category.name,
      monthName: monthLabel(month),
      currentCents: category.budgetedCents,
    );
    if (cents == null || cents == category.budgetedCents) return;
    await ref.read(ledgerStoreProvider).setBudget(phoneScope, category.id, month, cents);
    _log.info('Budget amount set', {'category': category.id, 'month': month});
  }

  Future<void> _copyLastMonth(String month) async {
    final copied = await ref.read(ledgerStoreProvider).copyPreviousMonth(phoneScope, month);
    _log.info("Last month's budget copied", {'month': month, 'categories': copied});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied == 0
              ? '${monthLabel(shiftMonth(month, -1))} had nothing budgeted.'
              : 'Copied $copied amount${copied == 1 ? '' : 's'} from ${monthLabel(shiftMonth(month, -1))}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetMonthProvider(_month));
    final onPhone = ref.watch(readsLedgerProvider).valueOrNull ?? false;
    _shown = budget.valueOrNull ?? _shown;
    final data = _shown;

    final Widget body;
    if (budget.hasError && !budget.hasValue) {
      final error = budget.error;
      body = isActualNotConnected(error)
          ? const ConnectActualState(state: LinkState.noActual)
          : ErrorRetry(
              title: 'Could not load the budget',
              message: error is ApiException ? error.message : 'Something unexpected went wrong.',
              onRetry: () => ref.invalidate(budgetMonthProvider(_month)),
            );
    } else if (data == null) {
      body = const _BudgetSkeleton();
    } else {
      body = Column(
        children: [
          _MonthSwitcher(data: data, onMonth: (m) => _goTo(m, data.month)),
          Expanded(
            child: _MonthTransition(
              month: data.month,
              direction: _direction,
              child: RefreshIndicator(
                key: ValueKey(data.month),
                onRefresh: () async {
                  await ref.read(ledgerSyncProvider.notifier).syncNow();
                  return ref.refresh(budgetMonthProvider(_month).future);
                },
                child: _BudgetBody(
                  data: data,
                  onPhone: onPhone,
                  collapsed: _collapsed,
                  onToggle: _toggle,
                  onEdit: onPhone ? (c) => _edit(data.month, c) : null,
                  onCopyLastMonth: onPhone ? () => _copyLastMonth(data.month) : null,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(body: SafeArea(bottom: false, child: body));
  }
}

class _MonthSwitcher extends StatelessWidget {
  final BudgetMonth data;
  final ValueChanged<String> onMonth;

  const _MonthSwitcher({required this.data, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    final canBack = data.month.compareTo(data.firstMonth) > 0;
    final canForward = data.month.compareTo(data.lastMonth) < 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.xs),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: canBack ? () => onMonth(shiftMonth(data.month, -1)) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(monthLabel(data.month), textAlign: TextAlign.center, style: context.text.titleMedium),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: canForward ? () => onMonth(shiftMonth(data.month, 1)) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// The new month slides in a little from the side you moved toward while the
/// old one fades, so you keep your place. A fade only under reduced motion.
class _MonthTransition extends StatelessWidget {
  final String month;
  final int direction;
  final Widget child;

  const _MonthTransition({required this.month, required this.direction, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Motion.small,
      switchInCurve: Motion.easeOut,
      switchOutCurve: Motion.easeOut,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(month);
        if (!incoming || reduceMotion) return FadeTransition(opacity: animation, child: child);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: Offset(0.06 * direction, 0), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _BudgetBody extends StatelessWidget {
  final BudgetMonth data;

  /// Set for the phone's own budget: amounts can be changed here.
  final ValueChanged<BudgetCategory>? onEdit;
  final VoidCallback? onCopyLastMonth;

  /// The phone's own budget (else a copy of the Actual one).
  final bool onPhone;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;

  const _BudgetBody({
    required this.data,
    this.onPhone = false,
    required this.collapsed,
    required this.onToggle,
    this.onEdit,
    this.onCopyLastMonth,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom: room for the quick-add button.
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl * 3),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _Summary(data: data),
        ),
        const SizedBox(height: Space.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              Expanded(child: LedgerStatus(onPhone: onPhone)),
              if (onCopyLastMonth != null && data.totalBudgetedCents == 0 && data.month.compareTo(data.firstMonth) > 0)
                TextButton.icon(
                  onPressed: onCopyLastMonth,
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy last month'),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        if (data.groups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              'No categories with a budget this month.',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        for (final group in data.groups)
          _GroupSection(
            group: group,
            open: !collapsed.contains(group.id),
            onToggle: () => onToggle(group.id),
            onEdit: onEdit,
          ),
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
            child: Text(formatBalance(cents), style: figures(context.text.titleMedium).copyWith(color: color)),
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
                formatBalance(toBudget),
                style: figures(
                  context.text.titleMedium,
                ).copyWith(fontWeight: FontWeight.w600, color: toBudget < 0 ? colors.onErrorContainer : colors.primary),
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

/// What's been used of what was available, 0..1.
double _usedOf(int spentCents, int balanceCents) {
  final spent = -spentCents;
  final available = spent + balanceCents;
  if (spent <= 0) return 0;
  if (available <= 0) return 1;
  return (spent / available).clamp(0, 1).toDouble();
}

class _GroupSection extends StatelessWidget {
  final BudgetGroup group;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<BudgetCategory>? onEdit;

  const _GroupSection({required this.group, required this.open, required this.onToggle, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xs),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: open ? 0 : -0.25,
                  duration: Motion.of(context, Motion.small),
                  curve: Motion.easeOut,
                  child: Icon(Icons.expand_more_rounded, size: 20, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: Space.xs),
                Expanded(child: Text(group.name, style: context.text.titleSmall)),
                Text(
                  formatBalance(group.balanceCents),
                  style: figures(context.text.bodyMedium)
                      .copyWith(color: group.balanceCents < 0 ? colors.error : colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Motion.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Column(
                  children: [
                    for (final c in group.categories)
                      _CategoryRow(category: c, onTap: onEdit == null ? null : () => onEdit!(c)),
                  ],
                )
              // Folded: one bar for the whole group, so it still reads.
              : Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xl, Space.xs, Space.gutter, Space.sm),
                  child: _Bar(
                    value: _usedOf(group.spentCents, group.balanceCents),
                    over: group.balanceCents < 0,
                    height: 3,
                  ),
                ),
        ),
        const SizedBox(height: Space.xs),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final bool over;
  final double height;

  const _Bar({required this.value, required this.over, this.height = 4});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: over ? colors.error : (value > 0.9 ? colors.tertiary : colors.primary),
        backgroundColor: colors.surfaceContainerHighest,
      ),
    );
  }
}

/// A category: what's left is what you came for, so it leads. Under the bar,
/// spent and budgeted in small figures; a sentence only when overspent. On
/// the phone's own budget the budgeted amount is a chip: the row sets it.
class _CategoryRow extends StatelessWidget {
  final BudgetCategory category;

  /// Null when the amounts are Actual's (read-only here).
  final VoidCallback? onTap;

  const _CategoryRow({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final over = category.overspent;
    final spent = formatBalance(-category.spentCents);
    if (category.budgetedCents == 0 && category.spentCents == 0 && category.balanceCents == 0) {
      return _UnusedCategoryRow(name: category.name, onTap: onTap);
    }
    final note = context.text.bodySmall?.copyWith(color: over ? colors.error : colors.onSurfaceVariant);
    return Semantics(
      label:
          '${category.name}: ${formatBalance(category.balanceCents)} left'
          '${over ? ', overspent' : ''}, spent $spent of ${formatBalance(category.budgetedCents)}',
      button: onTap != null,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xl, Space.sm, Space.gutter, Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Text(
                    formatBalance(category.balanceCents),
                    style: figures(context.text.bodyLarge)
                        .copyWith(fontWeight: FontWeight.w500, color: over ? colors.error : null),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs + 2),
              _Bar(value: category.usedFraction, over: over),
              const SizedBox(height: Space.xs + 2),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: note,
                        children: [
                          TextSpan(text: over ? 'Overspent by ' : 'Spent '),
                          TextSpan(text: over ? formatBalance(-category.balanceCents) : spent, style: figures(note)),
                          if (!over && category.carryover) const TextSpan(text: ' · rolls over'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  _Budgeted(cents: category.budgetedCents, editable: onTap != null),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A category with nothing budgeted or spent this month: one quiet line, so
/// the rows in use stand out.
class _UnusedCategoryRow extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;

  const _UnusedCategoryRow({required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = context.colors.onSurfaceVariant;
    return Semantics(
      label: '$name: nothing budgeted',
      button: onTap != null,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + Space.xl, Space.sm, Space.gutter, Space.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(color: muted),
                ),
              ),
              const SizedBox(width: Space.md),
              if (onTap != null)
                const _Budgeted(cents: 0, editable: true)
              else
                Text(formatBalance(0), style: figures(context.text.bodySmall).copyWith(color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Budgeted extends StatelessWidget {
  final int cents;
  final bool editable;

  const _Budgeted({required this.cents, required this.editable});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final small = figures(context.text.bodySmall);
    if (!editable) return Text('of ${formatBalance(cents)}', style: small.copyWith(color: colors.onSurfaceVariant));
    // Plain words when unset: there can be twenty of these on a screen, and
    // the accent stays rare.
    if (cents == 0) return Text('Set budget', style: context.text.bodySmall?.copyWith(color: colors.primary));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(formatBalance(cents), style: small.copyWith(color: colors.onSurface)),
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
