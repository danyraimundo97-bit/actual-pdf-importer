import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/money.dart';
import '../../core/log/app_log.dart';
import '../../data/local/db/local_category_store.dart';
import '../../data/local/ledger_store.dart';
import '../../data/models/quick_add.dart';
import '../../data/ledger_sync_controller.dart';
import '../../data/providers.dart';

export '../../core/format/money.dart' show parseAmountInput;

const _log = AppLog('quick-add');

final _random = Random.secure();

/// UUID v4: the idempotency key for one quick-add form.
String newClientId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

class QuickAddState {
  final String amountText;
  final bool income;
  final String payee;
  final String? categoryId;
  final String? categoryName;

  /// True once the user picked a category themselves: a payee suggestion
  /// then no longer overwrites it.
  final bool categoryChosen;
  final String? accountId;

  /// The other side, for money between your own accounts. Optional.
  final String? otherAccountId;
  final String? otherAccountName;
  final DateTime date;
  final String notes;
  final bool saving;
  final String? error;

  /// Generated once per form and reused by every save attempt, so a retry
  /// after a lost response can't add the transaction twice.
  final String clientId;

  const QuickAddState({
    this.amountText = '',
    this.income = false,
    this.payee = '',
    this.categoryId,
    this.categoryName,
    this.categoryChosen = false,
    this.accountId,
    this.otherAccountId,
    this.otherAccountName,
    required this.date,
    this.notes = '',
    this.saving = false,
    this.error,
    required this.clientId,
  });

  int? get amountCents {
    final cents = parseAmountInput(amountText);
    if (cents == null) return null;
    return income ? cents : -cents;
  }

  bool get canSave => amountCents != null && accountId != null && !saving;

  QuickAddState copyWith({
    String? amountText,
    bool? income,
    String? payee,
    String? categoryId,
    String? categoryName,
    bool? categoryChosen,
    String? accountId,
    DateTime? date,
    String? notes,
    bool? saving,
    String? error,
    bool clearCategory = false,
    bool clearError = false,
    String? otherAccountId,
    String? otherAccountName,
    bool clearOtherAccount = false,
  }) {
    final categoryChanged = clearCategory || (categoryId != null && categoryId != this.categoryId);
    final dropOther = clearOtherAccount || categoryChanged || (accountId != null && accountId == this.otherAccountId);
    return QuickAddState(
      amountText: amountText ?? this.amountText,
      income: income ?? this.income,
      payee: payee ?? this.payee,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      categoryChosen: categoryChosen ?? this.categoryChosen,
      accountId: accountId ?? this.accountId,
      otherAccountId: dropOther ? otherAccountId : (otherAccountId ?? this.otherAccountId),
      otherAccountName: dropOther ? otherAccountName : (otherAccountName ?? this.otherAccountName),
      date: date ?? this.date,
      notes: notes ?? this.notes,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      clientId: clientId,
    );
  }
}

/// The form's choices, from the ledger: the phone's own budget, or the copy
/// of an Actual one, so adding works with no connection.
final quickAddOptionsProvider = FutureProvider.autoDispose<QuickAddOptions>((ref) async {
  final scope = await ref.watch(ledgerScopeProvider.future);
  if (scope != phoneScope) await ref.read(ledgerSyncProvider.notifier).ensurePulled(scope);
  return ref.watch(ledgerReportsProvider).quickAddOptions(scope);
});

class QuickAddController extends AutoDisposeNotifier<QuickAddState> {
  DateTime Function() now = DateTime.now;

  @override
  QuickAddState build() {
    final today = now();
    return QuickAddState(date: DateTime(today.year, today.month, today.day), clientId: newClientId());
  }

  /// Picks the account once the options are in: the last one used, if it's
  /// still there, else the first (on-budget accounts come first).
  void applyOptions(QuickAddOptions options) {
    if (state.accountId != null || options.accounts.isEmpty) return;
    final last = ref.read(settingsStoreProvider).lastAccountId;
    final match = options.accounts.where((a) => a.id == last);
    state = state.copyWith(accountId: match.isNotEmpty ? match.first.id : options.accounts.first.id);
  }

  void setAmount(String text) => state = state.copyWith(amountText: text, clearError: true);

  void setIncome(bool income) {
    if (income == state.income) return;
    // An expense category makes no sense on income (and the reverse).
    state = state.copyWith(income: income, categoryChosen: false, clearCategory: true, clearError: true);
  }

  /// Sets the payee; a known payee pre-fills the category it last had,
  /// unless the user already chose one.
  void setPayee(String name, {QuickAddOptions? options}) {
    var next = state.copyWith(payee: name, clearError: true);
    if (!state.categoryChosen && options != null) {
      final known = options.recentPayees.where((p) => p.name.toLowerCase() == name.trim().toLowerCase());
      final categoryId = known.isEmpty ? null : known.first.lastCategoryId;
      final categoryName = options.categoryName(categoryId);
      next = categoryName == null
          ? next.copyWith(clearCategory: true)
          : next.copyWith(categoryId: categoryId, categoryName: categoryName);
    }
    state = next;
  }

  void setCategory(String id, String name) =>
      state = state.copyWith(categoryId: id, categoryName: name, categoryChosen: true, clearError: true);

  void setAccount(String id) => state = state.copyWith(accountId: id, clearError: true);

  void setOtherAccount(String? id, String? name) => state = id == null
      ? state.copyWith(clearOtherAccount: true)
      : state.copyWith(otherAccountId: id, otherAccountName: name);

  void setDate(DateTime date) => state = state.copyWith(date: date, clearError: true);

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  /// Adds the transaction to the ledger; the sync takes it to Actual when
  /// there is one. On failure the form keeps everything, and the same
  /// clientId means trying again can't add it twice.
  Future<bool> save() async {
    final amountCents = state.amountCents;
    final accountId = state.accountId;
    if (amountCents == null || accountId == null || state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    final payee = state.payee.trim();
    final categoryId = state.categoryId;
    final store = ref.read(ledgerStoreProvider);
    try {
      final draft = LedgerDraft(
          date: state.date,
          amountCents: amountCents,
          payee: payee.isEmpty ? null : payee,
          categoryId: categoryId,
          notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
          importedId: 'app-${state.clientId}',
      );
      final other = state.otherAccountId;
      final id = other == null
          ? await store.addTransaction(accountId, draft)
          : await store.addBetweenAccounts(accountId, other, draft);
      _log.info('Transaction saved', {'accountId': accountId, 'id': id, 'created': id != null});
      await ref.read(settingsStoreProvider).setLastAccountId(accountId);
      // With Actual the backend learns this when the row arrives; here it's
      // the phone's own memory.
      if (payee.isNotEmpty && categoryId != null && LocalCategoryStore.isLocalId(categoryId)) {
        await ref.read(localCategoryStoreProvider).remember(payee, categoryId);
        ref.read(categoryMemoryRevisionProvider.notifier).state++;
      }
      ref.read(ledgerSyncProvider.notifier).request(delay: Duration.zero);
      state = state.copyWith(saving: false);
      return true;
    } catch (e, stack) {
      _log.error('Transaction not saved', e, stack, {'accountId': accountId});
      state = state.copyWith(saving: false, error: 'Could not save the transaction on this phone.');
      return false;
    }
  }
}

final quickAddControllerProvider =
    AutoDisposeNotifierProvider<QuickAddController, QuickAddState>(QuickAddController.new);
