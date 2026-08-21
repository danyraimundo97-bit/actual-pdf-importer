import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../shared/widgets/category_picker_sheet.dart';

/// Edits date/payee/amount/category for one transaction, with the original
/// `rawLine` shown underneath so an edit can be checked against what the
/// PDF actually said.
class TransactionEditSheet extends StatefulWidget {
  final ParsedTransaction transaction;
  final List<ActualCategoryGroup> categoryGroups;

  const TransactionEditSheet({
    super.key,
    required this.transaction,
    required this.categoryGroups,
  });

  @override
  State<TransactionEditSheet> createState() => _TransactionEditSheetState();
}

class _TransactionEditSheetState extends State<TransactionEditSheet> {
  late final TextEditingController _payeeController;
  late final TextEditingController _amountController;
  late DateTime _date;
  String? _categoryId;
  String? _categoryName;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _payeeController = TextEditingController(text: t.payee);
    _amountController = TextEditingController(text: (t.amountCents / 100).toStringAsFixed(2));
    _date = t.date;
    _categoryId = t.effectiveCategoryId;
    _categoryName = t.effectiveCategoryName;
  }

  @override
  void dispose() {
    _payeeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final selected = await pickCategory(context, widget.categoryGroups);
    if (selected != null) {
      setState(() {
        _categoryId = selected.id;
        _categoryName = selected.name;
      });
    }
  }

  void _save() {
    final amountValue = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amountValue == null) {
      setState(() => _amountError = 'Enter a valid amount, e.g. -42.37');
      return;
    }
    final newAmountCents = (amountValue * 100).round();
    final t = widget.transaction;
    final somethingChanged =
        t.payee != _payeeController.text.trim() || t.amountCents != newAmountCents || t.date != _date;

    Navigator.pop(
      context,
      t.copyWith(
        payee: _payeeController.text.trim(),
        amountCents: newAmountCents,
        date: _date,
        overrideCategoryId: _categoryId,
        overrideCategoryName: _categoryName,
        edited: t.edited || somethingChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit transaction', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _payeeController,
              decoration: const InputDecoration(labelText: 'Payee'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (negative = outflow)',
                errorText: _amountError,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(formatDisplayDate(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_categoryName ?? 'Uncategorized'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCategory,
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.transaction.rawLine, style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
