import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/dashboard.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthLabel(String yyyyMm) => _monthNames[int.parse(yyyyMm.substring(5, 7)) - 1];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final budgetName = ref.watch(appConfigProvider).budgetName;

    Future<void> refresh() => ref.refresh(dashboardProvider.future);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: dashboard.when(
          skipLoadingOnRefresh: true,
          loading: () => const _DashboardSkeleton(),
          error: (error, _) {
            if (error is ApiException && error.code == 'NO_BUDGET_SELECTED') {
              return EmptyState(
                icon: Icons.folder_outlined,
                title: 'No budget selected',
                message: 'Choose which Actual budget to show in Settings.',
                actionLabel: 'Open Settings',
                onAction: () => context.go('/settings'),
              );
            }
            return ErrorRetry(
              title: 'Could not load the dashboard',
              message: error is ApiException ? error.message : 'Something unexpected went wrong.',
              onRetry: () => ref.invalidate(dashboardProvider),
            );
          },
          data: (data) {
            if (data.isEmpty) {
              return EmptyState(
                icon: Icons.insights_outlined,
                title: 'Nothing to show yet',
                message:
                    'This budget has no transactions. Import a statement and the numbers '
                    'show up here.',
                actionLabel: 'Import a statement',
                onAction: () => context.go('/import'),
              );
            }
            return RefreshIndicator(
              onRefresh: refresh,
              child: _DashboardBody(data: data, budgetName: budgetName),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Dashboard data;
  final String? budgetName;

  const _DashboardBody({required this.data, required this.budgetName});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: Space.xxl + Space.sm);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xxl),
      children: [
        _Padded(_Header(data: data, budgetName: budgetName)),
        if (data.uncategorizedCount > 0) ...[
          const SizedBox(height: Space.xl),
          _Padded(_AttentionRow(count: data.uncategorizedCount)),
        ],
        gap,
        const _Padded(_SectionTitle('Money in and out')),
        _Padded(_FlowChart(months: data.months)),
        if (data.topCategories.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Where it went this month')),
          _Padded(_CategoryBreakdown(categories: data.topCategories)),
        ],
        if (data.accounts.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Accounts')),
          _AccountStrip(accounts: data.accounts),
        ],
        if (data.topPayees.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Top payees this month')),
          _Padded(_PayeeRanking(payees: data.topPayees)),
        ],
        if (data.recent.isNotEmpty) ...[
          gap,
          const _Padded(_SectionTitle('Latest transactions')),
          for (final tx in data.recent) _RecentRow(tx: tx),
        ],
      ],
    );
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
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Text(text, style: context.text.titleLarge),
  );
}

/// Eases numbers in from zero on first build, so the headline figure and
/// the charts read as "just computed". Instant under reduced motion.
class _Reveal extends StatelessWidget {
  final Widget Function(BuildContext context, double t) builder;
  const _Reveal({required this.builder});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return builder(context, 1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => builder(context, t),
    );
  }
}

class _Header extends StatelessWidget {
  final Dashboard data;
  final String? budgetName;

