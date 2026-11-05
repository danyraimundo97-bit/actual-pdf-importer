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
