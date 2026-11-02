import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/log/app_log.dart';
import '../../data/models/quick_add.dart';
import '../../data/providers.dart';

const _log = AppLog('quick-add');

/// "4,50", "4.50", "1.234,56", "1,234.56", "12" → cents; null if it isn't
/// a positive amount. The sign comes from the expense/income toggle, so a
/// typed minus is ignored.
int? parseAmountInput(String input) {
  var text = input.trim().replaceAll(RegExp(r'[\s€+\-−]'), '');
  if (text.isEmpty) return null;
  final lastComma = text.lastIndexOf(',');
  final lastDot = text.lastIndexOf('.');
  // Whichever separator comes last is the decimal one, if it has 1-2
  // digits after it; the other is a thousands separator.
  final decimalAt = max(lastComma, lastDot);
  String whole = text;
  String fraction = '';
  if (decimalAt >= 0 && text.length - decimalAt - 1 <= 2) {
    whole = text.substring(0, decimalAt);
    fraction = text.substring(decimalAt + 1);
  }
  // Separators left in the whole part must group thousands: "1.234", not "4,5".
  if (whole.contains(RegExp(r'[.,]')) && !RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(whole)) return null;
  whole = whole.replaceAll(RegExp(r'[.,]'), '');
  if (!RegExp(r'^\d*$').hasMatch(whole) || !RegExp(r'^\d{0,2}$').hasMatch(fraction)) return null;
  if (whole.isEmpty && fraction.isEmpty) return null;
  final cents = int.parse(whole.isEmpty ? '0' : whole) * 100 + int.parse(fraction.padRight(2, '0'));
  return cents > 0 ? cents : null;
}

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
  }) {
    return QuickAddState(
      amountText: amountText ?? this.amountText,
      income: income ?? this.income,
      payee: payee ?? this.payee,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      categoryChosen: categoryChosen ?? this.categoryChosen,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
      clientId: clientId,
    );
  }
}

/// GET /quick-add/options for the active budget.
final quickAddOptionsProvider = FutureProvider.autoDispose<QuickAddOptions>((ref) {
  final budgetSyncId = ref.watch(appConfigProvider.select((c) => c.budgetSyncId));
  return ref.watch(importerApiProvider).getQuickAddOptions(budgetSyncId: budgetSyncId);
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

  void setDate(DateTime date) => state = state.copyWith(date: date, clearError: true);

  void setNotes(String notes) => state = state.copyWith(notes: notes);

  /// Adds the transaction. On failure the form keeps everything (and the
  /// same clientId), so trying again can't create a duplicate.
  Future<bool> save() async {
    final amountCents = state.amountCents;
    final accountId = state.accountId;
    if (amountCents == null || accountId == null || state.saving) return false;
    state = state.copyWith(saving: true, clearError: true);
    final config = ref.read(appConfigProvider);
    try {
      final password = config.budgetSyncId == null
          ? null
          : await ref.read(secretStoreProvider).budgetPassword(config.budgetSyncId!);
      final result = await ref.read(importerApiProvider).addTransaction(
            accountId: accountId,
            date: state.date,
            amountCents: amountCents,
            clientId: state.clientId,
            payeeName: state.payee.trim().isEmpty ? null : state.payee.trim(),
            categoryId: state.categoryId,
            notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
            budgetSyncId: config.budgetSyncId,
            budgetPassword: password,
          );
      _log.info('Transaction saved', {'accountId': accountId, 'id': result.id, 'created': result.created});
      await ref.read(settingsStoreProvider).setLastAccountId(accountId);
      ref.invalidate(dashboardProvider);
      ref.invalidate(budgetMonthProvider);
      state = state.copyWith(saving: false);
      return true;
    } on ApiException catch (e) {
      _log.warn('Transaction not saved', {'code': e.code, 'status': e.statusCode});
      state = state.copyWith(saving: false, error: e.message);
      return false;
    }
  }
}

final quickAddControllerProvider =
    AutoDisposeNotifierProvider<QuickAddController, QuickAddState>(QuickAddController.new);
