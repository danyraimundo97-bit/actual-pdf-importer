import '../models/budget_month.dart';
import '../models/dashboard.dart';
import 'db/app_database.dart';

// Home and Budget from the local ledger (docs/plans/local-ledger.md,
// Phase 4). Pure functions over rows, so the arithmetic is tested without a
// database. `buildLedgerDashboard` follows the backend's `buildDashboard`
// (backend_app/src/dashboard.ts) rule for rule; `buildLedgerBudgetMonth`
// follows Actual's own budget rules for both budget styles.

/// How the budget treats what's left at the end of a month. Named as in
/// Actual (`budgetType`).
enum BudgetStyle {
  /// "Simple monthly limits": each month starts fresh. To budget is this
  /// month's income minus this month's budgeted amounts.
  tracking,

  /// "Envelopes": what's left in a category carries into next month, and
  /// To budget is all income so far minus everything budgeted.
  envelope;

  static BudgetStyle parse(String? value) => value == 'envelope' ? envelope : tracking;
}

const _topCategories = 6;
const _topPayees = 5;
const _recent = 8;
const _uncategorizedWindowDays = 30;

String _month(String date) => date.substring(0, 7);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthOf(DateTime d) => _isoDate(d).substring(0, 7);

/// `YYYY-MM` [delta] months away.
String shiftLedgerMonth(String month, int delta) =>
    _monthOf(DateTime(int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)) + delta));

/// The last [count] months as YYYY-MM, oldest first, ending with [today]'s.
List<String> ledgerMonthKeys(DateTime today, int count) => [
  for (var i = count - 1; i >= 0; i--) _monthOf(DateTime(today.year, today.month - i)),
];

/// One amount as the budget and the flows read it: a top-level transaction,
/// or a split's child in place of its parent.
typedef _Leaf = ({String id, String accountId, bool inSplit, String date, int amountCents, String? categoryId, String? payeeId});

/// The top-level rows and, separately, the leaves. A split's parent carries
/// the total but no category, its children the categories: balances read
/// the top level, flows read the leaves, so a split is never counted twice.
({List<LedgerTransaction> top, Map<String, List<LedgerTransaction>> children}) _shape(
  List<LedgerTransaction> transactions,
) {
  final top = <LedgerTransaction>[];
  final children = <String, List<LedgerTransaction>>{};
  for (final t in transactions) {
    if (t.deleted) continue;
    final parent = t.parentId;
    if (parent == null) {
      top.add(t);
    } else {
      (children[parent] ??= []).add(t);
    }
  }
  return (top: top, children: children);
}

List<_Leaf> _leaves(LedgerTransaction t, Map<String, List<LedgerTransaction>> children) {
  final kids = children[t.id];
  if (kids == null || kids.isEmpty) {
    return [
      (
        id: t.id,
        accountId: t.accountId,
        inSplit: false,
        date: t.date,
        amountCents: t.amountCents,
        categoryId: t.categoryId,
        payeeId: t.payeeId,
      ),
    ];
  }
  return [
    for (final k in kids)
      (
        id: k.id,
        accountId: t.accountId,
        inSplit: true,
        date: t.date,
        amountCents: k.amountCents,
        categoryId: k.categoryId,
        payeeId: k.payeeId ?? t.payeeId,
      ),
  ];
}

/// Money moving between your own accounts, or an opening balance, is not a
/// flow (income or spending).
bool _isFlow(LedgerTransaction t) => t.transferId == null && !t.startingBalance;

/// The on-budget flows, as leaves.
List<_Leaf> _flows(List<LedgerAccount> accounts, List<LedgerTransaction> transactions) {
  final onBudget = {
    for (final a in accounts)
      if (!a.deleted && !a.closed && !a.offBudget) a.id,
  };
  final shaped = _shape(transactions);
  return [
    for (final t in shaped.top)
      if (onBudget.contains(t.accountId) && _isFlow(t)) ..._leaves(t, shaped.children),
  ];
}

/// Home's "without a category": one rule for the count and for the list that
/// shows them, so the two always agree.
List<_Leaf> _uncategorizedFlows(List<_Leaf> flows, DateTime today) {
  final cutoff = _isoDate(DateTime(today.year, today.month, today.day - _uncategorizedWindowDays));
  return [
    for (final f in flows)
      if (f.categoryId == null && f.date.compareTo(cutoff) >= 0) f,
  ];
}

