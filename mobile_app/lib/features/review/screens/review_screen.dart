import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/format/banks.dart';
import '../../../core/format/dates.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../data/local/db/app_database.dart';
import '../../../data/local/db/local_category_store.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/import_result.dart';
import '../../../data/models/parsed_transaction.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../accounts/widgets/account_sheet.dart';
import '../../categories/category_matching.dart';
import '../csv_export.dart';
import '../phone_save.dart';
import '../widgets/duplicates_sheet.dart';
import '../widgets/import_result_sheet.dart';
import '../widgets/save_into_sheet.dart';
import '../widgets/transaction_edit_sheet.dart';
import '../widgets/transaction_row.dart';
import 'review_screen_args.dart';
import '../../../core/log/app_log.dart';

const _log = AppLog('import');

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

  /// Saving into the phone's own accounts (Actual not connected).
  bool get _onPhone => widget.args.saveOnPhone && widget.args.account == null;
  List<LedgerAccount> _ledgerAccounts = const [];
  LedgerAccount? _ledgerAccount;
  bool _ledgerLoaded = false;

  @override
  void initState() {
    super.initState();
    final parsed = widget.args.parseResult;
    // Read while Actual wasn't connected: those suggestions are the app's own
    // categories, which Actual can't resolve. They're held back here and come
    // back as their linked Actual category once Actual's categories load
    // ("Match your categories"); unlinked ones stay off.
    _transactions = widget.args.account != null && parsed.localCategories
        ? [for (final t in parsed.transactions) t.withoutSuggestion()]
        : List.of(parsed.transactions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      if (_onPhone) _loadLedgerAccounts();
    });
  }

  /// The phone's open accounts, with the suggested one chosen ([select]
  /// wins, for an account just added here).
  Future<void> _loadLedgerAccounts({String? select}) async {
    final views = await ref.read(ledgerStoreProvider).watchAccounts(phoneScope).first;
    final open = [
      for (final v in views)
        if (!v.account.closed) v.account,
    ];
    final bankId = widget.args.parseResult.bankId;
    final lastUsed = select ?? ref.read(settingsStoreProvider).lastLedgerAccountFor(bankId);
    if (!mounted) return;
    setState(() {
      _ledgerAccounts = open;
      _ledgerAccount = suggestLedgerAccount(open, bankId: bankId, lastUsedId: lastUsed);
      _ledgerLoaded = true;
    });
  }

  Future<void> _chooseLedgerAccount() async {
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SaveIntoSheet(accounts: _ledgerAccounts, selected: _ledgerAccount),
    );
    if (!mounted) return;
    if (chosen is LedgerAccount) {
      setState(() => _ledgerAccount = chosen);
    } else if (chosen == SaveIntoSheet.newAccount) {
      final edit = await showAccountSheet(context);
      if (edit == null) return;
      final id = await ref
          .read(ledgerStoreProvider)
          .createAccount(
            phoneScope,
            name: edit.name,
            offBudget: edit.offBudget,
            openingBalanceCents: edit.balanceCents,
            bankId: widget.args.parseResult.bankId,
          );
      _log.info('Account added', {'account': id});
      await _loadLedgerAccounts(select: id);
    }
  }

  /// Asks about lines with the same date and amount as a transaction the
  /// account already has. What's left to save, or null if the user backed out.
  Future<List<ParsedTransaction>?> _withoutDuplicates(String accountId, List<ParsedTransaction> included) async {
    final found = await ref.read(ledgerStoreProvider).possibleDuplicates(accountId, statementDrafts(included));
    if (found.isEmpty) return included;
    if (!mounted) return null;
    final same = await showDuplicatesSheet(
      context,
      [for (final d in found) (index: d.line, line: included[d.line], existingPayee: d.existingPayee)],
    );
    if (same == null) return null;
    _log.info('Possible duplicates answered', {'found': found.length, 'skipped': same.length});
    return [
      for (final (i, t) in included.indexed)
        if (!same.contains(i)) t,
    ];
  }

  /// Saves the selected lines into the chosen phone account. Lines the
  /// account already has (same importedId) are skipped, so saving a
  /// statement twice adds nothing.
  Future<void> _saveOnPhone() async {
    final account = _ledgerAccount;
    final included = _transactions.where((t) => t.include).toList();
    if (account == null || included.isEmpty) return;
    setState(() => _importing = true);
    try {
      final store = ref.read(ledgerStoreProvider);
      final bankId = widget.args.parseResult.bankId;
      final toSave = await _withoutDuplicates(account.id, included);
      if (toSave == null) return;
      final saved = await store.addStatement(account.id, statementDrafts(toSave));
      if (account.bankId == null) await store.updateAccount(account.id, bankId: bankId);
      await ref.read(settingsStoreProvider).setLastLedgerAccountFor(bankId, account.id);
      await _rememberLocally(included);
      var categorized = 0;
      for (final id in saved.ids) {
        if ((await store.transaction(id))?.categoryId != null) categorized++;
      }
      _log.info('Statement saved on the phone', {
        'account': account.id,
        'added': saved.added,
        'skipped': saved.skipped,
      });
      final result = ImportResult(
        added: saved.added,
        updated: saved.skipped + included.length - toSave.length,
        categorized: categorized,
        addedIds: saved.ids,
        phoneAccount: (id: account.id, name: account.name),
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => ImportResultSheet(result: result, editedPayees: const [], transactions: _transactions),
      );
      if (mounted) context.pop(result);
    } catch (e, stack) {
      _log.error('Saving the statement on the phone failed', e, stack, {'account': account.id});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save the transactions on this phone.')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _loadCategories() async {
    // Without an account there's no Actual: the app's own categories.
    if (widget.args.account == null) {
      final groups = await ref.read(localCategoryStoreProvider).groups(budgetSyncId: widget.args.budgetSyncId);
      if (mounted) setState(() => _categoryGroups = groups);
      return;
    }
    try {
      final groups = await ref
          .read(importerApiProvider)
          .getActualCategories(budgetSyncId: widget.args.budgetSyncId);
      final linked = await _linkedSuggestions(groups);
      if (!mounted) return;
      setState(() {
        _categoryGroups = groups;
        for (final (i, t) in linked.indexed) {
          final current = _transactions[i];
          if (t.suggestedCategoryId == null || current.suggestedCategoryId != null) continue;
          if (current.overrideCategoryId != null) continue;
          _transactions[i] = current.copyWith(
            suggestedCategoryId: t.suggestedCategoryId,
            suggestedCategoryName: t.suggestedCategoryName,
            suggestedFromHint: t.suggestedFromHint,
          );
        }
      });
    } on ApiException {
      // The review screen still works without categories loaded — the
      // category picker just won't have anything to offer yet.
    }
  }

  /// The statement's local suggestions as their linked Actual categories,
  /// line by line (empty when there's nothing to map).
  String? _categoryEmoji(String? id) {
    for (final g in _categoryGroups) {
      for (final c in g.categories) {
        if (c.id == id) return c.emoji;
      }
    }
    return null;
  }

  Future<List<ParsedTransaction>> _linkedSuggestions(List<ActualCategoryGroup> groups) async {
    final parsed = widget.args.parseResult;
    final budgetSyncId = widget.args.budgetSyncId;
    if (!parsed.localCategories || budgetSyncId == null) return const [];
    final links = await ref.read(localCategoryStoreProvider).links(budgetSyncId);
    if (links.isEmpty) return const [];
    final names = actualCategoryNames(groups);
    return [for (final t in parsed.transactions) toActualCategories(t, links: links, actualNames: names)];
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
    _updateTransaction(
      index,
      _transactions[index].copyWith(include: !_transactions[index].include),
    );
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

  /// Shares the selected lines as a CSV. Built in memory; the share sheet
  /// may stage it in the app's cache to hand it over, and the app keeps no
  /// copy of its own.
  Future<void> _exportCsv() async {
    final included = _transactions.where((t) => t.include).toList();
    if (included.isEmpty) return;
    final first = included.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final last = included.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final name = '${widget.args.parseResult.bankId}-${_day(first)}-to-${_day(last)}.csv';
    _log.info('CSV exported', {'bank': widget.args.parseResult.bankId, 'transactions': included.length});
    await _rememberLocally(included);
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Transactions',
        files: [XFile.fromData(csvBytes(transactionsToCsv(included)), name: name, mimeType: 'text/csv')],
        fileNameOverrides: [name],
      ),
    );
  }

  /// Exporting is this path's "import": like the backend does on import,
  /// the phone remembers each category the user picked or accepted from a
  /// hint, so the next statement suggests it.
  Future<void> _rememberLocally(List<ParsedTransaction> included) async {
    final store = ref.read(localCategoryStoreProvider);
    var remembered = 0;
    for (final t in included) {
      final id = t.effectiveCategoryId;
      if (id == null || !LocalCategoryStore.isLocalId(id)) continue;
      if (t.overrideCategoryId == null && !t.showsHint) continue;
      await store.remember(t.payee, id, budgetSyncId: widget.args.budgetSyncId);
      remembered++;
    }
    if (remembered > 0) {
      _log.info('Categories remembered on the phone', {'mappings': remembered});
      ref.read(categoryMemoryRevisionProvider.notifier).state++;
    }
  }

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _confirmImport() async {
    final account = widget.args.account;
    final included = _transactions.where((t) => t.include).toList();
    if (included.isEmpty || account == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import ${included.length} transaction${included.length == 1 ? '' : 's'}?'),
        content: Text(
          'They will be added to "${account.name}". '
          'Lines already in Actual are matched, not duplicated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    _log.info('Import confirmed', {'accountId': account.id, 'transactions': included.length});
    try {
      // Into the phone's copy of the budget first; the sync takes it to Actual.
      final store = ref.read(ledgerStoreProvider);
      final budgetSyncId = widget.args.budgetSyncId;
      if (budgetSyncId != null) await ref.read(ledgerSyncProvider.notifier).ensurePulled(budgetSyncId);
      final toSave = await _withoutDuplicates(account.id, included);
      if (toSave == null) return;
      final saved = await store.addTransactions(account.id, statementDrafts(toSave, keepLines: true));
      var categorized = 0;
      for (final id in saved.ids) {
        if ((await store.transaction(id))?.categoryId != null) categorized++;
      }
      _log.info('Statement saved for Actual', {
        'accountId': account.id,
        'added': saved.added,
        'skipped': saved.skipped,
      });
      ref.read(ledgerSyncProvider.notifier).request(delay: Duration.zero);
      final result = ImportResult(
        added: saved.added,
        updated: saved.skipped + included.length - toSave.length,
        categorized: categorized,
        addedIds: saved.ids,
        inLedger: true,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => ImportResultSheet(
          result: result,
          editedPayees: _editedPayees.toList(),
          transactions: _transactions,
          budgetSyncId: widget.args.budgetSyncId,
        ),
      );
      // Hand the result back to the inbox, which marks the statement imported.
      if (mounted) context.pop(result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e, stack) {
      _log.error('Saving the statement for Actual failed', e, stack, {'accountId': account.id});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not save the transactions on this phone.')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Rows interleaved with a header wherever the date changes, so the date
  /// is read once per day instead of once per line. Statement order is kept.
  List<_ListEntry> _buildEntries() {
    final entries = <_ListEntry>[];
    DateTime? lastDate;
    for (var i = 0; i < _transactions.length; i++) {
      final date = _transactions[i].date;
      if (date != lastDate) {
        entries.add(_ListEntry.header(date));
        lastDate = date;
      }
      entries.add(_ListEntry.row(i));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final count = _includedCount;

    if (_transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No transactions found',
          message:
              'The statement was read, but no transaction lines were found in it. '
              'Check that it covers a period with activity.',
          actionLabel: 'Choose another statement',
          onAction: () => context.pop(),
        ),
      );
    }

    final entries = _buildEntries();
    final canImport = args.account != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          if (canImport || _onPhone)
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: count > 0 ? _exportCsv : null,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ReviewHeader(
              bankName: bankDisplayName(args.parseResult.bankId),
              accountName: args.account?.name,
              totalCents: _totalCents,
              includedCount: count,
              totalCount: _transactions.length,
              categorizedCount: _categorizedCount,
            ),
          ),
          if (_onPhone)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
                child: LabeledField(
                  label: 'Save into',
                  child: _ledgerLoaded
                      ? PickerField(
                          leadingIcon: Icons.account_balance_outlined,
                          value: _ledgerAccount?.name ?? 'Choose an account',
                          isPlaceholder: _ledgerAccount == null,
                          onTap: _chooseLedgerAccount,
                        )
                      : const Skeleton(height: 52, radius: Radii.control),
                ),
              ),
            ),
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final index = entry.index;
              if (index == null) return _DateHeader(date: entry.date!);
              return TransactionRow(
                transaction: _transactions[index],
                categoryEmoji: _categoryEmoji(_transactions[index].effectiveCategoryId),
                onTap: () => _editTransaction(index),
                onToggleInclude: () => _toggleInclude(index),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
            child: _onPhone
                ? BusyButton(
                    label: switch ((count, _ledgerAccount)) {
                      (0, _) => 'Nothing selected',
                      (_, null) => 'Choose an account to save into',
                      _ => 'Save $count transaction${count == 1 ? '' : 's'}',
                    },
                    busy: _importing,
                    onPressed: count > 0 && _ledgerAccount != null ? _saveOnPhone : null,
                  )
                : canImport
                ? BusyButton(
                    label: count == 0 ? 'Nothing selected' : 'Import $count transaction${count == 1 ? '' : 's'}',
                    busy: _importing,
                    onPressed: count > 0 ? _confirmImport : null,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const InlineNote(
                        message:
                            'Connect Actual to import these. Until then you can export them as a CSV, '
                            "which Actual's web app or a spreadsheet can open.",
                      ),
                      const SizedBox(height: Space.md),
                      FilledButton.icon(
                        onPressed: count > 0 ? _exportCsv : null,
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(count == 0 ? 'Nothing selected' : 'Export $count as CSV'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ListEntry {
  final DateTime? date;
  final int? index;

  const _ListEntry.header(DateTime this.date) : index = null;
  const _ListEntry.row(int this.index) : date = null;
}

class _ReviewHeader extends StatelessWidget {
  final String bankName;

  /// Null without an account to import into.
  final String? accountName;
  final int totalCents;
  final int includedCount;
  final int totalCount;
  final int categorizedCount;

  const _ReviewHeader({
    required this.bankName,
    required this.accountName,
    required this.totalCents,
    required this.includedCount,
    required this.totalCount,
    required this.categorizedCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant);
    final uncategorized = includedCount - categorizedCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(accountName == null ? '$bankName statement' : '$bankName statement into $accountName', style: muted),
          const SizedBox(height: Space.sm),
          Semantics(
            label: 'Net total of selected transactions',
            child: Text(
              formatCents(totalCents),
              // Display size reads better in the sans than in mono; tabular
              // figures keep the digits steady as rows are toggled.
              style: context.text.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text('$includedCount of $totalCount selected', style: muted),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Icon(
                uncategorized == 0 ? Icons.check_circle_outline_rounded : Icons.sell_outlined,
                size: 18,
                color: uncategorized == 0 ? context.tokens.inflow : colors.primary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  uncategorized == 0
                      ? 'Every selected line has a category.'
                      : '$uncategorized without a category. Tap a line to set one.',
                  style: context.text.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
      child: Text(
        formatDisplayDate(date),
        style: figures(context.text.labelMedium).copyWith(color: context.colors.onSurfaceVariant),
      ),
    );
  }
}
