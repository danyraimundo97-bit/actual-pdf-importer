import 'package:drift/drift.dart';

import '../../core/format/fold.dart';
import '../../core/log/app_log.dart';
import 'db/app_database.dart';
import 'ledger_store.dart';

const _log = AppLog('ledger');

/// What moving found, for the screen's sentence and the logs.
typedef LedgerMoveResult = ({int accounts, int transactions, int withoutCategory, int budgets});

/// Moves the phone's own rows (scope `''`) into a connected budget
/// (docs/plans/local-ledger.md, Phase 5c). One database transaction and no
/// network: the rows join the budget's copy with their outbox entries, and the
/// sync sends them like any other change, which is what makes a failure safe.
///
/// - [accounts] says, per phone account, which Actual account it joins, or
///   null to create it. Joining an account leaves the opening balance behind,
///   since that account already has its own.
/// - [links] is local category → Actual category. Any other category is left
///   off the row: a local id must never reach Actual.
/// - A payee joins the budget's payee of the same name, if there is one.
/// - A budget amount only fills an empty spot: this never overwrites what the
///   budget already says. Amounts for unlinked categories stay on the phone.
class LedgerMove {
  LedgerMove(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  static String _payeeKey(String name) => foldAccents(name).trim().toLowerCase();

  Future<LedgerMoveResult> intoBudget(
    String budget, {
    required Map<String, String?> accounts,
    required Map<String, String> links,
  }) {
    if (budget == phoneScope) throw ArgumentError.value(budget, 'budget', 'must be a budget');
    final at = _now().millisecondsSinceEpoch;
    return _db.transaction(() async {
      Future<void> dropEntry(String kind, String rowId) =>
          (_db.delete(_db.ledgerOutbox)..where((o) => o.kind.equals(kind) & o.rowId.equals(rowId))).go();
      Future<void> queue(String kind, String rowId) => _db
          .into(_db.ledgerOutbox)
          .insert(
            LedgerOutboxCompanion.insert(scope: budget, kind: kind, rowId: rowId, op: 'put', createdAt: at),
            onConflict: DoUpdate(
              (_) => LedgerOutboxCompanion(scope: Value(budget), op: const Value('put'), lastError: const Value(null)),
              target: [_db.ledgerOutbox.kind, _db.ledgerOutbox.rowId],
            ),
          );

      final phoneAccounts = await (_db.select(_db.ledgerAccounts)..where((a) => a.scope.equals(phoneScope))).get();
      final rows = await (_db.select(_db.ledgerTransactions)..where((t) => t.scope.equals(phoneScope))).get();
      final phonePayees = await (_db.select(_db.ledgerPayees)..where((p) => p.scope.equals(phoneScope))).get();
      final budgetPayees = {
        for (final p in await (_db.select(
          _db.ledgerPayees,
        )..where((p) => p.scope.equals(budget) & p.deleted.equals(false) & p.transferAccountId.isNull())).get())
          _payeeKey(p.name): p.id,
      };
      final payeeNames = {for (final p in phonePayees) p.id: p.name};
      final movedPayees = <String, String>{};

      // Only an account still on the phone can be left behind: one created
      // after the screen opened isn't in [accounts], and stays.
      bool moves(String accountId) => accounts.containsKey(accountId);

      var moved = 0;
      var withoutCategory = 0;
      for (final t in rows) {
        if (!moves(t.accountId)) continue;
        final target = accounts[t.accountId];
        // Never sent, so Actual needn't hear about them. The opening balance
        // of an account joining another isn't brought either.
        if (t.deleted || (target != null && t.startingBalance)) {
          await (_db.delete(_db.ledgerTransactions)..where((x) => x.id.equals(t.id))).go();
          await dropEntry('transaction', t.id);
          continue;
        }
        final payee = t.payeeId;
        String? payeeId;
        if (payee != null) {
          final name = payeeNames[payee];
          payeeId = name == null ? null : (movedPayees[payee] ??= budgetPayees[_payeeKey(name)] ?? payee);
        }
        final categoryId = t.categoryId == null ? null : links[t.categoryId];
        if (t.categoryId != null && categoryId == null) withoutCategory++;
        await (_db.update(_db.ledgerTransactions)..where((x) => x.id.equals(t.id))).write(
          LedgerTransactionsCompanion(
            scope: Value(budget),
            accountId: Value(target ?? t.accountId),
            payeeId: Value(payeeId),
            categoryId: Value(categoryId),
            updatedAt: Value(at),
          ),
        );
        await queue('transaction', t.id);
        moved++;
      }

      // Only the payees in use go: a phone payee nothing points at isn't worth
      // adding to someone's budget.
      final stillOnPhone =
          await (_db.selectOnly(_db.ledgerTransactions, distinct: true)
                ..addColumns([_db.ledgerTransactions.payeeId])
                ..where(_db.ledgerTransactions.scope.equals(phoneScope)))
              .get();
      final inUse = {for (final r in stillOnPhone) r.read(_db.ledgerTransactions.payeeId)};
      for (final p in phonePayees) {
        final target = movedPayees[p.id];
        if (target == p.id) {
          await (_db.update(
            _db.ledgerPayees,
          )..where((x) => x.id.equals(p.id))).write(LedgerPayeesCompanion(scope: Value(budget), updatedAt: Value(at)));
          await queue('payee', p.id);
        } else if (!inUse.contains(p.id)) {
          await (_db.delete(_db.ledgerPayees)..where((x) => x.id.equals(p.id))).go();
          await dropEntry('payee', p.id);
        }
      }

      var movedAccounts = 0;
      for (final a in phoneAccounts) {
        if (!moves(a.id)) continue;
        final target = accounts[a.id];
        if (target == null) {
          await (_db.update(_db.ledgerAccounts)..where((x) => x.id.equals(a.id))).write(
            LedgerAccountsCompanion(scope: Value(budget), sort: Value(1000 + a.sort), updatedAt: Value(at)),
          );
          await queue('account', a.id);
        } else {
          await (_db.delete(_db.ledgerAccounts)..where((x) => x.id.equals(a.id))).go();
          await dropEntry('account', a.id);
          // An open screen or an import's undo may still hold the old id.
          await _db
              .into(_db.ledgerIdAliases)
              .insertOnConflictUpdate(LedgerIdAliasesCompanion.insert(phoneId: a.id, actualId: target));
        }
        movedAccounts++;
      }

      final budgets = await _moveBudgets(budget, links, at, queue, dropEntry);
      _log.info('Phone rows moved into a budget', {
        'accounts': movedAccounts,
        'transactions': moved,
        'withoutCategory': withoutCategory,
        'budgets': budgets,
      });
      return (accounts: movedAccounts, transactions: moved, withoutCategory: withoutCategory, budgets: budgets);
    });
  }

  Future<int> _moveBudgets(
    String budget,
    Map<String, String> links,
    int at,
    Future<void> Function(String, String) queue,
    Future<void> Function(String, String) dropEntry,
  ) async {
    final phone = await (_db.select(_db.ledgerBudgets)..where((b) => b.scope.equals(phoneScope))).get();
    final existing = {
      for (final b in await (_db.select(_db.ledgerBudgets)..where((b) => b.scope.equals(budget))).get())
        '${b.categoryId}|${b.month}': b.budgetedCents,
    };
    var moved = 0;
    for (final b in phone) {
      final categoryId = links[b.categoryId];
      if (categoryId == null) continue;
      await (_db.delete(
        _db.ledgerBudgets,
      )..where((x) => x.scope.equals(phoneScope) & x.categoryId.equals(b.categoryId) & x.month.equals(b.month))).go();
      await dropEntry('budget', '${b.categoryId}|${b.month}');
      final key = '$categoryId|${b.month}';
      if (b.budgetedCents == 0 || (existing[key] ?? 0) != 0) continue;
      await _db
          .into(_db.ledgerBudgets)
          .insertOnConflictUpdate(
            LedgerBudgetsCompanion.insert(
              scope: budget,
              categoryId: categoryId,
              month: b.month,
              budgetedCents: b.budgetedCents,
              updatedAt: at,
            ),
          );
      await queue('budget', key);
      moved++;
    }
    return moved;
  }
}
