import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/fold.dart';
import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../data/local/ledger_move.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/settings_group.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../categories/category_matching.dart';
import '../../categories/match_categories.dart';

const _log = AppLog('ledger');

typedef _PhoneAccount = ({String id, String name, int balanceCents, int transactions, bool closed});

class _MoveData {
  final String budget;
  final List<_PhoneAccount> accounts;
  final List<({String id, String name})> budgetAccounts;

  /// Categories still waiting for a choice in "Match your categories".
  final int pendingMatches;

  /// Transactions that would arrive without a category as things stand.
  final int withoutCategory;
  final Map<String, String> links;

  const _MoveData({
    required this.budget,
    required this.accounts,
    required this.budgetAccounts,
    required this.pendingMatches,
    required this.withoutCategory,
    required this.links,
  });
}

/// The first connection (docs/plans/local-ledger.md, Phase 5c): the phone's own
/// accounts and transactions go into the budget. Each account joins one of the
/// budget's or becomes a new one; nothing changes until the button, and after
/// it the normal sync sends the rows.
class MoveAccountsScreen extends ConsumerStatefulWidget {
  const MoveAccountsScreen({super.key});

  @override
  ConsumerState<MoveAccountsScreen> createState() => _MoveAccountsScreenState();
}

class _MoveAccountsScreenState extends ConsumerState<MoveAccountsScreen> {
  _MoveData? _data;
  Object? _error;
  bool _moving = false;

