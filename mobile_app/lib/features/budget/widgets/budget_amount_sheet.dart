import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';

/// Asks how much to budget for one category in one month. Returns the new
/// amount in cents (0 clears it), or null when cancelled.
Future<int?> showBudgetAmountSheet(
  BuildContext context, {
  required String categoryName,
  required String monthName,
  required int currentCents,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.sheet(context),
    builder: (_) => _BudgetAmountSheet(categoryName: categoryName, monthName: monthName, currentCents: currentCents),
  );
}

class _BudgetAmountSheet extends StatefulWidget {
  final String categoryName;
  final String monthName;
  final int currentCents;

  const _BudgetAmountSheet({required this.categoryName, required this.monthName, required this.currentCents});

  @override
  State<_BudgetAmountSheet> createState() => _BudgetAmountSheetState();
}

class _BudgetAmountSheetState extends State<_BudgetAmountSheet> {
  late final _amount = TextEditingController(text: centsToInput(widget.currentCents));
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final cents = parseSignedAmountInput(_amount.text);
    if (cents == null || cents < 0) {
      setState(() => _error = 'Enter an amount, like 250 or 99,90.');
      return;
    }
    Navigator.pop<int>(context, cents);
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.categoryName,
      description: 'How much to budget for ${widget.monthName}.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
      children: [
        LabeledField(
          label: 'Budgeted',
          helper: 'Leave it empty for nothing.',
          child: TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: figures(context.text.bodyLarge),
            decoration: InputDecoration(suffixText: '€', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
        ),
      ],
    );
  }
}