/// What Home counts as without a category, newest first.
List<UncategorizedTransaction> buildUncategorized({
  required List<LedgerAccount> accounts,
  required List<LedgerTransaction> transactions,
  required Map<String, String> payeeNames,
  required DateTime today,
}) {
  final open = [
    for (final a in accounts)
      if (!a.deleted && !a.closed) a,
  ];
  final names = {for (final a in open) a.id: a.name};
  return [
    for (final f in _uncategorizedFlows(_flows(open, transactions), today))
      UncategorizedTransaction(
        id: f.id,
        date: DateTime.parse(f.date),
        amountCents: f.amountCents,
        payee: f.payeeId == null ? null : payeeNames[f.payeeId],
        account: names[f.accountId]!,
        inSplit: f.inSplit,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
}

Dashboard buildLedgerDashboard({
  required List<LedgerAccount> accounts,
  required List<LedgerTransaction> transactions,
  required Map<String, String> categoryNames,
  Map<String, String> categoryEmojis = const {},
  required Map<String, String> payeeNames,
  required DateTime today,
  int months = 6,
}) {
  final open = [
    for (final a in accounts)
      if (!a.deleted && !a.closed) a,
  ]..sort((a, b) => a.sort.compareTo(b.sort));
  final byId = {for (final a in open) a.id: a};
  final shaped = _shape(transactions);
  final top = [
    for (final t in shaped.top)
      if (byId.containsKey(t.accountId)) t,
  ];

  // Balances: every top-level transaction, transfers and opening balances
  // included.
  final balances = <String, int>{};
  for (final t in top) {
    balances[t.accountId] = (balances[t.accountId] ?? 0) + t.amountCents;
  }
  final dashAccounts = [
    for (final a in open)
      DashboardAccount(id: a.id, name: a.name, offbudget: a.offBudget, balanceCents: balances[a.id] ?? 0),
  ];
  final netWorth = dashAccounts.fold(0, (sum, a) => sum + a.balanceCents);

  // All rows, not just [top]: a split's children carry its categories.
  final flows = _flows(open, transactions);
  final keys = ledgerMonthKeys(today, months);
  final income = {for (final k in keys) k: 0};
  final spending = {for (final k in keys) k: 0};
  for (final f in flows) {
    final m = _month(f.date);
    if (!income.containsKey(m)) continue;
    if (f.amountCents > 0) {
      income[m] = income[m]! + f.amountCents;
    } else {
      spending[m] = spending[m]! - f.amountCents;
    }
  }

  final current = keys.last;
  final spentThisMonth = [
    for (final f in flows)
      if (f.amountCents < 0 && _month(f.date) == current) f,
  ];

  final byCategory = <String?, int>{};
  for (final f in spentThisMonth) {
    byCategory[f.categoryId] = (byCategory[f.categoryId] ?? 0) - f.amountCents;
  }
  final ranked = [
    for (final e in byCategory.entries)
      CategorySpend(
        categoryId: e.key,
        name: e.key == null ? 'Uncategorized' : (categoryNames[e.key] ?? 'Unknown category'),
        spendingCents: e.value,
        emoji: categoryEmojis[e.key],
      ),
  ]..sort((a, b) => b.spendingCents.compareTo(a.spendingCents));
  final topCategories = ranked.take(_topCategories).toList();
  if (ranked.length > _topCategories) {
    topCategories.add(
      CategorySpend(
        name: 'Other',
        spendingCents: ranked.skip(_topCategories).fold(0, (sum, c) => sum + c.spendingCents),
      ),
    );
  }

  final byPayee = <String, ({int spendingCents, int count})>{};
  for (final f in spentThisMonth) {
    final name = f.payeeId == null ? null : payeeNames[f.payeeId];
    if (name == null) continue;
    final entry = byPayee[name] ?? (spendingCents: 0, count: 0);
    byPayee[name] = (spendingCents: entry.spendingCents - f.amountCents, count: entry.count + 1);
  }
  final topPayees = [
    for (final e in byPayee.entries)
      PayeeSpend(name: e.key, spendingCents: e.value.spendingCents, count: e.value.count),
  ]..sort((a, b) => b.spendingCents.compareTo(a.spendingCents));

  final uncategorized = _uncategorizedFlows(flows, today).length;

  final recent = [...top]
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });

  return Dashboard(
    netWorthCents: netWorth,
    accounts: dashAccounts,
    months: [for (final k in keys) MonthFlow(month: k, incomeCents: income[k]!, spendingCents: spending[k]!)],
    topCategories: topCategories,
    topPayees: topPayees.take(_topPayees).toList(),
    uncategorizedCount: uncategorized,
    recent: [
      for (final t in recent.take(_recent))
        RecentTransaction(
          id: t.id,
          date: DateTime.parse(t.date),
          amountCents: t.amountCents,
          payee: t.payeeId == null ? null : payeeNames[t.payeeId],
          category: t.categoryId == null ? null : categoryNames[t.categoryId],
          categoryEmoji: categoryEmojis[t.categoryId],
          account: byId[t.accountId]!.name,
          accountId: t.accountId,
        ),
    ],
  );
}

/// A category group as the budget lists it (visible ones only).
typedef LedgerBudgetGroup = ({String id, String name, bool isIncome, List<({String id, String name})> categories});

