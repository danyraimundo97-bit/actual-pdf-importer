/// Mirrors the backend's GET /dashboard response. All money is integer
/// cents, negative = outflow, like everywhere else in the API.
class Dashboard {
  final int netWorthCents;
  final List<DashboardAccount> accounts;
  final List<MonthFlow> months;
  final List<CategorySpend> topCategories;
  final List<PayeeSpend> topPayees;
  final int uncategorizedCount;
  final List<RecentTransaction> recent;

  const Dashboard({
    required this.netWorthCents,
    required this.accounts,
    required this.months,
    required this.topCategories,
    required this.topPayees,
    required this.uncategorizedCount,
    required this.recent,
  });

  /// The newest month's flows (the backend always sends at least one).
  MonthFlow? get currentMonth => months.isEmpty ? null : months.last;

  bool get isEmpty => recent.isEmpty && accounts.every((a) => a.balanceCents == 0);

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List? ?? const []).cast<Map<String, dynamic>>().map(parse).toList();

    return Dashboard(
      netWorthCents: json['netWorthCents'] as int,
      accounts: list('accounts', DashboardAccount.fromJson),
      months: list('months', MonthFlow.fromJson),
      topCategories: list('topCategories', CategorySpend.fromJson),
      topPayees: list('topPayees', PayeeSpend.fromJson),
      uncategorizedCount: json['uncategorizedCount'] as int,
      recent: list('recent', RecentTransaction.fromJson),
    );
  }
}

class DashboardAccount {
  final String id;
  final String name;
  final bool offbudget;
  final int balanceCents;

  const DashboardAccount({
    required this.id,
    required this.name,
    required this.offbudget,
    required this.balanceCents,
  });

  factory DashboardAccount.fromJson(Map<String, dynamic> json) => DashboardAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    offbudget: json['offbudget'] as bool,
    balanceCents: json['balanceCents'] as int,
  );
}

class MonthFlow {
  /// "YYYY-MM".
  final String month;
  final int incomeCents;

  /// Positive: money that left on-budget accounts.
  final int spendingCents;

  const MonthFlow({required this.month, required this.incomeCents, required this.spendingCents});

  int get netCents => incomeCents - spendingCents;

  factory MonthFlow.fromJson(Map<String, dynamic> json) => MonthFlow(
    month: json['month'] as String,
    incomeCents: json['incomeCents'] as int,
    spendingCents: json['spendingCents'] as int,
  );
}

class CategorySpend {
  final String? categoryId;
  final String name;
  final int spendingCents;

  const CategorySpend({this.categoryId, required this.name, required this.spendingCents});

  factory CategorySpend.fromJson(Map<String, dynamic> json) => CategorySpend(
    categoryId: json['categoryId'] as String?,
    name: json['name'] as String,
    spendingCents: json['spendingCents'] as int,
  );
}

class PayeeSpend {
  final String name;
  final int spendingCents;
  final int count;

  const PayeeSpend({required this.name, required this.spendingCents, required this.count});

  factory PayeeSpend.fromJson(Map<String, dynamic> json) => PayeeSpend(
    name: json['name'] as String,
    spendingCents: json['spendingCents'] as int,
    count: json['count'] as int,
  );
}

class RecentTransaction {
  final String id;
  final DateTime date;
  final int amountCents;
  final String? payee;
  final String? category;
  final String account;

  const RecentTransaction({
    required this.id,
    required this.date,
    required this.amountCents,
    this.payee,
    this.category,
    required this.account,
  });

  factory RecentTransaction.fromJson(Map<String, dynamic> json) => RecentTransaction(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    amountCents: json['amountCents'] as int,
    payee: json['payee'] as String?,
    category: json['category'] as String?,
    account: json['account'] as String,
  );
}
