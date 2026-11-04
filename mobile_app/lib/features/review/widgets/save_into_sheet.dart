import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/db/app_database.dart';

/// Picks the phone account a statement is saved into. Pops with the
/// [LedgerAccount], or with [SaveIntoSheet.newAccount] for "New account…".
class SaveIntoSheet extends StatelessWidget {
  static const newAccount = 'new-account';

  final List<LedgerAccount> accounts;
  final LedgerAccount? selected;

  const SaveIntoSheet({super.key, required this.accounts, this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
              child: Text('Save into', style: context.text.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Space.lg),
                children: [
                  for (final account in accounts)
                    ListTile(
                      leading: Icon(account.offBudget ? Icons.savings_outlined : Icons.account_balance_outlined),
                      title: Text(account.name),
                      subtitle: account.offBudget ? const Text('Off budget') : null,
                      selected: account.id == selected?.id,
                      trailing: account.id == selected?.id ? Icon(Icons.check_rounded, color: colors.primary) : null,
                      onTap: () => Navigator.pop(context, account),
                    ),
                  ListTile(
                    leading: Icon(Icons.add_rounded, color: colors.primary),
                    title: Text('New account…', style: TextStyle(color: colors.primary)),
                    onTap: () => Navigator.pop(context, newAccount),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
