import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/category_emoji.dart';
import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/account_page.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../accounts/widgets/transaction_rows.dart';
import 'budget_screen.dart';

const _log = AppLog('budget');

/// Every transaction of one month, across all accounts, newest first and
/// grouped by day, from the ledger. Pull to refresh. Tap a row to change its category.
class MonthTransactionsScreen extends ConsumerStatefulWidget {
  /// `YYYY-MM`; null = this month.
  final String? month;

  /// Just what makes up Home's In or Out bar, when opened from one.
  final MonthFlowFilter filter;

  /// Just this category's transactions, when opened from the budget.
  final String? categoryId;
  final String? categoryName;

  const MonthTransactionsScreen({
    super.key,
    this.month,
    this.filter = MonthFlowFilter.all,
    this.categoryId,
    this.categoryName,
  });

  @override
  ConsumerState<MonthTransactionsScreen> createState() => _MonthTransactionsScreenState();
}

class _MonthTransactionsScreenState extends ConsumerState<MonthTransactionsScreen> {
  static String _thisMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  late String _month = widget.month ?? _thisMonth();

  /// Moves one transaction to another category. Only that one: the category
  /// memory, and so the payee's next statement line, stays as it is.
  Future<void> _changeCategory(AccountTransaction tx) async {
    final store = ref.read(ledgerStoreProvider);
    final row = await store.transaction(tx.id);
    if (row == null) return;
    final groups = row.scope == phoneScope
        ? await ref.read(localCategoryStoreProvider).groups(budgetSyncId: ref.read(appConfigProvider).budgetSyncId)
        : await ref.read(ledgerReportsProvider).categoryPicker(row.scope);
    if (!mounted) return;
    final choice = await pickCategory(context, groups);
    if (choice == null || choice.id == row.categoryId) return;

    final previous = row.categoryId;
    final sync = ref.read(ledgerSyncProvider.notifier);
    await store.setCategories({tx.id: choice.id});
    sync.request(delay: Duration.zero);
    _log.info('Transaction category changed', {'transaction': tx.id});
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Moved to ${splitCategoryName(choice.name).name}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await store.setCategories({tx.id: previous});
            sync.request(delay: Duration.zero);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(monthTransactionsProvider(_month));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.filter) {
          MonthFlowFilter.all => widget.categoryName ?? 'Transactions',
          MonthFlowFilter.income => 'Money in',
          MonthFlowFilter.spending => 'Money out',
        }),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthSwitcher(month: _month, onMonth: (m) => setState(() => _month = m)),
          Expanded(
            child: data.when(
              skipLoadingOnRefresh: true,
              loading: () => const SkeletonRows(count: 8),
              error: (error, _) => isActualNotConnected(error)
                  ? const ConnectActualState(state: LinkState.noActual)
                  : ErrorRetry(
                      title: 'Could not load this month',
                      message: error is ApiException ? error.message : 'Something unexpected went wrong.',
                      onRetry: () => ref.invalidate(monthTransactionsProvider(_month)),
                    ),
              data: (month) => RefreshIndicator(
                onRefresh: () async {
                  await ref.read(ledgerSyncProvider.notifier).syncNow();
                  return ref.refresh(monthTransactionsProvider(_month).future);
                },
                child: _MonthList(
                  data: month,
                  filter: widget.filter,
                  categoryId: widget.categoryId,
                  onChangeCategory: _changeCategory,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonth;

  const _MonthSwitcher({required this.month, required this.onMonth});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => onMonth(shiftMonth(month, -1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(monthLabel(month), textAlign: TextAlign.center, style: context.text.titleLarge),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: month.compareTo(thisMonth) < 0 ? () => onMonth(shiftMonth(month, 1)) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _MonthList extends StatelessWidget {
  final MonthTransactions data;
  final MonthFlowFilter filter;
  final String? categoryId;
  final ValueChanged<AccountTransaction> onChangeCategory;

  const _MonthList({required this.data, required this.filter, this.categoryId, required this.onChangeCategory});

  @override
  Widget build(BuildContext context) {
    final category = categoryId;
    final rows = category == null ? data.rows(filter) : data.rowsInCategory(category);
    final count = rows.length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Bottom: room for the quick-add button.
      padding: const EdgeInsets.only(bottom: Space.xxl * 3),
      children: [
        if (count == 0)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions this month',
            message: category == null
                ? 'Transactions in any of your accounts show up here.'
                : 'Transactions in this category show up here.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1 ? '1 transaction' : '$count transactions',
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xs),
                Text(switch (filter) {
                  MonthFlowFilter.all when category != null =>
                    'Total ${formatCents(rows.fold(0, (sum, t) => sum + t.amountCents))}',
                  MonthFlowFilter.all =>
                    'In ${formatCents(data.incomeCents)}  ·  Out ${formatCents(-data.spendingCents)}',
                  MonthFlowFilter.income => 'In ${formatCents(data.incomeCents)}',
                  MonthFlowFilter.spending => 'Out ${formatCents(-data.spendingCents)}',
                }, style: figures(context.text.bodyLarge).copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          ...transactionRowsWithDayHeaders(
            rows,
            // Transfers and splits are read-only on the phone; an opening
            // balance has no category.
            onTap: (tx) => !tx.transfer && tx.splits.isEmpty && !tx.openingBalance ? () => onChangeCategory(tx) : null,
          ),
        ],
      ],
    );
  }
}
