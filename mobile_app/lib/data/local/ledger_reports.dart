import 'package:drift/drift.dart';

import '../../core/format/category_emoji.dart';
import '../models/account_page.dart';
import '../models/actual_account.dart';
import '../models/actual_category.dart';
import '../models/budget_month.dart';
import '../models/dashboard.dart';
import '../models/quick_add.dart';
import '../../core/format/fold.dart';
import 'db/app_database.dart';
import 'ledger_builders.dart';
import 'ledger_store.dart';

typedef _CategoryLook = ({String name, String? emoji});

/// Home, Budget and the account screen read from the local ledger
/// (docs/plans/local-ledger.md, Phase 4): loads the rows, then hands them to
/// the pure builders in ledger_builders.dart. Same models as the backend's
/// responses, so the screens don't care where the numbers came from.
class LedgerReports {
  LedgerReports(this._db, this._store, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final LedgerStore _store;
  final DateTime Function() _now;

  Future<Dashboard> dashboard(String scope, {int months = 6}) async {
    final looks = await _categoryLooks(scope);
    return buildLedgerDashboard(
      accounts: await _store.accounts(scope),
      transactions: await _store.allTransactions(scope),
      categoryNames: _names(looks),
      categoryEmojis: _emojis(looks),
      payeeNames: await _store.payeeNames(scope),
      today: _now(),
      months: months,
    );
  }

  /// What Home counts as without a category.
  Future<List<UncategorizedTransaction>> uncategorized(String scope) async => buildUncategorized(
    accounts: await _store.accounts(scope),
    transactions: await _store.allTransactions(scope),
    payeeNames: await _store.payeeNames(scope),
    today: _now(),
  );

  /// [month] null = the current month.
  Future<BudgetMonth> budgetMonth(String scope, String? month) async {
    final today = _now();
    return buildLedgerBudgetMonth(
      month: month ?? ledgerMonthKeys(today, 1).single,
      categoryEmojis: _emojis(await _categoryLooks(scope)),
      style: BudgetStyle.parse(await _store.budgetMode(scope)),
      groups: await _budgetGroups(scope),
      accounts: await _store.accounts(scope),
      transactions: await _store.allTransactions(scope),
      budgets: await _store.allBudgets(scope),
      today: today,
    );
  }

  /// Every transaction of [month] (`YYYY-MM`), across all accounts.
  Future<MonthTransactions> monthTransactions(String scope, String month) async {
    final looks = await _categoryLooks(scope);
    return buildMonthTransactions(
      month: month,
      accounts: await _store.accounts(scope),
      transactions: await _store.allTransactions(scope),
      categoryNames: _names(looks),
      categoryEmojis: _emojis(looks),
      payeeNames: await _store.payeeNames(scope),
    );
  }

  /// One page of an account, newest first; the cursor is the next offset.
  Future<AccountPage> accountPage(String accountId, {String? before, int limit = 50}) async {
    final account = await _store.account(accountId);
    if (account == null || account.deleted) throw StateError('No account $accountId.');
    final offset = int.tryParse(before ?? '') ?? 0;
    final rows = await _store.transactions(accountId, limit: limit, offset: offset);
    final balance = _db.ledgerTransactions.amountCents.sum();
    final balanceRow =
        await (_db.selectOnly(_db.ledgerTransactions)
              ..addColumns([balance])
              ..where(
                _db.ledgerTransactions.accountId.equals(account.id) &
                    _db.ledgerTransactions.deleted.equals(false) &
                    _db.ledgerTransactions.parentId.isNull(),
              ))
            .getSingle();
    final parents = [
      for (final r in rows)
        if (r.isParent) r.id,
    ];
    final children = parents.isEmpty
        ? const <LedgerTransaction>[]
        : await (_db.select(
            _db.ledgerTransactions,
          )..where((t) => t.parentId.isIn(parents) & t.deleted.equals(false))).get();
    final payees = await _store.payeeNames(account.scope);
    final looks = await _categoryLooks(account.scope);
    final categories = _names(looks);
    return AccountPage(
      accountId: account.id,
      accountName: account.name,
      offbudget: account.offBudget,
      balanceCents: balanceRow.read(balance) ?? 0,
      transactions: [
        for (final r in rows)
          AccountTransaction(
            id: r.id,
            date: DateTime.parse(r.date),
            amountCents: r.amountCents,
            payee: r.payeeId == null ? null : payees[r.payeeId],
            openingBalance: r.startingBalance,
            category: r.categoryId == null ? null : categories[r.categoryId],
            categoryEmoji: looks[r.categoryId]?.emoji,
            notes: r.notes,
            transfer: r.transferId != null,
            cleared: r.cleared,
            splits: [
              for (final c in children)
                if (c.parentId == r.id)
                  (amountCents: c.amountCents, category: c.categoryId == null ? null : categories[c.categoryId]),
            ],
          ),
      ],
      nextCursor: rows.length < limit ? null : '${offset + rows.length}',
    );
  }

  /// The quick-add form's choices, from the ledger, so it works offline: open
  /// accounts (on budget first), categories, and payees most recent first
  /// with the category each last had.
  Future<QuickAddOptions> quickAddOptions(String scope) async {
    final groups = await _budgetGroups(scope);
    final accounts = [
      for (final a in await _store.accounts(scope))
        if (!a.closed) ActualAccount(id: a.id, name: a.name, offbudget: a.offBudget, closed: false),
    ]..sort((a, b) => (a.offbudget ? 1 : 0) - (b.offbudget ? 1 : 0));
    final names = await _store.payeeNames(scope);
    final rows = (await _store.allTransactions(scope)).where((t) => t.payeeId != null && t.transferId == null && !t.startingBalance).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = <String, RecentPayee>{};
    for (final t in rows) {
      final name = names[t.payeeId];
      if (name == null || recent.containsKey(name)) continue;
      recent[name] = RecentPayee(name: name, lastCategoryId: t.isParent ? null : t.categoryId);
      if (recent.length == _recentPayees) break;
    }
    return QuickAddOptions(
      accounts: accounts,
      categoryGroups: _pickerGroups(groups, _emojis(await _categoryLooks(scope))),
      incomeGroupIds: {
        for (final g in groups)
          if (g.isIncome) g.id,
      },
      recentPayees: recent.values.toList(),
    );
  }

  static const _recentPayees = 50;

  /// [scope]'s visible categories, for a category picker.
  Future<List<ActualCategoryGroup>> categoryPicker(String scope) async =>
      _pickerGroups(await _budgetGroups(scope), _emojis(await _categoryLooks(scope)));

  List<ActualCategoryGroup> _pickerGroups(List<LedgerBudgetGroup> groups, Map<String, String> emojis) => [
    for (final g in groups)
      if (g.categories.isNotEmpty)
        ActualCategoryGroup(
          id: g.id,
          name: g.name,
          categories: [for (final c in g.categories) ActualCategory(id: c.id, name: c.name, emoji: emojis[c.id])],
        ),
  ];

  /// Every category's name and emoji, hidden ones included (old transactions
  /// keep theirs). An emoji at the start of a name comes off the name. For an
  /// Actual category without one: the phone category linked to it, then one
  /// with the same name.
  Future<Map<String, _CategoryLook>> _categoryLooks(String scope) async {
    final phone = await _db.select(_db.categories).get();
    _CategoryLook look(String name, String? other) {
      final split = splitCategoryName(name);
      return (name: split.name, emoji: split.emoji ?? other);
    }

    if (scope == phoneScope) {
      return {for (final c in phone) c.id: look(c.name, phoneCategoryEmoji(c.emoji, c.presetKey))};
    }
    final byId = {for (final c in phone) c.id: c};
    final byName = <String, String>{
      for (final c in phone)
        if (phoneCategoryEmoji(c.emoji, c.presetKey) case final emoji?)
          _nameKey(splitCategoryName(c.name).name): emoji,
    };
    final links = await (_db.select(_db.categoryLinks)..where((l) => l.budgetSyncId.equals(scope))).get();
    final linked = <String, String>{};
    for (final l in links) {
      final c = byId[l.categoryId];
      final emoji = c == null ? null : phoneCategoryEmoji(c.emoji, c.presetKey);
      if (emoji != null) linked[l.actualCategoryId] = emoji;
    }
    return {
      for (final c in await (_db.select(_db.ledgerCategories)..where((c) => c.scope.equals(scope))).get())
        c.id: look(c.name, linked[c.id] ?? byName[_nameKey(splitCategoryName(c.name).name)]),
    };
  }

  static String _nameKey(String name) => foldAccents(name).trim().toLowerCase();

  Map<String, String> _names(Map<String, _CategoryLook> looks) => {for (final e in looks.entries) e.key: e.value.name};

  Map<String, String> _emojis(Map<String, _CategoryLook> looks) => {
    for (final e in looks.entries)
      e.key: ?e.value.emoji,
  };

  /// The phone's visible categories, in order, as the budget lists them.
  /// Copies of Actual categories are Actual's, not the phone budget's.
  Future<List<LedgerBudgetGroup>> _budgetGroups(String scope) async {
    if (scope != phoneScope) return _actualBudgetGroups(scope);
    return _phoneBudgetGroups();
  }

  /// An Actual budget's visible categories, grouped, in Actual's order.
  Future<List<LedgerBudgetGroup>> _actualBudgetGroups(String scope) async {
    final rows =
        await (_db.select(_db.ledgerCategories)
              ..where((c) => c.scope.equals(scope) & c.hidden.equals(false) & c.groupHidden.equals(false))
              ..orderBy([(c) => OrderingTerm(expression: c.groupSort), (c) => OrderingTerm(expression: c.sort)]))
            .get();
    final groups = <LedgerBudgetGroup>[];
    for (final c in rows) {
      if (groups.isEmpty || groups.last.id != c.groupId) {
        groups.add((id: c.groupId, name: c.groupName, isIncome: c.groupIsIncome, categories: []));
      }
      groups.last.categories.add((id: c.id, name: splitCategoryName(c.name).name));
    }
    return groups;
  }

  Future<List<LedgerBudgetGroup>> _phoneBudgetGroups() async {
    final groups =
        await (_db.select(_db.categoryGroups)
              ..where((g) => g.hidden.equals(false) & g.source.isNotValue('actual'))
              ..orderBy([(g) => OrderingTerm(expression: g.isIncome), (g) => OrderingTerm(expression: g.sort)]))
            .get();
    final categories =
        await (_db.select(_db.categories)
              ..where((c) => c.hidden.equals(false) & c.source.isNotValue('actual'))
              ..orderBy([(c) => OrderingTerm(expression: c.sort)]))
            .get();
    return [
      for (final g in groups)
        (
          id: g.id,
          name: g.name,
          isIncome: g.isIncome,
          categories: [
            for (final c in categories)
              if (c.groupId == g.id) (id: c.id, name: splitCategoryName(c.name).name),
          ],
        ),
    ];
  }
}
