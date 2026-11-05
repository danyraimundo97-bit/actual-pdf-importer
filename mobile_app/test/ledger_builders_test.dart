import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/data/local/db/app_database.dart';
import 'package:mobile_app/data/local/ledger_builders.dart';
import 'package:mobile_app/data/models/account_page.dart';

// docs/plans/local-ledger.md, Phase 4. The dashboard cases mirror
// backend_app/src/__tests__/dashboard.test.ts, so the phone and the backend
// agree on what counts.

final today = DateTime(2026, 9, 20);

LedgerAccount account(String id, String name, {bool offBudget = false, bool closed = false, int sort = 0}) =>
    LedgerAccount(
      id: id,
      scope: '',
      name: name,
      offBudget: offBudget,
      closed: closed,
      sort: sort,
      updatedAt: 0,
      deleted: false,
    );

final accounts = [
  account('chk', 'Checking'),
  account('inv', 'Broker', offBudget: true, sort: 1),
  account('old', 'Closed card', closed: true, sort: 2),
];

var _seq = 0;
LedgerTransaction tx(
  String accountId,
  String date,
  int cents, {
  String? payee,
  String? category,
  String? transfer,
  bool opening = false,
  String? parent,
  bool isParent = false,
  String? id,
  bool deleted = false,
}) => LedgerTransaction(
  id: id ?? 't${++_seq}',
  scope: '',
  accountId: accountId,
  date: date,
  amountCents: cents,
  payeeId: payee,
  categoryId: category,
  cleared: false,
  startingBalance: opening,
  transferId: transfer,
  parentId: parent,
  isParent: isParent,
  createdAt: _seq,
  updatedAt: 0,
  deleted: deleted,
);

