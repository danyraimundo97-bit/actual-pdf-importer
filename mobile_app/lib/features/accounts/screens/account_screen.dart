import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/account_page.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/category_emoji.dart';
import '../../../shared/widgets/connect_actual_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/skeleton.dart';
import '../account_page_controller.dart';
import '../widgets/ledger_transaction_sheet.dart';

const _log = AppLog('accounts');

/// One account: its balance, then every transaction newest first, grouped
/// by day, loading more as you scroll. Pull to refresh.
class AccountScreen extends ConsumerStatefulWidget {
  final String accountId;

  /// Shown in the app bar while the first page loads.
  final String? accountName;

  const AccountScreen({super.key, required this.accountId, this.accountName});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(accountPageProvider(widget.accountId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Change or remove a row, on the phone's own budget or a copy of an Actual
  /// one (the sync sends it). The list reloads by itself (the controller
  /// watches the ledger).
  Future<void> _edit(AccountTransaction tx) async {
    final store = ref.read(ledgerStoreProvider);
    final row = await store.transaction(tx.id);
    if (row == null) return;
    final groups = row.scope == phoneScope
        ? await ref.read(localCategoryStoreProvider).groups(budgetSyncId: ref.read(appConfigProvider).budgetSyncId)
        : await ref.read(ledgerReportsProvider).categoryPicker(row.scope);
    if (!mounted) return;
    final action = await showLedgerTransactionSheet(
      context,
      current: (
        date: tx.date,
        amountCents: tx.amountCents,
        payee: tx.payee ?? '',
        categoryId: row.categoryId,
        notes: tx.notes ?? '',
      ),
      categoryName: tx.category,
      categoryEmoji: tx.categoryEmoji,
      categoryGroups: groups,
    );
    if (action == null) return;
    if (action.remove) {
      await store.deleteTransaction(tx.id);
      _log.info('Transaction removed', {'transaction': tx.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction removed.')));
      }
      return;
    }
    final edit = action.edit!;
    await store.updateTransaction(
      tx.id,
      date: edit.date,
      amountCents: edit.amountCents,
      payee: edit.payee,
      categoryId: edit.categoryId,
      clearCategory: edit.categoryId == null,
      notes: edit.notes,
    );
    _log.info('Transaction changed', {'transaction': tx.id});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountPageProvider(widget.accountId));
    final controller = ref.read(accountPageProvider(widget.accountId).notifier);
    final title = state.name ?? widget.accountName ?? 'Account';

    Widget body;
    if (state.rows.isEmpty && state.loading) {
      body = const SkeletonRows(count: 8);
    } else if (state.rows.isEmpty && state.error != null) {
      final error = state.error;
      body = isActualNotConnected(error)
          ? const ConnectActualState(state: LinkState.noActual)
          : ErrorRetry(
              title: 'Could not load this account',
              message: error is ApiException ? error.message : 'Something unexpected went wrong.',
              onRetry: controller.refresh,
            );
    } else {
      body = RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            _BalanceHeader(balanceCents: state.balanceCents),
            if (state.rows.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                message: state.onPhone
                    ? 'Statements you save into this account show up in this list.'
                    : 'Transactions added to this account in Actual, imported or added here show up in this list.',
              )
            else
              ..._rowsWithDayHeaders(context, state.rows),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(Space.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.hasMore)
              Center(
                child: TextButton(onPressed: controller.loadMore, child: const Text('Could not load more. Try again')),
              ),
          ],
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }

  List<Widget> _rowsWithDayHeaders(BuildContext context, List<AccountTransaction> rows) {
    final out = <Widget>[];
    DateTime? day;
    for (final tx in rows) {
      if (day == null || !DateUtils.isSameDay(day, tx.date)) {
        day = tx.date;
        out.add(_DayHeader(date: tx.date));
      }
      // Transfers and splits are read-only on the phone; the opening balance
      // is changed in Settings › Accounts.
      final canEdit = !tx.transfer && tx.splits.isEmpty && !tx.openingBalance;
      out.add(_TransactionRow(tx: tx, onTap: canEdit ? () => _edit(tx) : null));
    }
    return out;
  }
}

class _BalanceHeader extends StatelessWidget {
  final int? balanceCents;

  const _BalanceHeader({required this.balanceCents});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final balance = balanceCents;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance', style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: Space.xs),
          balance == null
              ? const Skeleton(width: 180, height: 36, radius: 8)
              : Text(
                  formatCents(balance),
                  style: figures(context.text.headlineLarge).copyWith(
                    fontWeight: FontWeight.w600,
                    color: balance < 0 ? colors.error : null,
                  ),
                ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;

  const _DayHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final label = dayLabel(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
      child: Text(
        label,
        style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final AccountTransaction tx;
  final VoidCallback? onTap;

  const _TransactionRow({required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String detail;
    if (tx.openingBalance) {
      detail = 'Changed in Settings › Accounts';
    } else if (tx.transfer) {
      detail = 'Transfer';
    } else if (tx.splits.isNotEmpty) {
      detail = 'Split: ${tx.splits.map((s) => s.category ?? 'Uncategorized').toSet().join(', ')}';
    } else {
      detail = withEmoji(tx.categoryEmoji, tx.category ?? 'Uncategorized');
    }
    final uncategorized = !tx.openingBalance && !tx.transfer && tx.splits.isEmpty && tx.category == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.payee ?? (tx.openingBalance ? 'Opening balance' : 'No payee'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: uncategorized ? colors.primary : null),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            formatCents(tx.amountCents),
            style: figures(context.text.bodyLarge).copyWith(
              fontWeight: FontWeight.w500,
              color: tx.amountCents > 0 ? context.tokens.inflow : null,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
