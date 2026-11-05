import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/fold.dart';
import '../../../core/format/money.dart';
import '../../../core/log/app_log.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/ledger_sync_controller.dart';
import '../../../data/local/ledger_store.dart';
import '../../../data/models/actual_account.dart';
import '../../../data/models/actual_category.dart';
import '../../../data/models/quick_add.dart';
import '../../../data/providers.dart';
import '../../accounts/widgets/other_account_field.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/category_picker_sheet.dart';
import '../../../shared/widgets/inline_note.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/sheet_body.dart';
import '../bank_notifications.dart';

const _log = AppLog('bank-notifications');

/// Payees whose name contains what's typed, ignoring case and accents, those
/// starting with it first.
List<RecentPayee> matchingPayees(List<RecentPayee> payees, String typed, {int limit = 6}) {
  final query = foldAccents(typed).trim().toLowerCase();
  if (query.isEmpty) return const [];
  final matches = payees.where((p) => foldAccents(p.name).toLowerCase().contains(query)).toList();
  bool starts(RecentPayee p) => foldAccents(p.name).toLowerCase().startsWith(query);
  final ordered = [...matches.where(starts), ...matches.where((p) => !starts(p))];
  return ordered.take(limit).toList();
}

/// Turns a bank notification into a transaction: returns true once it's saved
/// or dismissed for good, false or null if it should keep waiting.
Future<bool?> showBankNotificationSheet(BuildContext context, BankNotification notification) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => BankNotificationSheet(notification: notification),
  );
}

class BankNotificationSheet extends ConsumerStatefulWidget {
  final BankNotification notification;

  const BankNotificationSheet({super.key, required this.notification});

  @override
  ConsumerState<BankNotificationSheet> createState() => _BankNotificationSheetState();
}

class _BankNotificationSheetState extends ConsumerState<BankNotificationSheet> {
  late final ParsedBankNotification _parsed = parseBankNotification(
    widget.notification.bank,
    widget.notification.title,
    widget.notification.text,
  );
  late final _amount = TextEditingController(text: _initialAmount());
  late bool _income = _parsed.income ?? false;

  String? _scope;
  List<ActualAccount> _accounts = const [];
  List<RecentPayee> _payees = const [];
  List<ActualCategoryGroup> _groups = const [];
  bool _loaded = false;

  String? _accountId;
  String _payee = '';
  String? _categoryId;
  String? _categoryName;
  Set<String> _betweenAccounts = const {};
  String? _otherAccountId;

  /// The user chose the category: a payee's suggestion no longer replaces it.
  bool _categoryChosen = false;
  bool _saving = false;
  String? _error;

  String _initialAmount() {
    final cents = _parsed.amountCents;
    return cents == null ? '' : centsToInput(cents);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = await ref.read(ledgerScopeProvider.future);
    final reports = ref.read(ledgerReportsProvider);
    final store = ref.read(ledgerStoreProvider);
    final options = await reports.quickAddOptions(scope);
    final payees = await reports.payeeHistory(scope);
    final groups = scope == phoneScope
        ? await ref.read(localCategoryStoreProvider).groups(budgetSyncId: ref.read(appConfigProvider).budgetSyncId)
        : await reports.categoryPicker(scope);
    final ledgerAccounts = await store.accounts(scope);
    final forBank = ledgerAccounts.where((a) => !a.closed && a.bankId == widget.notification.bank);
    final settings = ref.read(settingsStoreProvider);
    final last = settings.lastAccountId;
    final package = widget.notification.package;
    final appDefault = package == null ? null : settings.defaultAccountForApp(package);
    final ids = options.accounts.map((a) => a.id);
    if (!mounted) return;
    setState(() {
      _scope = scope;
      _accounts = options.accounts;
      _payees = payees;
      _betweenAccounts = options.betweenAccountsCategoryIds;
      _groups = groups;
      // A default from another budget isn't in the list: fall through.
      _accountId = ids.contains(appDefault)
          ? appDefault
          : forBank.isNotEmpty
          ? forBank.first.id
          : ids.contains(last)
          ? last
          : ids.firstOrNull;
      _loaded = true;
    });
  }

  /// Fills the category from what's known about the payee: its mapping, else
  /// what it last had. Never replaces one the user chose.
  Future<void> _suggestCategory(String payee) async {
    final scope = _scope;
    if (scope == null || _categoryChosen) return;
    final id = await ref.read(ledgerReportsProvider).suggestedCategory(scope, payee);
    if (!mounted || _categoryChosen || payee != _payee) return;
    setState(() {
      if (id != _categoryId) _otherAccountId = null;
      _categoryId = id;
      _categoryName = id == null ? null : _categoryNameOf(id);
    });
  }

  String? _categoryNameOf(String id) {
    for (final g in _groups) {
      for (final c in g.categories) {
        if (c.id == id) return c.name;
      }
    }
    return null;
  }

  void _setPayee(String name) {
    setState(() {
      _payee = name;
      _error = null;
    });
    _suggestCategory(name);
  }

  Future<void> _pickCategory() async {
    final choice = await pickCategory(context, _groups);
    if (choice == null) return;
    setState(() {
      if (choice.id != _categoryId) _otherAccountId = null;
      _categoryId = choice.id;
      _categoryName = choice.name;
      _categoryChosen = true;
    });
  }

  int? get _amountCents {
    final cents = parseAmountInput(_amount.text);
    if (cents == null) return null;
    return _income ? cents : -cents;
  }