void main() {
  group('dashboard', () {
    dynamic build(List<LedgerTransaction> transactions, [Map<String, String> categories = const {}]) =>
        buildLedgerDashboard(
          accounts: accounts,
          transactions: transactions,
          categoryNames: categories,
          payeeNames: const {'p-shop': 'Continente', 'p-boss': 'Employer', 'p-cafe': 'Cafe'},
          today: today,
          months: 3,
        );

    test('month keys list the last N months oldest first, across a year boundary', () {
      expect(ledgerMonthKeys(DateTime(2026, 1, 15), 3), ['2025-11', '2025-12', '2026-01']);
    });

    test('balances include transfers and off-budget accounts; closed and removed rows are dropped', () {
      final d = build([
        tx('chk', '2026-01-01', 100000, opening: true),
        tx('chk', '2026-09-02', -20000, transfer: 'x'),
        tx('inv', '2026-09-02', 20000, transfer: 'y'),
        tx('old', '2026-09-03', -999),
        tx('chk', '2026-09-04', -5000, deleted: true),
      ]);
      expect(
        [for (final a in d.accounts) (a.id, a.balanceCents, a.offbudget)],
        [('chk', 80000, false), ('inv', 20000, true)],
      );
      expect(d.netWorthCents, 100000);
    });

    test('income and spending exclude transfers, opening balances and off-budget accounts', () {
      final d = build([
        tx('chk', '2026-09-01', 100000, opening: true),
        tx('chk', '2026-09-01', 250000, payee: 'p-boss'),
        tx('chk', '2026-09-05', -4200, payee: 'p-shop', category: 'food'),
        tx('chk', '2026-09-06', -50000, transfer: 'x'),
        tx('inv', '2026-09-06', 50000, transfer: 'y'),
        tx('inv', '2026-09-07', -1000),
        tx('chk', '2026-08-10', -300, payee: 'p-cafe'),
        tx('chk', '2026-03-10', -777),
      ]);
      expect(
        [for (final m in d.months) (m.month, m.incomeCents, m.spendingCents)],
        [('2026-07', 0, 0), ('2026-08', 0, 300), ('2026-09', 250000, 4200)],
      );
    });

    test('split transactions are categorised by their children, never double counted', () {
      final d = build(
        [
          tx('chk', '2026-09-10', -10000, payee: 'p-shop', isParent: true, id: 'split'),
          tx('chk', '2026-09-10', -7000, category: 'food', parent: 'split'),
          tx('chk', '2026-09-10', -3000, category: 'home', parent: 'split'),
        ],
        {'food': 'Groceries', 'home': 'Household'},
      );
      expect(d.accounts.first.balanceCents, -10000);
      expect(d.months.last.spendingCents, 10000);
      expect([for (final c in d.topCategories) (c.name, c.spendingCents)], [('Groceries', 7000), ('Household', 3000)]);
      // Children inherit the parent's payee.
      expect([for (final p in d.topPayees) (p.name, p.spendingCents, p.count)], [('Continente', 10000, 2)]);
    });

    test('categories beyond the top six roll up into "Other"; uncategorized is named', () {
      final categories = {for (var i = 1; i <= 8; i++) 'c$i': 'Cat $i'};
      final d = build([
        for (var i = 1; i <= 8; i++) tx('chk', '2026-09-15', -i * 100, category: 'c$i'),
        tx('chk', '2026-09-15', -50),
      ], categories);
      expect(d.topCategories.length, 7);
      expect((d.topCategories.first.categoryId, d.topCategories.first.spendingCents), ('c8', 800));
      expect(
        (d.topCategories.last.categoryId, d.topCategories.last.name, d.topCategories.last.spendingCents),
        (null, 'Other', 350),
      );
    });

    test('the uncategorized count only looks at the last 30 days of on-budget flows', () {
      final d = build([
        tx('chk', '2026-09-19', -100),
        tx('chk', '2026-08-25', -100),
        tx('chk', '2026-08-01', -100),
        tx('chk', '2026-09-19', -100, category: 'food'),
        tx('chk', '2026-09-19', -100, transfer: 'x'),
        tx('inv', '2026-09-19', -100),
      ]);
      expect(d.uncategorizedCount, 2);
    });

    test('recent lists the newest transactions with names resolved', () {
      final d = build(
        [tx('chk', '2026-09-01', -1, payee: 'p-cafe'), tx('chk', '2026-09-18', -2, payee: 'p-shop', category: 'food')],
        {'food': 'Groceries'},
      );
      expect(
        [for (final r in d.recent) (r.date, r.payee, r.category, r.account, r.accountId)],
        [
          (DateTime(2026, 9, 18), 'Continente', 'Groceries', 'Checking', 'chk'),
          (DateTime(2026, 9, 1), 'Cafe', null, 'Checking', 'chk'),
        ],
      );
    });
  });

  group('budget month', () {
    final groups = <LedgerBudgetGroup>[
      (
        id: 'g-food',
        name: 'Food',
        isIncome: false,
        categories: [(id: 'groceries', name: 'Groceries'), (id: 'eating', name: 'Eating out')],
      ),
      (id: 'g-income', name: 'Income', isIncome: true, categories: [(id: 'salary', name: 'Salary')]),
    ];
    final october = DateTime(2026, 10, 20);

    LedgerBudget budget(String category, String month, int cents, {bool carryover = false}) => LedgerBudget(
      scope: '',
      categoryId: category,
      month: month,
      budgetedCents: cents,
      carryover: carryover,
      updatedAt: 0,
    );

    // September: 2.000 in; groceries 300 budgeted, 350 spent (50 over);
    // eating out 100 budgeted, 40 spent. October: 2.000 in; groceries 300
    // budgeted, 100 spent; eating out 100 budgeted.
    final transactions = [
      tx('chk', '2026-09-01', 200000, category: 'salary'),
      tx('chk', '2026-09-05', -35000, category: 'groceries'),
      tx('chk', '2026-09-06', -4000, category: 'eating'),
      tx('chk', '2026-10-01', 200000, category: 'salary'),
      tx('chk', '2026-10-03', -10000, category: 'groceries'),
      // Not budget money: uncategorized, a transfer, an opening balance,
      // off budget.
      tx('chk', '2026-10-04', 99900),
      tx('chk', '2026-10-04', -5000, category: 'groceries', transfer: 'x'),
      tx('chk', '2026-09-01', 70000, opening: true),
      tx('inv', '2026-10-04', -2500, category: 'groceries'),
    ];
    List<LedgerBudget> budgets({bool carryover = false}) => [
      budget('groceries', '2026-09', 30000, carryover: carryover),
      budget('eating', '2026-09', 10000),
      budget('groceries', '2026-10', 30000),
      budget('eating', '2026-10', 10000),
    ];

    dynamic build(BudgetStyle style, {String month = '2026-10', bool carryover = false}) => buildLedgerBudgetMonth(
      month: month,
      style: style,
      groups: groups,
      accounts: accounts,
      transactions: transactions,
      budgets: budgets(carryover: carryover),
      today: october,
    );

    Map<String, int> left(dynamic month) => {
      for (final g in month.groups)
        for (final c in g.categories) c.id as String: c.balanceCents as int,
    };

    test('simple limits: every month starts fresh', () {
      final m = build(BudgetStyle.tracking);
      expect(left(m), {'groceries': 20000, 'eating': 10000});
      expect(m.toBudgetCents, 200000 - 40000);
      expect(
        (m.totalBudgetedCents, m.totalSpentCents, m.totalBalanceCents, m.incomeCents),
        (40000, -10000, 30000, 200000),
      );
      expect([for (final i in m.income) (i.id, i.receivedCents)], [('salary', 200000)]);
    });

    test('envelopes: leftovers carry, overspending comes out of next month', () {
      final september = build(BudgetStyle.envelope, month: '2026-09');
      expect(left(september), {'groceries': -5000, 'eating': 6000});
      expect(september.toBudgetCents, 200000 - 40000);

      final m = build(BudgetStyle.envelope);
      expect(left(m), {'groceries': 20000, 'eating': 16000});
      expect(m.toBudgetCents, 160000 + 200000 - 5000 - 40000);
    });

    test('envelopes: with carryover the overspending stays in the category', () {
      final m = build(BudgetStyle.envelope, carryover: true);
      expect(left(m), {'groceries': 15000, 'eating': 16000});
      expect(m.toBudgetCents, 160000 + 200000 - 40000);
    });

    test('the month switcher runs from the first month with data to next month', () {
      final m = build(BudgetStyle.tracking);
      expect((m.firstMonth, m.lastMonth), ('2026-09', '2026-11'));
      final empty = build(BudgetStyle.envelope, month: '2026-11');
      expect(left(empty), {'groceries': 20000, 'eating': 16000});
      expect(empty.toBudgetCents, 315000);
    });

    test('a group without visible categories is left out', () {
      final m = buildLedgerBudgetMonth(
        month: '2026-10',
        style: BudgetStyle.tracking,
        groups: [...groups, (id: 'g-empty', name: 'Empty', isIncome: false, categories: const [])],
        accounts: accounts,
        transactions: const [],
        budgets: const [],
        today: october,
      );
      expect([for (final g in m.groups) g.id], ['g-food']);
    });
  });

  group('buildMonthTransactions by category', () {
    MonthTransactions month(List<LedgerTransaction> rows, {Set<String> notCounted = const {}}) => buildMonthTransactions(
      month: '2026-09',
      accounts: accounts,
      transactions: rows,
      categoryNames: const {'food': 'Food', 'fun': 'Fun', 'move': 'Between'},
      categoryEmojis: const {},
      payeeNames: const {},
      notCounted: notCounted,
    );

    test('a split shows only its share, so a category adds up to its figure', () {
      final result = month([
        tx('chk', '2026-09-10', -1000, category: 'food', id: 'plain'),
        tx('chk', '2026-09-11', -300, isParent: true, id: 'split'),
        tx('chk', '2026-09-11', -200, category: 'food', parent: 'split', id: 's1'),
        tx('chk', '2026-09-11', -100, category: 'fun', parent: 'split', id: 's2'),
      ]);
      expect({for (final r in result.rowsInCategory('food')) r.id: r.amountCents}, {'split': -200, 'plain': -1000});
      expect({for (final r in result.rowsInCategory('fun')) r.id: r.amountCents}, {'split': -100});
      expect(result.rowsInCategory('none'), isEmpty);
    });

    test('leaves out other months and transfers; a category that does not count still lists its rows', () {
      final result = month([
        tx('chk', '2026-08-31', -5, category: 'food', id: 'august'),
        tx('chk', '2026-09-02', -6, category: 'food', transfer: 'x', id: 'transfer'),
        tx('chk', '2026-09-03', -7, category: 'move', id: 'moved'),
      ], notCounted: {'move'});
      expect(result.rowsInCategory('food'), isEmpty);
      expect(result.rowsInCategory('move').single.id, 'moved');
      expect(result.spendingCents, 0);
    });
  });
}
