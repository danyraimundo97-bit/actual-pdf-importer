import 'package:flutter/material.dart';

import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/actual_category.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';

/// A transaction as the sheet edits it.
typedef LedgerTransactionEdit = ({DateTime date, int amountCents, String payee, String? categoryId, String notes});

/// What the sheet returns: changed fields, or a removal.
typedef LedgerTransactionAction = ({LedgerTransactionEdit? edit, bool remove});

/// Edits or removes one of the phone's transactions (the account screen,
/// docs/plans/local-ledger.md, Phase 4). Null when cancelled.
Future<LedgerTransactionAction?> showLedgerTransactionSheet(
  BuildContext context, {
  required LedgerTransactionEdit current,
  required String? categoryName,
  required List<ActualCategoryGroup> categoryGroups,
}) {
  return showModalBottomSheet<LedgerTransactionAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.sheet(context),
    builder: (_) => _LedgerTransactionSheet(current: current, categoryName: categoryName, groups: categoryGroups),
  );
}

class _LedgerTransactionSheet extends StatefulWidget {
  final LedgerTransactionEdit current;
  final String? categoryName;
  final List<ActualCategoryGroup> groups;

  const _LedgerTransactionSheet({required this.current, required this.categoryName, required this.groups});

  @override
  State<_LedgerTransactionSheet> createState() => _LedgerTransactionSheetState();
}

class _LedgerTransactionSheetState extends State<_LedgerTransactionSheet> {
  late final _payee = TextEditingController(text: widget.current.payee);
  late final _amount = TextEditingController(text: centsToInput(widget.current.amountCents));
  late final _notes = TextEditingController(text: widget.current.notes);
  late DateTime _date = widget.current.date;
  late String? _categoryId = widget.current.categoryId;
  late String? _categoryName = widget.categoryName;
  String? _amountError;

  @override
  void dispose() {
    _payee.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final selected = await pickCategory(context, widget.groups);
    if (selected != null) {
      setState(() {
        _categoryId = selected.id;
        _categoryName = selected.name;
      });
    }
  }

  void _save() {
    final cents = parseSignedAmountInput(_amount.text);
    if (cents == null || cents == 0) {
      setState(() => _amountError = 'Enter an amount, like -12,50 for money out.');
      return;
    }
    Navigator.pop<LedgerTransactionAction>(context, (
      edit: (
        date: _date,
        amountCents: cents,
        payee: _payee.text.trim(),
        categoryId: _categoryId,
        notes: _notes.text.trim(),
      ),
      remove: false,
    ));
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this transaction?'),
        content: const Text(
          'It is removed from this account. If it came from a statement, saving that statement again '
          'does not bring it back.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop<LedgerTransactionAction>(context, (edit: null, remove: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'Edit transaction',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
      children: [
        LabeledField(
          label: 'Payee',
          child: TextField(controller: _payee, textCapitalization: TextCapitalization.words),
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Amount',
                helper: _amountError == null ? 'A minus for money out' : null,
                child: TextField(
                  controller: _amount,
                  style: figures(context.text.bodyLarge),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(suffixText: '€', errorText: _amountError, errorMaxLines: 2),
                  onChanged: (_) {
                    if (_amountError != null) setState(() => _amountError = null);
                  },
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
          label: 'Notes',
          child: TextField(controller: _notes, textCapitalization: TextCapitalization.sentences),
        ),
        const SizedBox(height: Space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove transaction'),
            onPressed: _remove,
          ),
        ),
      ],
    );
  }
}
