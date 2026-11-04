import 'package:drift/drift.dart';

import '../../core/log/app_log.dart';
import 'db/app_database.dart';

const _log = AppLog('ledger');

/// Fetches a pull: `(budgetSyncId, epoch, lastId)` → the backend's JSON
/// (`GET /ledger/pull`). A function, so tests hand in a fake.
typedef LedgerPullFetch = Future<Map<String, dynamic>> Function(String budgetSyncId, String? epoch, int? lastId);

typedef LedgerPullResult = ({bool full, int transactions, int budgets});

/// Keeps the phone's copy of an Actual budget (scope = its sync id) in step
/// with Actual (docs/plans/local-ledger.md, Phase 5).
///
/// [pull] asks for what changed since the stored cursor and applies it in
/// one database transaction, so a copy is never half updated. Rows the
/// phone changed and hasn't sent yet (a pending outbox entry) keep the
/// phone's version: a pending change is newer than the last pull. Rows the
/// pull writes are Actual's, so they never go into the outbox.
class LedgerSync {
  LedgerSync(this._db, this._fetch, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final LedgerPullFetch _fetch;
  final DateTime Function() _now;

  /// When [scope] was last pulled, or null if it never was.
  Future<DateTime?> lastPulledAt(String scope) async {
    final state = await (_db.select(_db.ledgerSyncState)..where((s) => s.scope.equals(scope))).getSingleOrNull();
    final at = state?.lastPulledAt;
    return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
  }

  Future<LedgerPullResult> pull(String scope) async {
    final state = await (_db.select(_db.ledgerSyncState)..where((s) => s.scope.equals(scope))).getSingleOrNull();
    final json = await _fetch(scope, state?.cursorEpoch, state?.cursorLastId);
    final result = await _apply(scope, json);
    _log.info('Ledger pulled', {'full': result.full, 'transactions': result.transactions, 'budgets': result.budgets});
    return result;
  }

  Future<LedgerPullResult> _apply(String scope, Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => (json[key] as List? ?? const []).cast<Map<String, dynamic>>();
    final full = json['full'] == true;
    final at = _now().millisecondsSinceEpoch;

    return _db.transaction(() async {
      final pending = <String, Set<String>>{};
      for (final o in await (_db.select(_db.ledgerOutbox)..where((o) => o.scope.equals(scope))).get()) {
        (pending[o.kind] ??= {}).add(o.rowId);
      }
      bool isPending(String kind, String id) => pending[kind]?.contains(id) ?? false;

      // Accounts, payees and categories come whole: what's missing is gone.
      final accounts = list('accounts');
      final accountIds = {for (final a in accounts) a['id'] as String};
      final known = {
        for (final a in await (_db.select(_db.ledgerAccounts)..where((a) => a.scope.equals(scope))).get()) a.id: a,
      };
      final payees = list('payees');
      final payeeIds = {for (final p in payees) p['id'] as String};
      final transactions = [
        for (final t in list('transactions'))
          if (!isPending('transaction', t['id'] as String)) t,
      ];
      // A transaction can belong to an account Actual has deleted (it isn't
      // listed any more); keep a removed stand-in so the row has its account.
      final orphanAccounts = {
        for (final t in transactions)
          if (!accountIds.contains(t['accountId']) && !known.containsKey(t['accountId'])) t['accountId'] as String,
      };

      await _db.batch((b) {
        for (final (i, a) in accounts.indexed) {
          final id = a['id'] as String;
          if (isPending('account', id)) continue;
          b.insert(
            _db.ledgerAccounts,
            LedgerAccountsCompanion.insert(
              id: id,
              scope: scope,
              name: a['name'] as String,
              offBudget: Value(a['offbudget'] == true),
              closed: Value(a['closed'] == true),
              sort: i,
              bankId: Value(known[id]?.bankId),
              updatedAt: at,
            ),
            onConflict: DoUpdate(
              (_) => LedgerAccountsCompanion(
                name: Value(a['name'] as String),
                offBudget: Value(a['offbudget'] == true),
                closed: Value(a['closed'] == true),
                sort: Value(i),
                updatedAt: Value(at),
                deleted: const Value(false),
              ),
            ),
          );
        }
        for (final id in orphanAccounts) {
          b.insert(
            _db.ledgerAccounts,
            LedgerAccountsCompanion.insert(
              id: id,
              scope: scope,
              name: 'Deleted account',
              closed: const Value(true),
              sort: 1 << 30,
              updatedAt: at,
              deleted: const Value(true),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
        for (final p in payees) {
          final id = p['id'] as String;
          if (isPending('payee', id)) continue;
          b.insert(
            _db.ledgerPayees,
            LedgerPayeesCompanion.insert(
              id: id,
              scope: scope,
              name: p['name'] as String,
              transferAccountId: Value(p['transferAccountId'] as String?),
              updatedAt: at,
            ),
            onConflict: DoUpdate(
              (_) => LedgerPayeesCompanion(
                name: Value(p['name'] as String),
                transferAccountId: Value(p['transferAccountId'] as String?),
                updatedAt: Value(at),
                deleted: const Value(false),
              ),
            ),
          );
        }
      });

      // Gone from Actual: removed here too. Rows made on the phone and not
      // sent yet (ids `acct:`/`payee:`) aren't Actual's to remove.
      await (_db.update(_db.ledgerAccounts)..where(
            (a) =>
                a.scope.equals(scope) &
                a.id.isNotIn([...accountIds, ...orphanAccounts]) &
                a.id.like('acct:%').not() &
                a.id.isNotIn(pending['account'] ?? const <String>{}),
          ))
          .write(LedgerAccountsCompanion(deleted: const Value(true), updatedAt: Value(at)));
      await (_db.update(_db.ledgerPayees)..where(
            (p) =>
                p.scope.equals(scope) &
                p.id.isNotIn(payeeIds) &
                p.id.like('payee:%').not() &
                p.id.isNotIn(pending['payee'] ?? const <String>{}),
          ))
          .write(LedgerPayeesCompanion(deleted: const Value(true), updatedAt: Value(at)));

      await (_db.delete(_db.ledgerCategories)..where((c) => c.scope.equals(scope))).go();
      await _db.batch((b) {
        var sort = 0;
        for (final (gi, g) in list('categoryGroups').indexed) {
          for (final c in (g['categories'] as List? ?? const []).cast<Map<String, dynamic>>()) {
            b.insert(
              _db.ledgerCategories,
              LedgerCategoriesCompanion.insert(
                scope: scope,
                id: c['id'] as String,
                name: c['name'] as String,
                hidden: Value(c['hidden'] == true),
                sort: sort++,
                groupId: g['id'] as String,
                groupName: g['name'] as String,
                groupIsIncome: Value(g['isIncome'] == true),
                groupHidden: Value(g['hidden'] == true),
                groupSort: gi,
              ),
            );
          }
        }
      });

      // Transactions and budget amounts: everything (full) or the changes.
      if (full) {
        await (_db.delete(_db.ledgerTransactions)..where(
              (t) =>
                  t.scope.equals(scope) &
                  t.id.like('tx:%').not() &
                  t.id.isNotIn(pending['transaction'] ?? const <String>{}),
            ))
            .go();
      }
      await _db.batch((b) {
        for (final t in transactions) {
          b.insert(
            _db.ledgerTransactions,
            LedgerTransactionsCompanion.insert(
              id: t['id'] as String,
              scope: scope,
              accountId: t['accountId'] as String,
              date: t['date'] as String,
              amountCents: t['amountCents'] as int,
              payeeId: Value(t['payeeId'] as String?),
              categoryId: Value(t['categoryId'] as String?),
              notes: Value(t['notes'] as String?),
              cleared: Value(t['cleared'] == true),
              importedId: Value(t['importedId'] as String?),
              startingBalance: Value(t['startingBalance'] == true),
              transferId: Value(t['transferId'] as String?),
              parentId: Value(t['parentId'] as String?),
              isParent: Value(t['isParent'] == true),
              createdAt: at,
              updatedAt: at,
              deleted: Value(t['deleted'] == true),
            ),
            onConflict: DoUpdate(
              (_) => LedgerTransactionsCompanion(
                accountId: Value(t['accountId'] as String),
                date: Value(t['date'] as String),
                amountCents: Value(t['amountCents'] as int),
                payeeId: Value(t['payeeId'] as String?),
                categoryId: Value(t['categoryId'] as String?),
                notes: Value(t['notes'] as String?),
                cleared: Value(t['cleared'] == true),
                importedId: Value(t['importedId'] as String?),
                startingBalance: Value(t['startingBalance'] == true),
                transferId: Value(t['transferId'] as String?),
                parentId: Value(t['parentId'] as String?),
                isParent: Value(t['isParent'] == true),
                updatedAt: Value(at),
                deleted: Value(t['deleted'] == true),
              ),
            ),
          );
        }
      });

      final budgets = [
        for (final b in list('budgets'))
          if (!isPending('budget', '${b['categoryId']}|${b['month']}')) b,
      ];
      if (full) {
        final keep = pending['budget'] ?? const <String>{};
        final rows = await (_db.select(_db.ledgerBudgets)..where((b) => b.scope.equals(scope))).get();
        for (final row in rows) {
          if (keep.contains('${row.categoryId}|${row.month}')) continue;
          await (_db.delete(_db.ledgerBudgets)
                ..where((b) => b.scope.equals(scope) & b.categoryId.equals(row.categoryId) & b.month.equals(row.month)))
              .go();
        }
      }
      await _db.batch((b) {
        for (final row in budgets) {
          b.insert(
            _db.ledgerBudgets,
            LedgerBudgetsCompanion.insert(
              scope: scope,
              categoryId: row['categoryId'] as String,
              month: row['month'] as String,
              budgetedCents: row['budgetedCents'] as int,
              carryover: Value(row['carryover'] == true),
              updatedAt: at,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

      await _db
          .into(_db.ledgerSyncState)
          .insertOnConflictUpdate(
            LedgerSyncStateCompanion.insert(
              scope: scope,
              budgetMode: Value(json['budgetType'] == 'tracking' ? 'tracking' : 'envelope'),
              lastPulledAt: Value(at),
              cursorEpoch: Value(json['epoch'] as String?),
              cursorLastId: Value(json['lastId'] as int?),
            ),
          );
      return (full: full, transactions: transactions.length, budgets: budgets.length);
    });
  }
}
