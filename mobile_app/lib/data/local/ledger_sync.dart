import 'package:drift/drift.dart';

import '../../core/log/app_log.dart';
import 'db/app_database.dart';

const _log = AppLog('ledger');

/// Fetches a pull: `(budgetSyncId, epoch, lastId)` → the backend's JSON
/// (`GET /ledger/pull`). A function, so tests hand in a fake.
typedef LedgerPullFetch = Future<Map<String, dynamic>> Function(String budgetSyncId, String? epoch, int? lastId);

typedef LedgerPullResult = ({bool full, int transactions, int budgets});

/// Sends outbox entries: `(budgetSyncId, entries)` → the backend's answers
/// (`POST /ledger/push`). A function, so tests hand in a fake.
typedef LedgerPushSend =
    Future<List<Map<String, dynamic>>> Function(String budgetSyncId, List<Map<String, dynamic>> entries);

typedef LedgerPushResult = ({int sent, int failed});

/// Entries per request; the rest follow in the same run.
const _pushBatch = 200;

/// The order the outbox goes in: a row can only point at what's already
/// there, and an old transaction can be edited to use a brand new payee.
const _kindOrder = {'payee': 0, 'account': 1, 'transaction': 2, 'budget': 3};

/// Keeps the phone's copy of an Actual budget (scope = its sync id) in step
/// with Actual (docs/plans/local-ledger.md, Phase 5).
///
/// [push] sends the outbox: entries Actual took leave it (rows take Actual's
/// ids), and entries it refused stay with their code.
///
/// [pull] asks for what changed since the stored cursor and applies it in
/// one database transaction, so a copy is never half updated. Rows the
/// phone changed and hasn't sent yet (a pending outbox entry) keep the
/// phone's version: a pending change is newer than the last pull. Rows the
/// pull writes are Actual's, so they never go into the outbox.
class LedgerSync {
  LedgerSync(this._db, this._fetch, {LedgerPushSend? send, DateTime Function()? now})
    : _send = send,
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final LedgerPullFetch _fetch;
  final LedgerPushSend? _send;
  final DateTime Function() _now;

  /// When [scope] was last pulled, or null if it never was.
  Future<DateTime?> lastPulledAt(String scope) async {
    final state = await (_db.select(_db.ledgerSyncState)..where((s) => s.scope.equals(scope))).getSingleOrNull();
    final at = state?.lastPulledAt;
    return at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
  }

  /// Sends everything waiting for [scope]. Throws when a request fails (no
  /// connection): whatever wasn't answered stays queued, and every entry is
  /// safe to send again.
  Future<LedgerPushResult> push(String scope) async {
    final send = _send;
    if (send == null) throw StateError('No way to send changes.');
    final tried = <int>{};
    var sent = 0;
    var failed = 0;
    while (true) {
      final queue = await (_db.select(_db.ledgerOutbox)..where((o) => o.scope.equals(scope))).get();
      final batch =
          queue.where((o) => !tried.contains(o.seq)).toList()..sort((a, b) {
            final byKind = (_kindOrder[a.kind] ?? 9) - (_kindOrder[b.kind] ?? 9);
            return byKind != 0 ? byKind : a.seq - b.seq;
          });
      if (batch.isEmpty) break;
      final slice = batch.take(_pushBatch).toList();
      tried.addAll(slice.map((o) => o.seq));

      final entries = <(LedgerOutboxData, Map<String, dynamic>)>[];
      for (final entry in slice) {
        final payload = await _payload(entry);
        if (payload == null) {
          // Nothing Actual needs to hear about (see [_payload]).
          await (_db.delete(_db.ledgerOutbox)..where((o) => o.seq.equals(entry.seq))).go();
        } else {
          entries.add((entry, payload));
        }
      }
      if (entries.isEmpty) continue;

      final answers = await send(scope, [for (final (_, payload) in entries) payload]);
      failed += await _applyAnswers(entries, answers);
      sent += entries.length;
    }
    if (sent > 0) _log.info('Ledger pushed', {'sent': sent, 'failed': failed});
    return (sent: sent, failed: failed);
  }

  /// The row as it is now, or null when there's nothing to send: the row is
  /// gone, or a phone-only transaction was removed before it was ever sent.
  Future<Map<String, dynamic>?> _payload(LedgerOutboxData entry) async {
    final base = {'seq': entry.seq, 'kind': entry.kind, 'op': entry.op};
    switch (entry.kind) {
      case 'payee':
        final row = await (_db.select(_db.ledgerPayees)..where((p) => p.id.equals(entry.rowId))).getSingleOrNull();
        return row == null ? null : {...base, 'id': row.id, 'name': row.name};
      case 'account':
        final row = await (_db.select(_db.ledgerAccounts)..where((a) => a.id.equals(entry.rowId))).getSingleOrNull();
        if (row == null) return null;
        return {...base, 'id': row.id, 'name': row.name, 'offBudget': row.offBudget, 'closed': row.closed};
      case 'transaction':
        if (entry.op == 'delete' && entry.rowId.startsWith('tx:')) return null;
        if (entry.op == 'delete') return {...base, 'id': entry.rowId};
        final row = await (_db.select(
          _db.ledgerTransactions,
        )..where((t) => t.id.equals(entry.rowId))).getSingleOrNull();
        if (row == null) return null;
        final payee = row.payeeId == null
            ? null
            : await (_db.select(_db.ledgerPayees)..where((p) => p.id.equals(row.payeeId!))).getSingleOrNull();
        return {
          ...base,
          'id': row.id,
          'accountId': row.accountId,
          'date': row.date,
          'amountCents': row.amountCents,
          'payeeId': row.payeeId,
          'payeeName': payee?.name,
          'categoryId': row.categoryId,
          'notes': row.notes,
          'cleared': row.cleared,
          'importedId': row.importedId,
          'startingBalance': row.startingBalance,
        };
      case 'budget':
        final split = entry.rowId.lastIndexOf('|');
        final categoryId = entry.rowId.substring(0, split);
        final month = entry.rowId.substring(split + 1);
        final row =
            await (_db.select(_db.ledgerBudgets)..where(
                  (b) => b.scope.equals(entry.scope) & b.categoryId.equals(categoryId) & b.month.equals(month),
                ))
                .getSingleOrNull();
        return row == null
            ? null
            : {...base, 'categoryId': categoryId, 'month': month, 'budgetedCents': row.budgetedCents};
    }
    return null;
  }

