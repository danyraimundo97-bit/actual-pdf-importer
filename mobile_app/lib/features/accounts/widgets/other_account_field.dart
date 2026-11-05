import 'package:flutter/material.dart';

import '../../../data/models/actual_account.dart';
import '../../../shared/widgets/labeled_field.dart';

/// For money moved between your own accounts: the account on the other side.
/// Optional. Set, the opposite amount goes in that account too
/// ([LedgerStore.addBetweenAccounts]), keeping both balances right.
class OtherAccountField extends StatelessWidget {
  final bool income;
  final List<ActualAccount> accounts;

  /// The transaction's own account, left out of the choices.
  final String? accountId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const OtherAccountField({
    super.key,
    required this.income,
    required this.accounts,
    required this.accountId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final others = accounts.where((a) => a.id != accountId).toList();
    final selected = others.any((a) => a.id == value) ? value : null;
    return LabeledField(
      label: income ? 'Came from (optional)' : 'Went to (optional)',
      child: DropdownButtonFormField<String?>(
        key: ValueKey('other-account-$selected-$accountId'),
        initialValue: selected,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
          for (final a in others)
            DropdownMenuItem<String?>(
              value: a.id,
              child: Text(a.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
