import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/settings_group.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/account_sheet.dart';

const _log = AppLog('accounts');

/// Settings › Accounts: the accounts kept on this phone
/// (docs/plans/local-ledger.md, Phase 2). Add, rename, set the opening
/// balance, mark off budget, close. Nothing is deleted.
class AccountsSettingsScreen extends ConsumerWidget {
  const AccountsSettingsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final edit = await showAccountSheet(context);
    if (edit == null) return;
    final id = await ref
        .read(ledgerStoreProvider)
        .createAccount(phoneScope, name: edit.name, offBudget: edit.offBudget, openingBalanceCents: edit.balanceCents);
    _log.info('Account added', {'account': id});
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, LedgerAccountView view) async {
    final store = ref.read(ledgerStoreProvider);
    final id = view.account.id;
    final opening = await store.openingBalance(id);
    if (!context.mounted) return;
    final edit = await showAccountSheet(context, existing: view.account, openingBalanceCents: opening);
    if (edit == null) return;
    await store.updateAccount(id, name: edit.name, offBudget: edit.offBudget, closed: edit.closed);
    if (edit.balanceCents != opening) await store.setOpeningBalance(id, edit.balanceCents);
    _log.info(
      switch (edit.closed) {
        true => 'Account closed',
        false => 'Account reopened',
        null => 'Account changed',
      },
      {'account': id},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(ledgerAccountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(tooltip: 'Add account', icon: const Icon(Icons.add_rounded), onPressed: () => _add(context, ref)),
        ],
      ),
      body: accounts.when(
        loading: () => const SkeletonRows(count: 4),
        error: (error, _) => ErrorRetry(
          title: 'Could not load the accounts',
          message: 'Something unexpected went wrong.',
          onRetry: () => ref.invalidate(ledgerAccountsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No accounts yet',
              message:
                  'Add the accounts you want to follow on this phone. Statements you review and '
                  'transactions you add go into them.',
              actionLabel: 'Add account',
              actionIcon: Icons.add_rounded,
              onAction: () => _add(context, ref),
            );
          }
          final open = [
            for (final v in list)
              if (!v.account.closed) v,
          ];
          final closed = [
            for (final v in list)
              if (v.account.closed) v,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
            children: [
              Text(
                'Kept on this phone. Statements you review and transactions you add go into them.',
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              if ((ref.watch(phoneAccountsToMoveProvider).valueOrNull ?? 0) > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.push('/move-accounts'),
                    child: Text('Bring them into ${ref.watch(appConfigProvider).budgetName ?? 'your budget'}'),
                  ),
                ),
              const SizedBox(height: Space.lg),
              if (open.isNotEmpty) SettingsGroup(children: [for (final v in open) _row(context, ref, v)]),
              if (closed.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                SettingsGroup(label: 'Closed', children: [for (final v in closed) _row(context, ref, v)]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, LedgerAccountView view) {
    final account = view.account;
    return SettingsRow(
      icon: account.offBudget ? Icons.savings_outlined : Icons.account_balance_outlined,
      title: account.name,
      subtitle: account.offBudget ? const Text('Off budget') : null,
      value: formatCents(view.balanceCents),
      valueFigures: true,
      onTap: () => _edit(context, ref, view),
    );
  }
}
