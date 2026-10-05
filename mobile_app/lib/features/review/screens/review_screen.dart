import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/banks.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/import_result_sheet.dart';
import '../widgets/transaction_edit_sheet.dart';
import '../widgets/transaction_row.dart';
import 'review_screen_args.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final ReviewScreenArgs args;

  const ReviewScreen({super.key, required this.args});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late List<ParsedTransaction> _transactions;
  List<ActualCategoryGroup> _categoryGroups = [];
  bool _importing = false;
  final Set<String> _editedPayees = {};

  @override
  void initState() {
    super.initState();
    _transactions = List.of(widget.args.parseResult.transactions);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    try {
      final groups = await ref
          .read(importerApiProvider)
          .getActualCategories(budgetSyncId: widget.args.budgetSyncId);
      if (mounted) setState(() => _categoryGroups = groups);
    } on ApiException {
      // The review screen still works without categories loaded — the
      // category picker just won't have anything to offer yet.
    }
  }

  int get _includedCount => _transactions.where((t) => t.include).length;

  int get _totalCents =>
      _transactions.where((t) => t.include).fold(0, (sum, t) => sum + t.amountCents);

  int get _categorizedCount =>
      _transactions.where((t) => t.include && t.effectiveCategoryId != null).length;

  void _updateTransaction(int index, ParsedTransaction updated) {
    setState(() => _transactions[index] = updated);
  }

  void _toggleInclude(int index) {
    _updateTransaction(
      index,
      _transactions[index].copyWith(include: !_transactions[index].include),
    );
  }

  Future<void> _editTransaction(int index) async {
    final result = await showModalBottomSheet<ParsedTransaction>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          TransactionEditSheet(transaction: _transactions[index], categoryGroups: _categoryGroups),
    );
    if (result == null) return;
    if (result.overrideCategoryId != null &&
        result.overrideCategoryId != _transactions[index].suggestedCategoryId) {
      _editedPayees.add(result.payee);
    }
    _updateTransaction(index, result);
  }

  Future<void> _confirmImport() async {
    final included = _transactions.where((t) => t.include).toList();
    if (included.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import ${included.length} transaction${included.length == 1 ? '' : 's'}?'),
        content: Text(
          'They will be added to "${widget.args.account.name}". '
          'Lines already in Actual are matched, not duplicated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      final result = await ref
          .read(importerApiProvider)
          .confirmImport(
            accountId: widget.args.account.id,
            transactions: included,
            budgetSyncId: widget.args.budgetSyncId,
          );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => ImportResultSheet(
          result: result,
          editedPayees: _editedPayees.toList(),
          transactions: _transactions,
          budgetSyncId: widget.args.budgetSyncId,
        ),
      );
      // Hand the result back to the inbox, which marks the statement imported.
      if (mounted) context.pop(result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Rows interleaved with a header wherever the date changes, so the date
  /// is read once per day instead of once per line. Statement order is kept.
  List<_ListEntry> _buildEntries() {
    final entries = <_ListEntry>[];
    DateTime? lastDate;
    for (var i = 0; i < _transactions.length; i++) {
      final date = _transactions[i].date;
      if (date != lastDate) {
        entries.add(_ListEntry.header(date));
        lastDate = date;
      }
      entries.add(_ListEntry.row(i));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final count = _includedCount;

    if (_transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No transactions found',
          message:
              'The statement was read, but no transaction lines were found in it. '
              'Check that it covers a period with activity.',
          actionLabel: 'Choose another statement',
          onAction: () => context.pop(),
        ),
      );
    }

    final entries = _buildEntries();
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ReviewHeader(
              bankName: bankDisplayName(args.parseResult.bankId),
              accountName: args.account.name,
              totalCents: _totalCents,
              includedCount: count,
              totalCount: _transactions.length,
              categorizedCount: _categorizedCount,
            ),
          ),
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final index = entry.index;
              if (index == null) return _DateHeader(date: entry.date!);
              return TransactionRow(
                transaction: _transactions[index],
                onTap: () => _editTransaction(index),
                onToggleInclude: () => _toggleInclude(index),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
            child: BusyButton(
              label: count == 0
                  ? 'Nothing selected'
                  : 'Import $count transaction${count == 1 ? '' : 's'}',
              busy: _importing,
              onPressed: count > 0 ? _confirmImport : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListEntry {
  final DateTime? date;
  final int? index;

  const _ListEntry.header(DateTime this.date) : index = null;
  const _ListEntry.row(int this.index) : date = null;
}

class _ReviewHeader extends StatelessWidget {
  final String bankName;
  final String accountName;
  final int totalCents;
  final int includedCount;
  final int totalCount;
  final int categorizedCount;

  const _ReviewHeader({
    required this.bankName,
    required this.accountName,
    required this.totalCents,
    required this.includedCount,
    required this.totalCount,
    required this.categorizedCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final uncategorized = includedCount - categorizedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$bankName statement into $accountName', style: muted),
          const SizedBox(height: Space.sm),
          Semantics(
            label: 'Net total of selected transactions',
            child: Text(
              formatCents(totalCents),
              // Display size reads better in the sans than in mono; tabular
              // figures keep the digits steady as rows are toggled.
              style: context.text.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text('$includedCount of $totalCount selected', style: muted),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Icon(
                uncategorized == 0 ? Icons.check_circle_outline_rounded : Icons.sell_outlined,
                size: 18,
                color: uncategorized == 0 ? context.tokens.inflow : colors.primary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  uncategorized == 0
                      ? 'Every selected line has a category.'
                      : '$uncategorized without a category. Tap a line to set one.',
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Text(
        formatDisplayDate(date),
        style: figures(context.text.labelMedium).copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