  Future<void> _save() async {
    final amount = _amountCents;
    final accountId = _accountId;
    final scope = _scope;
    if (amount == null || accountId == null || scope == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final notification = widget.notification;
    final payee = _payee.trim();
    final categoryId = _categoryId;
    try {
      final store = ref.read(ledgerStoreProvider);
      final draft = LedgerDraft(
        date: notification.postedAt,
        amountCents: amount,
        payee: payee.isEmpty ? null : payee,
        categoryId: categoryId,
        // One per notification. `app-` as quick add: the statement that
        // shows it later is a different id, so saving it asks.
        importedId: 'app-${notification.id}',
      );
      // The other bank's notification for a move already added, say.
      final found = await store.possibleDuplicates(accountId, [draft]);
      if (found.isNotEmpty) {
        final answer = await _askIfSame(found.first.existingPayee);
        if (answer == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        if (answer) {
          await _dismiss();
          return;
        }
      }
      final other = _accounts.any((a) => a.id == _otherAccountId && a.id != accountId) ? _otherAccountId : null;
      if (other == null) {
        await store.addTransaction(accountId, draft);
      } else {
        await store.addBetweenAccounts(accountId, other, draft);
      }
      // The payee is mapped from this transaction, new or not.
      if (payee.isNotEmpty && categoryId != null) {
        final memory = ref.read(localCategoryStoreProvider);
        if (scope == phoneScope) {
          await memory.remember(payee, categoryId);
        } else {
          await memory.rememberActual(payee, scope, categoryId);
        }
        ref.read(categoryMemoryRevisionProvider.notifier).state++;
      }
      await ref.read(bankNotificationsProvider).remove(notification.id);
      ref.read(ledgerSyncProvider.notifier).request(delay: Duration.zero);
      _log.info('Notification saved as a transaction', {'account': accountId, 'mapped': categoryId != null});
      ref.invalidate(bankNotificationsWaitingProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, stack) {
      _log.error('Notification not saved', e, stack, {'account': accountId});
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the transaction on this phone.';
        });
      }
    }
  }

  /// True: it's the one already saved. False: add it. Null: backed out.
  Future<bool?> _askIfSame(String? existingPayee) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Is this already saved?'),
        content: Text(
          'This account has a transaction with the same date and amount'
          '${existingPayee == null ? '' : ': $existingPayee'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Different, add it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Same, skip it')),
        ],
      ),
    );
  }

  Future<void> _dismiss() async {
    await ref.read(bankNotificationsProvider).remove(widget.notification.id);
    ref.invalidate(bankNotificationsWaitingProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final muted = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    final source = [notification.title, notification.text].where((s) => s.trim().isNotEmpty).join(' · ');
    return SheetBody(
      title: 'Add this transaction?',
      description: '${notification.bankName}: $source',
      actions: [
        TextButton(onPressed: _saving ? null : _dismiss, child: const Text('Not a transaction')),
        BusyButton(
          label: _error == null ? 'Save' : 'Try again',
          busy: _saving,
          onPressed: _loaded && _accountId != null && _amountCents != null ? _save : null,
        ),
      ],
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Expense'), icon: Icon(Icons.remove_rounded)),
            ButtonSegment(value: true, label: Text('Income'), icon: Icon(Icons.add_rounded)),
          ],
          selected: {_income},
          onSelectionChanged: (s) => setState(() => _income = s.first),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          key: const ValueKey('bank-notification-amount'),
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: figures(context.text.headlineSmall),
          decoration: const InputDecoration(labelText: 'Amount', hintText: '0,00', suffixText: ' €'),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'Payee',
          child: Autocomplete<RecentPayee>(
            displayStringForOption: (p) => p.name,
            optionsBuilder: (value) => matchingPayees(_payees, value.text),
            onSelected: (p) => _setPayee(p.name),
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
              key: const ValueKey('bank-notification-payee'),
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Who was it?'),
              onChanged: _setPayee,
              onSubmitted: (_) => onSubmitted(),
            ),
            optionsViewBuilder: (context, onSelected, matches) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 3,
                color: context.colors.surfaceContainerHigh,
                borderRadius: Radii.controlAll,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final p in matches) ListTile(dense: true, title: Text(p.name), onTap: () => onSelected(p)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        LabeledField(
          label: 'Category',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sell_outlined),
            title: Text(_categoryName ?? 'No category'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _loaded ? _pickCategory : null,
          ),
        ),
        if (_payee.trim().isNotEmpty && _categoryId != null)
          Text('${_payee.trim()} will go to ${_categoryName ?? 'this category'} next time too.', style: muted),
        const SizedBox(height: Space.lg),
        if (_loaded && _accounts.isEmpty)
          const InlineNote(message: 'Add an account first, in Settings › Accounts.', tone: NoteTone.error)
        else
          LabeledField(
            label: 'Account',
            child: DropdownButtonFormField<String>(
              key: ValueKey(_accountId),
              initialValue: _accountId,
              isExpanded: true,
              items: [
                for (final a in _accounts)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _accountId = id),
            ),
          ),
        if (_betweenAccounts.contains(_categoryId) && _accounts.length > 1) ...[
          const SizedBox(height: Space.lg),
          OtherAccountField(
            income: _income,
            accounts: _accounts,
            accountId: _accountId,
            value: _otherAccountId,
            onChanged: (id) => setState(() => _otherAccountId = id),
          ),
        ],
        if (_error != null) ...[const SizedBox(height: Space.md), InlineNote(message: _error!, tone: NoteTone.error)],
      ],
    );
  }
}
