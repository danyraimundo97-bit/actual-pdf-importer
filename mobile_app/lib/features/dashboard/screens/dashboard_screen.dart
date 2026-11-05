import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../data/models/budget_month.dart';
import '../../../data/models/account_page.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_emoji.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/ledger_status.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/settings_group.dart';
import '../../../shared/widgets/skeleton.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Home shows the last few; each account's screen has the rest.
const _latestRows = 5;

String _shortMonth(String yyyyMm) => _monthNames[int.parse(yyyyMm.substring(5, 7)) - 1];

/// Home, in the order the questions come: what do I have, how is this month
/// going, where is it, what just happened, where did it go.
///
/// Opened many times a day, so nothing animates on arrival. Only a figure
/// that changes while you're looking (a sync landing) eases to its new value.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    // Without Actual, Home reads the phone's own accounts (local ledger).
    final onPhone = ref.watch(readsLedgerProvider).valueOrNull ?? false;
    final budgetName = onPhone ? null : ref.watch(appConfigProvider).budgetName;
    final budget = ref.watch(budgetMonthProvider(null)).valueOrNull;

    // Pull-to-refresh asks Actual for what changed (nothing to do on the
    // phone's own budget), then rebuilds.
    Future<void> refresh() async {
      await ref.read(ledgerSyncProvider.notifier).syncNow();
      return ref.refresh(dashboardProvider.future);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: dashboard.when(
          skipLoadingOnRefresh: true,
          loading: () => const _DashboardSkeleton(),
          error: (error, _) {
            if (isActualNotConnected(error)) {
              return ConnectActualState(
                state: error is ApiException && error.code == 'NO_BUDGET_SELECTED'
                    ? LinkState.noBudget
                    : LinkState.noActual,
              );
            }
            return ErrorRetry(
              title: 'Could not load the dashboard',
              message: error is ApiException ? error.message : 'Something unexpected went wrong.',
              onRetry: () => ref.invalidate(dashboardProvider),
            );
          },
          data: (data) {
            if (data.isEmpty && onPhone && data.accounts.isEmpty) {
              return EmptyState(
                icon: Icons.account_balance_outlined,
                title: 'Start with your accounts',
                message:
                    'Home shows your balances and where your money goes. Add the accounts you use, '
                    'then import a statement into them. It all stays on this phone.',
                actionLabel: 'Add an account',
                actionIcon: Icons.add_rounded,
                onAction: () => context.push('/settings/accounts'),
              );
            }
            if (data.isEmpty) {
              final empty = EmptyState(
                icon: Icons.insights_outlined,
                title: 'Nothing to show yet',
                message: onPhone
                    ? 'Your accounts have no transactions yet. Import a statement and the numbers show up here.'
                    : 'This budget has no transactions. Import a statement and the numbers '
                          'show up here.',
                actionLabel: 'Import a statement',
                onAction: () => context.go('/import'),
              );
              // A new budget is where the phone's accounts are most at home.
              return Column(
                children: [
                  const _Padded(_MoveAccountsOffer(top: Space.xl)),
                  Expanded(child: empty),
                ],
              );
            }
            return RefreshIndicator(
              onRefresh: refresh,
              child: _DashboardBody(data: data, budget: budget, budgetName: budgetName, onPhone: onPhone),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Dashboard data;

  /// This month's budget, for "spent of budget"; null until it's read.
  final BudgetMonth? budget;
  final String? budgetName;

  /// Read from the phone's own ledger, not Actual.
  final bool onPhone;

  const _DashboardBody({required this.data, this.budget, required this.budgetName, this.onPhone = false});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Space.xxl);
    final month = data.currentMonth;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom: room for the quick-add button.
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xxl * 3),
      children: [
        _Padded(_NetWorth(cents: data.netWorthCents, budgetName: budgetName, onPhone: onPhone)),
        const _Padded(_MoveAccountsOffer()),
        if (month != null) ...[const SizedBox(height: Space.xl), _Padded(_ThisMonth(month: month, budget: budget))],
        if (data.uncategorizedCount > 0) ...[
          const SizedBox(height: Space.md),
          _Padded(_UncategorizedRow(count: data.uncategorizedCount)),
        ],
        if (data.accounts.isNotEmpty) ...[gap, _Padded(_Accounts(accounts: data.accounts))],
        if (data.recent.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Latest')),
          ..._recentWithDays(data.recent.take(_latestRows).toList()),
        ],
        if (data.topCategories.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Where it went this month')),
          _Padded(_CategoryBars(categories: data.topCategories)),
        ],
        gap,
        const _Padded(_SectionTitle('Money in and out')),
        _Padded(_FlowChart(months: data.months)),
        if (data.topPayees.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Top payees this month')),
          _Padded(_PayeeList(payees: data.topPayees)),
        ],
      ],
    );
  }

  /// One day header per day, so the date is read once (as on the account
  /// screen).
  List<Widget> _recentWithDays(List<RecentTransaction> rows) {
    final out = <Widget>[];
    DateTime? day;
    for (final tx in rows) {
      if (day == null || !DateUtils.isSameDay(day, tx.date)) {
        day = tx.date;
        out.add(_DayLabel(date: tx.date, first: out.isEmpty));
      }
      out.add(_RecentRow(tx: tx));
    }
    return out;
  }
}