/// One month's budget in [style].
///
/// Spent is what moved in a category that month on on-budget accounts
/// (transfers and opening balances excluded; refunds count back). Income is
/// what landed in income categories, as in Actual: uncategorized money in
/// isn't income until it has a category.
///
/// - [BudgetStyle.tracking]: left = budgeted + spent; To budget = this
///   month's income − this month's budgeted.
/// - [BudgetStyle.envelope]: left = budgeted + spent + what was left last
///   month (a positive leftover always carries; an overspent one only with
///   `carryover`, otherwise it comes out of next month's To budget). To
///   budget = last month's To budget + this month's income − last month's
///   overspending − this month's budgeted.
BudgetMonth buildLedgerBudgetMonth({
  Map<String, String> categoryEmojis = const {},
  required String month,
  required BudgetStyle style,
  required List<LedgerBudgetGroup> groups,
  required List<LedgerAccount> accounts,
  required List<LedgerTransaction> transactions,
  required List<LedgerBudget> budgets,
  required DateTime today,
}) {
  final expense = [
    for (final g in groups)
      if (!g.isIncome && g.categories.isNotEmpty) g,
  ];
  final incomeGroups = [
    for (final g in groups)
      if (g.isIncome) g,
  ];
  final expenseIds = {
    for (final g in expense)
      for (final c in g.categories) c.id,
  };
  final incomeIds = {
    for (final g in incomeGroups)
      for (final c in g.categories) c.id,
  };

  // Per month: spent per expense category, received per income category.
  final spent = <String, Map<String, int>>{};
  final received = <String, Map<String, int>>{};
  final flowMonths = <String>{};
  for (final f in _flows(accounts, transactions)) {
    final c = f.categoryId;
    if (c == null) continue;
    final m = _month(f.date);
    final into = expenseIds.contains(c) ? spent : (incomeIds.contains(c) ? received : null);
    if (into == null) continue;
    flowMonths.add(m);
    final row = into[m] ??= {};
    row[c] = (row[c] ?? 0) + f.amountCents;
  }
  final budgeted = <String, Map<String, LedgerBudget>>{};
  for (final b in budgets) {
    (budgeted[b.month] ??= {})[b.categoryId] = b;
  }

  final current = _monthOf(today);
  final known = {...flowMonths, ...budgeted.keys, current};
  final firstMonth = known.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final latest = known.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  final next = shiftLedgerMonth(current, 1);
  final lastMonth = latest.compareTo(next) >= 0 ? latest : next;

  int incomeOf(String m) => (received[m] ?? const {}).values.fold(0, (s, v) => s + v);

  // Envelopes run every month from the first one; tracking needs only [month].
  var carried = <String, int>{};
  var toBudget = 0;
  var lastOverspent = 0;
  late Map<String, int> left;
  late Map<String, int> carryIn;
  var m = style == BudgetStyle.envelope && firstMonth.compareTo(month) < 0 ? firstMonth : month;
  while (true) {
    carryIn = style == BudgetStyle.envelope ? carried : const {};
    left = {
      for (final c in expenseIds) c: (budgeted[m]?[c]?.budgetedCents ?? 0) + (spent[m]?[c] ?? 0) + (carryIn[c] ?? 0),
    };
    final totalBudgeted = (budgeted[m] ?? const {}).entries
        .where((e) => expenseIds.contains(e.key))
        .fold(0, (s, e) => s + e.value.budgetedCents);
    toBudget = style == BudgetStyle.envelope
        ? toBudget + incomeOf(m) + lastOverspent - totalBudgeted
        : incomeOf(m) - totalBudgeted;
    if (m == month) break;
    // What goes into next month.
    carried = {};
    lastOverspent = 0;
    for (final e in left.entries) {
      final carryover = budgeted[m]?[e.key]?.carryover ?? false;
      if (e.value > 0 || carryover) {
        carried[e.key] = e.value;
      } else {
        lastOverspent += e.value;
      }
    }
    m = shiftLedgerMonth(m, 1);
  }

  final budgetGroups = [
    for (final g in expense)
      () {
        final categories = [
          for (final c in g.categories)
            BudgetCategory(
              id: c.id,
              name: c.name,
              budgetedCents: budgeted[month]?[c.id]?.budgetedCents ?? 0,
              spentCents: spent[month]?[c.id] ?? 0,
              balanceCents: left[c.id] ?? 0,
              carryover: style == BudgetStyle.envelope && (budgeted[month]?[c.id]?.carryover ?? false),
              emoji: categoryEmojis[c.id],
            ),
        ];
        int sum(int Function(BudgetCategory) f) => categories.fold(0, (s, c) => s + f(c));
        return BudgetGroup(
          id: g.id,
          name: g.name,
          budgetedCents: sum((c) => c.budgetedCents),
          spentCents: sum((c) => c.spentCents),
          balanceCents: sum((c) => c.balanceCents),
          categories: categories,
        );
      }(),
  ];
  int total(int Function(BudgetGroup) f) => budgetGroups.fold(0, (s, g) => s + f(g));

  return BudgetMonth(
    month: month,
    firstMonth: firstMonth,
    lastMonth: lastMonth,
    toBudgetCents: toBudget,
    totalBudgetedCents: total((g) => g.budgetedCents),
    totalSpentCents: total((g) => g.spentCents),
    totalBalanceCents: total((g) => g.balanceCents),
    incomeCents: incomeOf(month),
    groups: budgetGroups,
    income: [
      for (final g in incomeGroups)
        for (final c in g.categories)
          (id: c.id, name: c.name, receivedCents: received[month]?[c.id] ?? 0, emoji: categoryEmojis[c.id]),
    ],
  );
}