  /// Applies one request's answers in one database transaction. Returns how
  /// many entries Actual refused.
  Future<int> _applyAnswers(
    List<(LedgerOutboxData, Map<String, dynamic>)> entries,
    List<Map<String, dynamic>> answers,
  ) {
    final bySeq = {for (final a in answers) a['seq'] as int: a};
    return _db.transaction(() async {
      var failed = 0;
      for (final (sent, _) in entries) {
        final answer = bySeq[sent.seq];
        final entry = _db.update(_db.ledgerOutbox)..where((o) => o.seq.equals(sent.seq));
        if (answer == null || answer['ok'] != true) {
          failed++;
          final code = answer?['code'] as String? ?? 'NO_ANSWER';
          _log.warn('Ledger change refused', {'kind': sent.kind, 'id': sent.rowId, 'code': code});
          await entry.write(LedgerOutboxCompanion(attempts: Value(sent.attempts + 1), lastError: Value(code)));
          continue;
        }
        if (answer['gone'] == true) {
          await _markGone(sent);
          await (_db.delete(_db.ledgerOutbox)..where((o) => o.seq.equals(sent.seq))).go();
          continue;
        }
        final newId = answer['id'] as String?;
        final rowId = newId ?? sent.rowId;
        if (newId != null && newId != sent.rowId) await _rekey(sent.kind, sent.rowId, newId);

        final current = await (_db.select(_db.ledgerOutbox)..where((o) => o.seq.equals(sent.seq))).getSingleOrNull();
        if (current == null) continue;
        if (current.revision == sent.revision) {
          await (_db.delete(_db.ledgerOutbox)..where((o) => o.seq.equals(sent.seq))).go();
        } else {
          // Changed while it was on its way: the next run sends the newer
          // version, under the row's new id.
          await (_db.delete(_db.ledgerOutbox)..where(
                (o) => o.kind.equals(sent.kind) & o.rowId.equals(rowId) & o.seq.equals(sent.seq).not(),
              ))
              .go();
          await entry.write(LedgerOutboxCompanion(rowId: Value(rowId), attempts: const Value(0)));
        }
      }
      return failed;
    });
  }

  /// Removed in Actual meanwhile. A pull has skipped this row while it was
  /// pending, so it won't say so again.
  Future<void> _markGone(LedgerOutboxData sent) async {
    final at = Value(_now().millisecondsSinceEpoch);
    if (sent.kind == 'transaction') {
      await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(sent.rowId))).write(
        LedgerTransactionsCompanion(deleted: const Value(true), updatedAt: at),
      );
    } else if (sent.kind == 'account') {
      await (_db.update(_db.ledgerAccounts)..where((a) => a.id.equals(sent.rowId))).write(
        LedgerAccountsCompanion(deleted: const Value(true), updatedAt: at),
      );
    }
  }

  /// The row takes Actual's id, and what points at it follows. Actual may
  /// already have that row (a statement line it matched, a payee of that
  /// name), and the phone's copy of it gives way; the next pull has Actual's
  /// version anyway.
  Future<void> _rekey(String kind, String phoneId, String actualId) async {
    switch (kind) {
      case 'transaction':
        await (_db.delete(_db.ledgerTransactions)..where((t) => t.id.equals(actualId))).go();
        await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(phoneId))).write(
          LedgerTransactionsCompanion(id: Value(actualId)),
        );
      case 'payee':
        await (_db.delete(_db.ledgerPayees)..where((p) => p.id.equals(actualId))).go();
        await (_db.update(_db.ledgerPayees)..where((p) => p.id.equals(phoneId))).write(
          LedgerPayeesCompanion(id: Value(actualId)),
        );
        await (_db.update(_db.ledgerTransactions)..where((t) => t.payeeId.equals(phoneId))).write(
          LedgerTransactionsCompanion(payeeId: Value(actualId)),
        );
      case 'account':
        // Transactions point at accounts with a foreign key: new row first.
        final row = await (_db.select(_db.ledgerAccounts)..where((a) => a.id.equals(phoneId))).getSingle();
        await _db
            .into(_db.ledgerAccounts)
            .insert(row.toCompanion(false).copyWith(id: Value(actualId)), mode: InsertMode.insertOrIgnore);
        await (_db.update(_db.ledgerTransactions)..where((t) => t.accountId.equals(phoneId))).write(
          LedgerTransactionsCompanion(accountId: Value(actualId)),
        );
        await (_db.delete(_db.ledgerAccounts)..where((a) => a.id.equals(phoneId))).go();
    }
    await _db
        .into(_db.ledgerIdAliases)
        .insertOnConflictUpdate(LedgerIdAliasesCompanion.insert(phoneId: phoneId, actualId: actualId));
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
