import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/money.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../data/providers.dart';
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
    _updateTransaction(index, _transactions[index].copyWith(include: !_transactions[index].include));
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
        title: const Text('Import these transactions?'),
        content: Text(
          'Importing ${included.length} transaction${included.length == 1 ? '' : 's'} into '
          '"${widget.args.account.name}".',
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
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => ImportResultSheet(
          result: result,
          editedPayees: _editedPayees.toList(),
          transactions: _transactions,
          budgetSyncId: widget.args.budgetSyncId,
        ),
      );
      if (mounted) context.go('/import');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Review — ${widget.args.parseResult.bankId}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_includedCount transactions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Total: ${formatCents(_totalCents)}'),
                    Text('$_categorizedCount of $_includedCount already categorized'),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                return TransactionRow(
                  transaction: tx,
                  onTap: () => _editTransaction(index),
                  onToggleInclude: () => _toggleInclude(index),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: (_includedCount > 0 && !_importing) ? _confirmImport : null,
                child: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Import $_includedCount transaction${_includedCount == 1 ? '' : 's'}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
