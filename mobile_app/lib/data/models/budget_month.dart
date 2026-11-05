/// GET /budget-month: budgeted, spent and left per category for one month.
/// Integer cents; `spentCents` is negative when money went out (Actual's
/// sign), `balanceCents` negative = overspent.
class BudgetMonth {
  final String month; // YYYY-MM
  final String firstMonth;
  final String lastMonth;
  final int toBudgetCents;
  final int totalBudgetedCents;
  final int totalSpentCents;
  final int totalBalanceCents;
  final int incomeCents;
  final List<BudgetGroup> groups;
  final List<({String id, String name, int receivedCents, String? emoji})> income;

  const BudgetMonth({
    required this.month,
    required this.firstMonth,
    required this.lastMonth,
    required this.toBudgetCents,
    required this.totalBudgetedCents,
    required this.totalSpentCents,
    required this.totalBalanceCents,
    required this.incomeCents,
    required this.groups,
    required this.income,
  });

  factory BudgetMonth.fromJson(Map<String, dynamic> json) => BudgetMonth(
        month: json['month'] as String,
        firstMonth: json['firstMonth'] as String,
        lastMonth: json['lastMonth'] as String,
        toBudgetCents: json['toBudgetCents'] as int,
        totalBudgetedCents: json['totalBudgetedCents'] as int,
        totalSpentCents: json['totalSpentCents'] as int,
        totalBalanceCents: json['totalBalanceCents'] as int,
        incomeCents: json['incomeCents'] as int,
        groups: (json['groups'] as List).cast<Map<String, dynamic>>().map(BudgetGroup.fromJson).toList(),
        income: (json['income'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map((i) => (id: i['id'] as String, name: i['name'] as String, receivedCents: i['receivedCents'] as int, emoji: null))
            .toList(),
      );
}

class BudgetGroup {
  final String id;
  final String name;
  final int budgetedCents;
  final int spentCents;
  final int balanceCents;
  final List<BudgetCategory> categories;

  const BudgetGroup({
    required this.id,
    required this.name,
    required this.budgetedCents,
    required this.spentCents,
    required this.balanceCents,
    required this.categories,
  });

  factory BudgetGroup.fromJson(Map<String, dynamic> json) => BudgetGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        budgetedCents: json['budgetedCents'] as int,
        spentCents: json['spentCents'] as int,
        balanceCents: json['balanceCents'] as int,
        categories: (json['categories'] as List).cast<Map<String, dynamic>>().map(BudgetCategory.fromJson).toList(),
      );
}

class BudgetCategory {
  final String id;
  final String name;
  final int budgetedCents;
  final int spentCents;
  final int balanceCents;
  final bool carryover;
  final String? emoji;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.budgetedCents,
    required this.spentCents,
    required this.balanceCents,
    this.carryover = false,
    this.emoji,
  });

  bool get overspent => balanceCents < 0;

  /// How much of what was available has been spent, 0..1 (1 when overspent
  /// or when nothing was available but something was spent).
  double get usedFraction {
    final spent = -spentCents;
    final available = spent + balanceCents; // what there was to spend this month
    if (spent <= 0) return 0;
    if (available <= 0) return 1;
    return (spent / available).clamp(0, 1).toDouble();
  }

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        budgetedCents: json['budgetedCents'] as int,
        spentCents: json['spentCents'] as int,
        balanceCents: json['balanceCents'] as int,
        carryover: json['carryover'] as bool? ?? false,
      );
}
