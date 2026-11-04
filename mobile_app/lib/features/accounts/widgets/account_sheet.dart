import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/db/app_database.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';

/// What the account sheet asks for. [closed] is null when it didn't change.
typedef AccountEdit = ({String name, bool offBudget, int balanceCents, bool? closed});

/// Adds an account ([existing] null) or edits one. For a new account the
/// amount is its balance today; for an existing one, its opening balance.
Future<AccountEdit?> showAccountSheet(BuildContext context, {LedgerAccount? existing, int openingBalanceCents = 0}) {
  return showModalBottomSheet<AccountEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.sheet(context),
    builder: (_) => _AccountSheet(existing: existing, openingBalanceCents: openingBalanceCents),
  );
}

class _AccountSheet extends StatefulWidget {
  final LedgerAccount? existing;
  final int openingBalanceCents;

  const _AccountSheet({this.existing, required this.openingBalanceCents});

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _balance = TextEditingController(text: centsToInput(widget.openingBalanceCents));
  late bool _offBudget = widget.existing?.offBudget ?? false;
  String? _nameError;
  String? _balanceError;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _save({bool? closed}) {
    final name = _name.text.trim();
    final cents = parseSignedAmountInput(_balance.text);
    setState(() {
      _nameError = name.isEmpty ? 'Give the account a name.' : null;
      _balanceError = cents == null ? 'Enter an amount, like 1250,00 or -40.' : null;
    });
    if (_nameError != null || _balanceError != null) return;
    Navigator.pop<AccountEdit>(context, (name: name, offBudget: _offBudget, balanceCents: cents!, closed: closed));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return SheetBody(
      title: _editing ? 'Edit account' : 'New account',
      description: _editing ? null : 'An account kept on this phone, like your bank account or a card.',
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: Text(_editing ? 'Save' : 'Add')),
      ],
      children: [
        LabeledField(
          label: 'Name',
          child: TextField(
            controller: _name,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(errorText: _nameError),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: _editing ? 'Opening balance' : 'Balance today',
          helper: _editing
              ? 'What it held before its first transaction here. A minus is money you owe.'
              : 'A minus is money you owe, like on a credit card. Leave it empty for 0.',
          child: TextField(
            controller: _balance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: figures(context.text.bodyLarge),
            decoration: InputDecoration(suffixText: '€', errorText: _balanceError),
            onChanged: (_) {
              if (_balanceError != null) setState(() => _balanceError = null);
            },
          ),
        ),
        const SizedBox(height: Space.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Off budget'),
          subtitle: const Text("Savings or investments you don't spend from. Counted in net worth, not in the budget."),
          value: _offBudget,
          onChanged: (value) => setState(() => _offBudget = value),
        ),
        if (existing != null) ...[
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: existing.closed ? null : TextButton.styleFrom(foregroundColor: context.colors.error),
              icon: Icon(existing.closed ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
              label: Text(existing.closed ? 'Reopen account' : 'Close account'),
              onPressed: () => _save(closed: !existing.closed),
            ),
          ),
        ],
      ],
    );
  }
}
