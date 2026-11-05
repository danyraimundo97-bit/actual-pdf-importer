/// GET /accounts/:id/transactions: one account's balance and a page of its
/// transactions, newest first. Money in integer cents, negative = outflow.
class AccountPage {
  final String accountId;
  final String accountName;
  final bool offbudget;
  final int balanceCents;
  final List<AccountTransaction> transactions;

  /// Pass back as `before` for the next page; null on the last one.
  final String? nextCursor;

  const AccountPage({
    required this.accountId,
    required this.accountName,
    required this.offbudget,
    required this.balanceCents,
    required this.transactions,
    this.nextCursor,
  });

  factory AccountPage.fromJson(Map<String, dynamic> json) {
    final account = json['account'] as Map<String, dynamic>;
    return AccountPage(
      accountId: account['id'] as String,
      accountName: account['name'] as String,
      offbudget: account['offbudget'] as bool? ?? false,
      balanceCents: account['balanceCents'] as int,
      transactions: (json['transactions'] as List)
          .cast<Map<String, dynamic>>()
          .map(AccountTransaction.fromJson)
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class AccountTransaction {
  final String id;
  final DateTime date;
  final int amountCents;
  final String? payee;
  final String? category;
  final String? categoryEmoji;
  final String? notes;
  final bool transfer;
  final bool cleared;

  /// Set when the row comes from a list spanning several accounts.
  final String? accountName;
  final List<({int amountCents, String? category})> splits;

  /// The account's opening balance (the phone's ledger marks it; it's
  /// changed in Settings › Accounts, not here).
  final bool openingBalance;

  const AccountTransaction({
    required this.id,
    required this.date,
    required this.amountCents,
    this.payee,
    this.category,
    this.categoryEmoji,
    this.notes,
    this.transfer = false,
    this.cleared = false,
    this.accountName,
    this.splits = const [],
    this.openingBalance = false,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic> json) => AccountTransaction(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        amountCents: json['amountCents'] as int,
        payee: json['payee'] as String?,
        category: json['category'] as String?,
        notes: json['notes'] as String?,
        transfer: json['transfer'] as bool? ?? false,
        cleared: json['cleared'] as bool? ?? false,
        splits: (json['splits'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map((s) => (amountCents: s['amountCents'] as int, category: s['category'] as String?))
            .toList(),
      );
}

/// Which of a month's transactions to show: all, or just what makes up
/// Home's In or Out bar.
enum MonthFlowFilter {
  all,
  income,
  spending;

  static MonthFlowFilter parse(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => MonthFlowFilter.all);
}

/// Every transaction of one month, across accounts. Totals as Home counts
/// them: on-budget accounts, without transfers or opening balances.
class MonthTransactions {
  final String month;
  final int incomeCents;
  final int spendingCents;
  final List<AccountTransaction> transactions;

  /// The rows behind each total. A split with parts on both sides is in both.
  final Set<String> incomeIds;
  final Set<String> spendingIds;

  /// Category id → row id → how much of that row is in the category: the whole
  /// row, or the matching parts of a split.
  final Map<String, Map<String, int>> categoryCents;

  const MonthTransactions({
    required this.month,
    required this.incomeCents,
    required this.spendingCents,
    required this.transactions,
    this.incomeIds = const {},
    this.spendingIds = const {},
    this.categoryCents = const {},
  });

  /// A category's rows, each showing only its share, so they add up to the
  /// category's figure in the budget.
  List<AccountTransaction> rowsInCategory(String categoryId) {
    final shares = categoryCents[categoryId] ?? const <String, int>{};
    return [
      for (final t in transactions)
        if (shares[t.id] case final cents?)
          AccountTransaction(
            id: t.id,
            date: t.date,
            amountCents: cents,
            payee: t.payee,
            openingBalance: t.openingBalance,
            category: t.category,
            categoryEmoji: t.categoryEmoji,
            notes: t.notes,
            transfer: t.transfer,
            cleared: t.cleared,
            accountName: t.accountName,
            splits: t.splits,
          ),
    ];
  }

  List<AccountTransaction> rows(MonthFlowFilter filter) => switch (filter) {
    MonthFlowFilter.all => transactions,
    MonthFlowFilter.income => [
      for (final t in transactions)
        if (incomeIds.contains(t.id)) t,
    ],
    MonthFlowFilter.spending => [
      for (final t in transactions)
        if (spendingIds.contains(t.id)) t,
    ],
  };
}