  /// Phone account → the budget's account it joins; null = new.
  final _targets = <String, String?>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _read();
      if (!mounted) return;
      setState(() {
        _data = data;
        for (final a in data.accounts) {
          if (_targets.containsKey(a.id)) continue;
          final key = foldAccents(a.name).trim().toLowerCase();
          _targets[a.id] = [
            for (final b in data.budgetAccounts)
              if (foldAccents(b.name).trim().toLowerCase() == key) b.id,
          ].firstOrNull;
        }
      });
    } catch (e, st) {
      _log.error('Could not read what to bring over', e, st);
      if (mounted) setState(() => _error = e);
    }
  }

  Future<_MoveData> _read() async {
    final budget = await ref.read(ledgerScopeProvider.future);
    if (budget == phoneScope) throw StateError('No budget connected');
    await ref.read(ledgerSyncProvider.notifier).ensurePulled(budget);
    final ledger = ref.read(ledgerStoreProvider);
    final categories = ref.read(localCategoryStoreProvider);

    // Same names link without asking, from the phone's copy, so this works
    // while the backend is away.
    final actual = await ref.read(ledgerReportsProvider).categoryPicker(budget);
    final local = await categories.allGroups();
    final auto = autoMatchCategories(local, actual);
    final known = await categories.links(budget);
    for (final e in auto.entries) {
      if (!known.containsKey(e.key)) await categories.link(e.key, budget, e.value);
    }
    final links = await categories.links(budget);

    final views = await ledger.watchAccounts(phoneScope).first;
    final rows = [
      for (final t in await ledger.allTransactions(phoneScope))
        if (!t.deleted) t,
    ];
    return _MoveData(
      budget: budget,
      accounts: [
        for (final v in views)
          (
            id: v.account.id,
            name: v.account.name,
            balanceCents: v.balanceCents,
            transactions: rows.where((t) => t.accountId == v.account.id && !t.startingBalance).length,
            closed: v.account.closed,
          ),
      ],
      budgetAccounts: [
        for (final a in await ledger.accounts(budget))
          if (!a.closed) (id: a.id, name: a.name),
      ],
      pendingMatches: pendingCategoryMatches(
        local: local,
        links: links,
        inUse: await categories.categoriesInUse(budgetSyncId: budget),
        skipped: ref.read(settingsStoreProvider).skippedCategoryMatches(budget),
      ),
      withoutCategory: rows.where((t) => t.categoryId != null && !links.containsKey(t.categoryId)).length,
      links: links,
    );
  }

  Future<void> _matchCategories() async {
    await context.push('/match-categories');
    await _load();
  }

  Future<void> _move() async {
    final data = _data;
    if (data == null) return;
    setState(() => _moving = true);
    try {
      final result = await LedgerMove(ref.read(appDatabaseProvider))
          .intoBudget(data.budget, accounts: {for (final a in data.accounts) a.id: _targets[a.id]}, links: data.links);
      ref.read(ledgerSyncProvider.notifier).request(delay: Duration.zero);
      if (!mounted) return;
      final budgetName = ref.read(appConfigProvider).budgetName ?? 'your budget';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.transactions == 1
                ? 'One transaction is on its way to $budgetName.'
                : '${result.transactions} transactions are on their way to $budgetName.',
          ),
        ),
      );
      context.pop();
    } catch (e, st) {
      _log.error('Could not bring the accounts over', e, st);
      if (!mounted) return;
      setState(() => _moving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing was moved. See Diagnostics.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Bring accounts over')),
      body: _error != null
          ? ErrorRetry(
              title: 'Could not read the budget',
              message: 'Check the connection and try again.',
              onRetry: _load,
            )
          : data == null
          ? const SkeletonRows(count: 5)
          : _body(context, data),
    );
  }

  Widget _body(BuildContext context, _MoveData data) {
    final muted = context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant);
    final small = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final budgetName = ref.read(appConfigProvider).budgetName ?? 'your budget';
    final joining = data.accounts.any((a) => _targets[a.id] != null);
    final closed = data.accounts.any((a) => a.closed && _targets[a.id] == null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
      children: [
        Text(
          'These are kept on this phone and aren\'t in $budgetName yet. Nothing changes in Actual until you '
          'tap the button below.',
          style: muted,
        ),
        const SizedBox(height: Space.xl),
        Text('Accounts', style: context.text.titleSmall),
        const SizedBox(height: Space.sm),
        for (final a in data.accounts) ...[
          _AccountChoice(
            account: a,
            budgetAccounts: data.budgetAccounts,
            target: _targets[a.id],
            onChanged: (target) => setState(() => _targets[a.id] = target),
          ),
          const SizedBox(height: Space.md),
        ],
        if (joining) Text("An account that joins another leaves its opening balance behind.", style: small),
        if (closed) ...[
          const SizedBox(height: Space.xs),
          Text('A closed account arrives open. Close it in Actual once it has its rows.', style: small),
        ],
        const SizedBox(height: Space.xl),
        Text('Categories', style: context.text.titleSmall),
        const SizedBox(height: Space.sm),
        SettingsGroup(
          children: [
            ListTile(
              title: Text(
                data.pendingMatches == 0
                    ? 'Matched with $budgetName'
                    : '${data.pendingMatches} to match with $budgetName',
              ),
              subtitle: data.withoutCategory == 0
                  ? null
                  : Text(
                      data.withoutCategory == 1
                          ? 'One transaction would arrive without a category.'
                          : '${data.withoutCategory} transactions would arrive without a category.',
                    ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _matchCategories,
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text('Budget amounts only fill the months and categories where $budgetName has none.', style: small),
        const SizedBox(height: Space.xl),
        BusyButton(label: 'Bring them over', busy: _moving, onPressed: _moving ? null : _move),
      ],
    );
  }
}

class _AccountChoice extends StatelessWidget {
  final _PhoneAccount account;
  final List<({String id, String name})> budgetAccounts;
  final String? target;
  final ValueChanged<String?> onChanged;

  const _AccountChoice({
    required this.account,
    required this.budgetAccounts,
    required this.target,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = account.transactions == 1 ? '1 transaction' : '${account.transactions} transactions';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: Space.md),
            Text(formatBalance(account.balanceCents), style: figures(context.text.bodyMedium)),
          ],
        ),
        Text(count, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: Space.xs),
        DropdownButtonFormField<String?>(
          initialValue: target,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Goes into', labelStyle: context.text.bodySmall),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('A new account')),
            for (final b in budgetAccounts)
              DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