class _Padded extends StatelessWidget {
  final Widget child;

  const _Padded(this.child);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: Semantics(header: true, child: Text(text, style: context.text.titleMedium)),
  );
}

/// A figure that appears at once, and eases to a new value when it changes
/// in front of you. Instant under reduced motion.
class _EasedCents extends StatelessWidget {
  final int cents;
  final Widget Function(BuildContext context, int cents) builder;

  const _EasedCents({required this.cents, required this.builder});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
    tween: IntTween(end: cents),
    duration: Motion.of(context, Motion.small),
    curve: Motion.easeOut,
    builder: (context, value, _) => builder(context, value),
  );
}

/// With Actual connected, the phone's own accounts aren't on screen. This says
/// so, once per budget: "Not now" leaves them, and Settings › Accounts still
/// has the way.
class _MoveAccountsOffer extends ConsumerStatefulWidget {
  final double top;

  const _MoveAccountsOffer({this.top = Space.lg});

  @override
  ConsumerState<_MoveAccountsOffer> createState() => _MoveAccountsOfferState();
}

class _MoveAccountsOfferState extends ConsumerState<_MoveAccountsOffer> {
  Future<void> _notNow(String budget) async {
    await ref.read(settingsStoreProvider).dismissPhoneAccountsOffer(budget);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(phoneAccountsToMoveProvider).valueOrNull ?? 0;
    final budget = ref.watch(appConfigProvider).budgetSyncId;
    if (count == 0 || budget == null || ref.read(settingsStoreProvider).phoneAccountsOfferDismissed(budget)) {
      return const SizedBox.shrink();
    }
    final name = ref.watch(appConfigProvider).budgetName ?? 'this budget';
    return Padding(
      padding: EdgeInsets.only(top: widget.top),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.xs),
        decoration: BoxDecoration(
          borderRadius: Radii.controlAll,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 1 ? 'One account is only on this phone' : '$count accounts are only on this phone',
              style: context.text.titleSmall,
            ),
            const SizedBox(height: Space.xs),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Text(
                'Bring them into $name to see them here and keep them in step with Actual.',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _notNow(budget), child: const Text('Not now')),
                TextButton(onPressed: () => context.push('/move-accounts'), child: const Text('Bring them over')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetWorth extends StatelessWidget {
  final int cents;
  final String? budgetName;
  final bool onPhone;

  const _NetWorth({required this.cents, required this.budgetName, required this.onPhone});

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(budgetName == null ? 'Net worth' : 'Net worth in $budgetName', style: muted),
        const SizedBox(height: Space.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _EasedCents(
            cents: cents,
            builder: (context, value) => Text(
              formatBalance(value),
              style: context.text.headlineMedium?.copyWith(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.4,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: value < 0 ? context.colors.error : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        LedgerStatus(onPhone: onPhone),
      ],
    );
  }
}

/// The one raised surface on Home: this month, and how it sits against the
/// budget when there is one.
class _ThisMonth extends StatelessWidget {
  final MonthFlow month;
  final BudgetMonth? budget;

  const _ThisMonth({required this.month, this.budget});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final budgeted = budget?.totalBudgetedCents ?? 0;
    final spent = -(budget?.totalSpentCents ?? 0);
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: settingsGroupColor(context),
        borderRadius: Radii.controlAll,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(monthLabel(month.month), style: context.text.titleSmall),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MiniStat(label: 'In', cents: month.incomeCents, color: context.tokens.inflow),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _MiniStat(label: 'Out', cents: -month.spendingCents),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _MiniStat(label: 'Net', cents: month.netCents),
              ),
            ],
          ),
          if (budgeted > 0) ...[const SizedBox(height: Space.lg), _BudgetBar(spent: spent, budgeted: budgeted)],
        ],
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final int spent;
  final int budgeted;

