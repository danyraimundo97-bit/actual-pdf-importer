import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';

/// Edits date/payee/amount/category for one transaction, with the original
/// `rawLine` shown underneath so an edit can be checked against what the
/// PDF actually said.
class TransactionEditSheet extends StatefulWidget {
  final ParsedTransaction transaction;
  final List<ActualCategoryGroup> categoryGroups;

  const TransactionEditSheet({super.key, required this.transaction, required this.categoryGroups});

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
      setState(() => _amountError = 'Enter an amount like -42.37');
      return;
    }
    final newAmountCents = (amountValue * 100).round();
    final t = widget.transaction;
    final somethingChanged =
        t.payee != _payeeController.text.trim() ||
        t.amountCents != newAmountCents ||
        t.date != _date;

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
    final colors = context.colors;
    return SheetBody(
      title: 'Edit transaction',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
      children: [
        LabeledField(
          label: 'Payee',
          child: TextField(
            controller: _payeeController,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Amount',
                helper: _amountError == null ? 'Negative for money out' : null,
                child: TextField(
                  controller: _amountController,
                  style: figures(context.text.bodyLarge),
                  decoration: InputDecoration(errorText: _amountError, errorMaxLines: 2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: LabeledField(
                label: 'Date',
                child: PickerField(
                  value: formatDisplayDate(_date),
                  useFigures: true,
                  trailingIcon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'Category',
          child: PickerField(
            leadingIcon: Icons.sell_outlined,
            value: _categoryName ?? 'Uncategorized',
            isPlaceholder: _categoryName == null,
            trailingIcon: Icons.chevron_right_rounded,
            onTap: _pickCategory,
          ),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'On the statement',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: Radii.controlAll,
            ),
            child: SelectableText(
              widget.transaction.rawLine,
              style: figures(context.text.bodySmall).copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}