  const _Header({required this.data, required this.budgetName});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final month = data.currentMonth;
    final muted = context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(budgetName == null ? 'Net worth' : 'Net worth in $budgetName', style: muted),
        const SizedBox(height: Space.xs),
        _Reveal(
          builder: (context, t) => Text(
            formatCents((data.netWorthCents * t).round()),
            style: context.text.headlineMedium?.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (month != null) ...[
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'In this month',
                  value: formatCents(month.incomeCents),
                  color: context.tokens.inflow,
                ),
              ),
              Expanded(
                child: _MiniStat(label: 'Out this month', value: formatCents(-month.spendingCents)),
              ),
              Expanded(
                child: _MiniStat(label: 'Net', value: formatCents(month.netCents)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

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
          child: Text(value, style: figures(context.text.titleMedium).copyWith(color: color)),
        ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final int count;

  const _AttentionRow({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.primary.withValues(alpha: 0.07),
      borderRadius: Radii.controlAll,
      child: InkWell(
        borderRadius: Radii.controlAll,
        onTap: () => context.go('/categories'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
          child: Row(
            children: [
              Icon(Icons.sell_outlined, color: colors.primary, size: 20),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  '$count transaction${count == 1 ? '' : 's'} from the last 30 days '
                  '${count == 1 ? 'has' : 'have'} no category. Teach the importer in '
                  'Category memory.',
                  style: context.text.bodyMedium,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
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

class _FlowChart extends StatelessWidget {
  final List<MonthFlow> months;

  const _FlowChart({required this.months});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inflow = context.tokens.inflow;
    final spend = colors.primary;
    final maxCents = months.fold<int>(
      0,
      (m, f) => [m, f.incomeCents, f.spendingCents].reduce((a, b) => a > b ? a : b),
    );
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
        const SizedBox(height: Space.lg),
        SizedBox(
          height: 200,
          child: _Reveal(
            builder: (context, t) => BarChart(
              duration: Duration.zero,
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: colors.outlineVariant, strokeWidth: 1),
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
                          child: Text(_monthLabel(months[i].month), style: context.text.bodySmall),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
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
                      barsSpace: 4,
                      barRods: [
                        _rod(months[i].incomeCents * t, inflow),
                        _rod(months[i].spendingCents * t, spend),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _rod(double cents, Color color) => BarChartRodData(
    toY: cents / 100,
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );
}

class _CategoryBreakdown extends StatelessWidget {
  final List<CategorySpend> categories;

  const _CategoryBreakdown({required this.categories});

  /// One hue: the accent, stepping toward neutral for smaller slices, with
  /// "Other"/"Uncategorized" in plain grey so they never look like a category.
  List<Color> _palette(BuildContext context) {
    final colors = context.colors;
    final named = categories.where((c) => c.categoryId != null).length;
    var step = 0;
    return [
      for (final c in categories)
        if (c.categoryId == null)
          colors.outline
        else
          Color.lerp(colors.primary, colors.surfaceContainerHighest, (step++) / (named + 1))!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(0, (sum, c) => sum + c.spendingCents);
    final palette = _palette(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 136,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _Reveal(
                builder: (context, t) => PieChart(
                  duration: Duration.zero,
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    sections: [
                      for (var i = 0; i < categories.length; i++)
                        PieChartSectionData(
                          value: categories[i].spendingCents.toDouble(),
                          color: palette[i],
                          radius: 18 * t + 4,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Spent', style: context.text.bodySmall),
                  FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      child: Text(
                        formatCents(-total).replaceFirst('−', ''),
                        style: figures(context.text.labelLarge),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.xl),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < categories.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette[i],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(
                          categories[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium,
                        ),
                      ),
                      Text(
                        '${(categories[i].spendingCents * 100 / (total == 0 ? 1 : total)).round()}%',
                        style: figures(context.text.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountStrip extends StatelessWidget {
  final List<DashboardAccount> accounts;

  const _AccountStrip({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
        itemBuilder: (context, i) {
          final a = accounts[i];
          return Container(
            width: 176,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: Radii.controlAll,
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  a.offbudget ? '${a.name} (off-budget)' : a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCents(a.balanceCents),
                    style: figures(context.text.titleMedium)
                        .copyWith(color: a.balanceCents < 0 ? colors.error : null),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PayeeRanking extends StatelessWidget {
  final List<PayeeSpend> payees;

  const _PayeeRanking({required this.payees});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < payees.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: figures(context.text.titleMedium).copyWith(
                      color: i == 0 ? context.colors.primary : context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payees[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${payees[i].count} transaction${payees[i].count == 1 ? '' : 's'}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(formatCents(-payees[i].spendingCents), style: figures(context.text.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final RecentTransaction tx;

  const _RecentRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final detail = [tx.category ?? 'Uncategorized', tx.account].join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm + 2),
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
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: tx.category == null ? colors.primary : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCents(tx.amountCents),
                style: figures(context.text.bodyLarge).copyWith(
                  fontWeight: FontWeight.w500,
                  color: tx.amountCents > 0 ? context.tokens.inflow : null,
                ),
              ),
              Text(formatDisplayDate(tx.date), style: figures(context.text.bodySmall)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Same silhouette as the loaded dashboard: headline figure, three stats,
/// chart block, then rows.
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
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 140, height: 14)),
          SizedBox(height: Space.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(width: 220, height: 40, radius: 8),
          ),
          SizedBox(height: Space.xl),
          Row(
            children: [
              Expanded(child: Skeleton(height: 34, radius: 8)),
              SizedBox(width: Space.md),
              Expanded(child: Skeleton(height: 34, radius: 8)),
              SizedBox(width: Space.md),
              Expanded(child: Skeleton(height: 34, radius: 8)),
            ],
          ),
          SizedBox(height: Space.xxl + Space.sm),
          Align(alignment: Alignment.centerLeft, child: Skeleton(width: 180, height: 18)),
          SizedBox(height: Space.lg),
          Skeleton(height: 200, radius: Radii.control),
          SizedBox(height: Space.xxl),
          SkeletonRows(count: 3, padding: EdgeInsets.zero),
        ],
      ),
    );
  }
}