  const _BudgetBar({required this.spent, required this.budgeted});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final over = spent > budgeted;
    final share = spent <= 0 ? 0.0 : (spent / budgeted).clamp(0.0, 1.0);
    return Semantics(
      excludeSemantics: true,
      label: over
          ? 'Over budget by ${formatBalance(spent - budgeted)}'
          : '${(spent * 100 / budgeted).round()} percent of the budget spent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              color: over ? colors.error : colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: Space.xs + 2),
          Text(
            over
                ? 'Over budget by ${formatBalance(spent - budgeted)}'
                : '${(spent * 100 / budgeted).round()}% of ${formatBalance(budgeted)} budgeted',
            style: context.text.bodySmall?.copyWith(color: over ? colors.error : null),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int cents;
  final Color? color;

  const _MiniStat({required this.label, required this.cents, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _EasedCents(
            cents: cents,
            builder: (context, value) =>
                Text(formatCents(value), style: figures(context.text.bodyMedium).copyWith(color: color)),
          ),
        ),
      ],
    );
  }
}

class _UncategorizedRow extends StatelessWidget {
  final int count;

  const _UncategorizedRow({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.primary.withValues(alpha: 0.07),
      borderRadius: Radii.controlAll,
      clipBehavior: Clip.antiAlias,
      child: Pressable(
        onTap: () => context.push('/dashboard/uncategorized'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
          child: Row(
            children: [
              Icon(Icons.sell_outlined, color: colors.primary, size: 18),
              const SizedBox(width: Space.md),
              Expanded(child: Text(
                  count == 1
                      ? '1 transaction in the last 30 days without a category'
                      : '$count transactions in the last 30 days without a category',
                  style: context.text.bodyMedium,
                )),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every account in view: on budget first, then off budget with their own
/// total when there are both.
class _Accounts extends StatelessWidget {
  final List<DashboardAccount> accounts;

  const _Accounts({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final on = [
      for (final a in accounts)
        if (!a.offbudget) a,
    ];
    final off = [
      for (final a in accounts)
        if (a.offbudget) a,
    ];
    final both = on.isNotEmpty && off.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Accounts'),
        if (on.isNotEmpty) _AccountGroup(label: both ? 'On budget' : null, accounts: on),
        if (both) const SizedBox(height: Space.lg),
        if (off.isNotEmpty) _AccountGroup(label: 'Off budget', accounts: off),
      ],
    );
  }
}

class _AccountGroup extends StatelessWidget {
  final String? label;
  final List<DashboardAccount> accounts;

  const _AccountGroup({required this.label, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = accounts.fold<int>(0, (sum, a) => sum + a.balanceCents);
    final muted = context.text.labelLarge?.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.lg, Space.sm),
            child: Row(
              children: [
                Expanded(child: Text(label!, style: muted)),
                Text(formatBalance(total), style: figures(muted)),
              ],
            ),
          ),
        SettingsGroup(
          dividerIndent: Space.lg,
          children: [
            for (final a in accounts)
              SettingsRow(
                title: a.name,
                value: formatBalance(a.balanceCents),
                valueFigures: true,
                valueColor: a.balanceCents < 0 ? colors.error : colors.onSurface,
                onTap: () => context.push('/dashboard/accounts/${Uri.encodeComponent(a.id)}', extra: a.name),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  final DateTime date;
  final bool first;

  const _DayLabel({required this.date, required this.first});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Space.gutter, first ? 0 : Space.md, Space.gutter, Space.xs),
    child: Text(dayLabel(date), style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
  );
}

class _RecentRow extends StatelessWidget {
  final RecentTransaction tx;

  const _RecentRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accountId = tx.accountId;
    return Pressable(
      onTap: accountId == null
          ? null
          : () => context.push('/dashboard/accounts/${Uri.encodeComponent(accountId)}', extra: tx.account),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.payee ?? 'No payee',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${withEmoji(tx.categoryEmoji, tx.category ?? 'Uncategorized')} · ${tx.account}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: tx.category == null ? colors.primary : null),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text(
              formatCents(tx.amountCents),
              style: figures(context.text.bodyMedium)
                  .copyWith(fontWeight: FontWeight.w500, color: tx.amountCents > 0 ? context.tokens.inflow : null),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ranked bars: lengths compare at a glance, which a ring of near-identical
/// purples never did. "Other" and "Uncategorized" are grey, so they don't
/// read as a category.
class _CategoryBars extends StatelessWidget {
  final List<CategorySpend> categories;

  const _CategoryBars({required this.categories});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = categories.fold<int>(0, (sum, c) => sum + c.spendingCents);
    final largest = categories.fold<int>(0, (m, c) => c.spendingCents > m ? c.spendingCents : m);
    return Column(
      children: [
        for (final c in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CategoryGlyph(emoji: c.emoji, name: c.categoryId == null ? null : c.name),
                    const SizedBox(width: CategoryGlyph.gap),
                    Expanded(
                      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                    ),
                    const SizedBox(width: Space.md),
                    Text(formatBalance(c.spendingCents), style: figures(context.text.bodyMedium)),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(c.spendingCents * 100 / (total == 0 ? 1 : total)).round()}%',
                        textAlign: TextAlign.end,
                        style: figures(context.text.bodySmall),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: largest == 0 ? 0 : c.spendingCents / largest,
                      child: Container(height: 4, color: c.categoryId == null ? colors.outline : colors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: Space.xs + 2),
      Text(label, style: context.text.bodySmall),
    ],
  );
}

/// Six months of in and out. Past months are dimmed, so this month's pair
/// is the one the eye lands on.
class _FlowChart extends StatelessWidget {
  final List<MonthFlow> months;

  const _FlowChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inflow = context.tokens.inflow;
    final spend = colors.primary;
    final maxCents = months.fold<int>(0, (m, f) => [m, f.incomeCents, f.spendingCents].reduce((a, b) => a > b ? a : b));
    final maxY = maxCents == 0 ? 1.0 : maxCents / 100 * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Legend(color: inflow, label: 'In'),
            const SizedBox(width: Space.lg),
            _Legend(color: spend, label: 'Out'),
          ],
        ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 160,
          child: BarChart(
            duration: Duration.zero,
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxY / 2,
                getDrawingHorizontalLine: (_) => FlLine(color: colors.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= months.length) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(_shortMonth(months[i].month), style: context.text.bodySmall),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                // The bars are thin: give a finger some room, mostly above
                // them, without reaching the bar beside it (3 apart).
                touchExtraThreshold: const EdgeInsets.fromLTRB(1, 24, 1, 8),
                touchCallback: (event, response) {
                  final spot = response?.spot;
                  if (event is! FlTapUpEvent || spot == null) return;
                  final flow = spot.touchedRodDataIndex == 0 ? MonthFlowFilter.income : MonthFlowFilter.spending;
                  context.push('/dashboard/transactions?month=${months[spot.touchedBarGroupIndex].month}&flow=${flow.name}');
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colors.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final m = months[group.x];
                    final cents = rodIndex == 0 ? m.incomeCents : -m.spendingCents;
                    return BarTooltipItem(
                      formatCents(cents),
                      figures(context.text.bodySmall).copyWith(color: colors.onInverseSurface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      _rod(months[i].incomeCents, inflow, current: i == months.length - 1),
                      _rod(months[i].spendingCents, spend, current: i == months.length - 1),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _rod(int cents, Color color, {required bool current}) => BarChartRodData(
    toY: cents / 100,
    color: current ? color : color.withValues(alpha: 0.45),
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
  );
}

class _PayeeList extends StatelessWidget {
  final List<PayeeSpend> payees;

  const _PayeeList({required this.payees});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in payees)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text('${p.count} transaction${p.count == 1 ? '' : 's'}', style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(formatCents(-p.spendingCents), style: figures(context.text.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Same silhouette as the loaded screen: net worth, the month panel, then
/// rows.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
        children: const [
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 90, height: 14)),
          SizedBox(height: Space.sm),
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 220, height: 40, radius: 8)),
          SizedBox(height: Space.sm),
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 130, height: 14)),
          SizedBox(height: Space.xl),
          Skeleton(height: 132, radius: Radii.control),
          SizedBox(height: Space.xxl),
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 100, height: 18)),
          SizedBox(height: Space.md),
          Skeleton(height: 112, radius: Radii.control),
          SizedBox(height: Space.xxl),
          SkeletonRows(count: 3, padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}
