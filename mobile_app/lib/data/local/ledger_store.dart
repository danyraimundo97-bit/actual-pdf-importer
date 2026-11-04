import 'dart:math';

import 'package:drift/drift.dart';

import 'db/app_database.dart';

/// The phone's scope: its own budget, before (or without) Actual.
const phoneScope = '';

/// A transaction to add, before it has an id.
class LedgerDraft {
  final DateTime date;
  final int amountCents;
  final String? payee;
  final String? categoryId;
  final String? notes;

  /// `pdfimport-…` or `app-<clientId>`; a second draft with the same one in
  /// the same account is skipped.
  final String? importedId;

  const LedgerDraft({
    required this.date,
    required this.amountCents,
    this.payee,
    this.categoryId,
    this.notes,
    this.importedId,
  });
}

/// An account with its balance (every live top-level row, transfers and
/// the opening balance included), for lists.
typedef LedgerAccountView = ({LedgerAccount account, int balanceCents});

/// The local ledger (docs/plans/local-ledger.md, Phase 2): accounts,
/// payees, transactions and budget amounts on the phone. Every change also
/// queues its row in [LedgerOutbox], in the same database transaction, for
/// the sync with Actual (Phase 5).
class LedgerStore {
  LedgerStore(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  int get _at => _now().millisecondsSinceEpoch;

  // Accounts -----------------------------------------------------------------

  /// Live accounts in their order, open ones first, with balances.
  Stream<List<LedgerAccountView>> watchAccounts(String scope) {
    final balance = _db.ledgerTransactions.amountCents.sum();
    final query =
        _db.select(_db.ledgerAccounts).join([
            leftOuterJoin(
              _db.ledgerTransactions,
              _db.ledgerTransactions.accountId.equalsExp(_db.ledgerAccounts.id) &
                  _db.ledgerTransactions.deleted.equals(false) &
                  _db.ledgerTransactions.parentId.isNull(),
              useColumns: false,
            ),
          ])
          ..addColumns([balance])
          ..where(_db.ledgerAccounts.scope.equals(scope) & _db.ledgerAccounts.deleted.equals(false))
          ..groupBy([_db.ledgerAccounts.id])
          ..orderBy([OrderingTerm.asc(_db.ledgerAccounts.closed), OrderingTerm.asc(_db.ledgerAccounts.sort)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows) (account: row.readTable(_db.ledgerAccounts), balanceCents: row.read(balance) ?? 0),
      ],
    );
  }

  Future<LedgerAccount?> account(String id) =>
      (_db.select(_db.ledgerAccounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// A new account; a non-zero [openingBalanceCents] becomes its opening
  /// balance transaction on [openedOn] (today by default).
  Future<String> createAccount(
    String scope, {
    required String name,
    bool offBudget = false,
    int openingBalanceCents = 0,
    DateTime? openedOn,
    String? bankId,
  }) {
    return _db.transaction(() async {
      final id = 'acct:${_uuid()}';
      final sort = await _nextAccountSort(scope);
      await _db
          .into(_db.ledgerAccounts)
          .insert(
            LedgerAccountsCompanion.insert(
              id: id,
              scope: scope,
              name: name.trim(),
              offBudget: Value(offBudget),
              sort: sort,
              bankId: Value(bankId),
              updatedAt: _at,
            ),
          );
      await _queue(scope, 'account', id);
      if (openingBalanceCents != 0) {
        await _putOpeningBalance(scope, id, openingBalanceCents, openedOn ?? _now());
      }
      return id;
    });
  }

  Future<void> updateAccount(String id, {String? name, bool? offBudget, bool? closed, String? bankId}) {
    return _db.transaction(() async {
      final account = await _requireAccount(id);
      await (_db.update(_db.ledgerAccounts)..where((a) => a.id.equals(id))).write(
        LedgerAccountsCompanion(
          name: name == null ? const Value.absent() : Value(name.trim()),
          offBudget: Value.absentIfNull(offBudget),
          closed: Value.absentIfNull(closed),
          bankId: Value.absentIfNull(bankId),
          updatedAt: Value(_at),
        ),
      );
      await _queue(account.scope, 'account', id);
    });
  }

  /// [ids] in their new order; ids of other scopes are ignored.
  Future<void> reorderAccounts(String scope, List<String> ids) {
    return _db.transaction(() async {
      for (final (i, id) in ids.indexed) {
        final changed = await (_db.update(_db.ledgerAccounts)..where((a) => a.id.equals(id) & a.scope.equals(scope)))
            .write(LedgerAccountsCompanion(sort: Value(i), updatedAt: Value(_at)));
        if (changed > 0) await _queue(scope, 'account', id);
      }
    });
  }

  /// The account's opening balance (0 when it has none).
  Future<int> openingBalance(String accountId) async {
    final row = await _openingBalanceRow(accountId);
    return row?.amountCents ?? 0;
  }

  /// Sets, changes or (with 0) removes the opening balance.
  Future<void> setOpeningBalance(String accountId, int cents, {DateTime? on}) {
    return _db.transaction(() async {
      final account = await _requireAccount(accountId);
      final existing = await _openingBalanceRow(accountId);
      if (existing == null) {
        if (cents != 0) await _putOpeningBalance(account.scope, accountId, cents, on ?? _now());
      } else if (cents == 0) {
        await _tombstone(existing);
      } else if (cents != existing.amountCents || on != null) {
        await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(existing.id))).write(
          LedgerTransactionsCompanion(
            amountCents: Value(cents),
            date: on == null ? const Value.absent() : Value(ledgerDate(on)),
            updatedAt: Value(_at),
          ),
        );
        await _queue(account.scope, 'transaction', existing.id);
      }
    });
  }

  Future<LedgerTransaction?> _openingBalanceRow(String accountId) =>
      (_db.select(_db.ledgerTransactions)
            ..where((t) => t.accountId.equals(accountId) & t.startingBalance.equals(true) & t.deleted.equals(false)))
          .getSingleOrNull();

  Future<void> _putOpeningBalance(String scope, String accountId, int cents, DateTime on) async {
    final id = 'tx:${_uuid()}';
    await _db
        .into(_db.ledgerTransactions)
        .insert(
          LedgerTransactionsCompanion.insert(
            id: id,
            scope: scope,
            accountId: accountId,
            date: ledgerDate(on),
            amountCents: cents,
            startingBalance: const Value(true),
            cleared: const Value(true),
            createdAt: _at,
            updatedAt: _at,
          ),
        );
    await _queue(scope, 'transaction', id);
  }

  Future<int> _nextAccountSort(String scope) async {
    final max = _db.ledgerAccounts.sort.max();
    final row =
        await (_db.selectOnly(_db.ledgerAccounts)
              ..addColumns([max])
              ..where(_db.ledgerAccounts.scope.equals(scope)))
            .getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  Future<LedgerAccount> _requireAccount(String id) async {
    final account = await this.account(id);
    if (account == null || account.deleted) throw StateError('No account $id.');
    return account;
  }

  // Payees -------------------------------------------------------------------

  /// The live payee named [name] in [scope] (ignoring case and outer
  /// spaces), created if missing.
  Future<String> payeeId(String scope, String name) async {
    final trimmed = name.trim();
    final existing =
        await (_db.select(_db.ledgerPayees)
              ..where(
                (p) => p.scope.equals(scope) & p.deleted.equals(false) & p.name.lower().equals(trimmed.toLowerCase()),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = 'payee:${_uuid()}';
    await _db
        .into(_db.ledgerPayees)
        .insert(LedgerPayeesCompanion.insert(id: id, scope: scope, name: trimmed, updatedAt: _at));
    await _queue(scope, 'payee', id);
    return id;
  }

  // Transactions -------------------------------------------------------------

  Future<LedgerTransaction?> transaction(String id) =>
      (_db.select(_db.ledgerTransactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Adds one transaction. Returns null when [LedgerDraft.importedId] is
  /// already in the account (a retried quick add).
  Future<String?> addTransaction(String accountId, LedgerDraft draft) async {
    final result = await addTransactions(accountId, [draft]);
    return result.ids.isEmpty ? null : result.ids.single;
  }

  /// Adds a statement's transactions, skipping any whose importedId the
  /// account already has (removed ones included, as Actual does), so
  /// importing the same statement twice adds nothing.
  Future<({int added, int skipped, List<String> ids})> addTransactions(String accountId, List<LedgerDraft> drafts) {
    return _db.transaction(() async {
      final account = await _requireAccount(accountId);
      final wanted = {for (final d in drafts) ?d.importedId};
      final known = wanted.isEmpty
          ? <String>{}
          : {
              for (final t in await (_db.select(
                _db.ledgerTransactions,
              )..where((t) => t.accountId.equals(accountId) & t.importedId.isIn(wanted))).get())
                t.importedId!,
            };
      final ids = <String>[];
      var skipped = 0;
      for (final draft in drafts) {
        if (draft.importedId != null && !known.add(draft.importedId!)) {
          skipped++;
          continue;
        }
        final payee = draft.payee?.trim();
        final id = 'tx:${_uuid()}';
        await _db
            .into(_db.ledgerTransactions)
            .insert(
              LedgerTransactionsCompanion.insert(
                id: id,
                scope: account.scope,
                accountId: accountId,
                date: ledgerDate(draft.date),
                amountCents: draft.amountCents,
                payeeId: Value(payee == null || payee.isEmpty ? null : await payeeId(account.scope, payee)),
                categoryId: Value(draft.categoryId),
                notes: Value(draft.notes),
                importedId: Value(draft.importedId),
                createdAt: _at,
                updatedAt: _at,
              ),
            );
        await _queue(account.scope, 'transaction', id);
        ids.add(id);
      }
      return (added: ids.length, skipped: skipped, ids: ids);
    });
  }

  /// Saves a reviewed statement ([addTransactions]) keeping the account's
  /// opening balance true. That balance is what the account held on its
  /// date ("Balance today" when the account was added), so statement lines
  /// on or before that date were already in it: the opening balance gives
  /// them back and moves to the day before the earliest one. The balance on
  /// the opening date stays what the user said.
  Future<({int added, int skipped, List<String> ids})> addStatement(String accountId, List<LedgerDraft> drafts) {
    return _db.transaction(() async {
      final opening = await _openingBalanceRow(accountId);
      final saved = await addTransactions(accountId, drafts);
      if (opening == null || saved.ids.isEmpty) return saved;
      final earlier = await (_db.select(
        _db.ledgerTransactions,
      )..where((t) => t.id.isIn(saved.ids) & t.date.isSmallerOrEqualValue(opening.date))).get();
      if (earlier.isEmpty) return saved;
      final earliest = DateTime.parse(earlier.map((t) => t.date).reduce((a, b) => a.compareTo(b) <= 0 ? a : b));
      await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(opening.id))).write(
        LedgerTransactionsCompanion(
          amountCents: Value(opening.amountCents - earlier.fold(0, (sum, t) => sum + t.amountCents)),
          date: Value(ledgerDate(DateTime(earliest.year, earliest.month, earliest.day - 1))),
          updatedAt: Value(_at),
        ),
      );
      await _queue(opening.scope, 'transaction', opening.id);
      return saved;
    });
  }

  /// Changes a transaction's fields; `importedId` never changes (it's the
  /// dedupe key, see CLAUDE.md). Pass [clearCategory] to remove the category.
  Future<void> updateTransaction(
    String id, {
    DateTime? date,
    int? amountCents,
    String? payee,
    String? categoryId,
    bool clearCategory = false,
    String? notes,
    String? accountId,
  }) {
    return _db.transaction(() async {
      final tx = await transaction(id);
      if (tx == null || tx.deleted) throw StateError('No transaction $id.');
      if (tx.transferId != null || tx.isParent || tx.parentId != null) {
        throw StateError('Transfers and split transactions are read-only on the phone.');
      }
      if (accountId != null) await _requireAccount(accountId);
      final payeeName = payee?.trim();
      await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(id))).write(
        LedgerTransactionsCompanion(
          date: date == null ? const Value.absent() : Value(ledgerDate(date)),
          amountCents: Value.absentIfNull(amountCents),
          payeeId: payeeName == null
              ? const Value.absent()
              : Value(payeeName.isEmpty ? null : await payeeId(tx.scope, payeeName)),
          categoryId: clearCategory ? const Value(null) : Value.absentIfNull(categoryId),
          notes: Value.absentIfNull(notes),
          accountId: Value.absentIfNull(accountId),
          updatedAt: Value(_at),
        ),
      );
      await _queue(tx.scope, 'transaction', id);
    });
  }

  /// Removes a transaction (a tombstone; Actual gets a soft delete).
  Future<void> deleteTransaction(String id) {
    return _db.transaction(() async {
      final tx = await transaction(id);
      if (tx == null || tx.deleted) return;
      await _tombstone(tx);
    });
  }

  /// Removes several transactions (undoing a saved statement). Returns how
  /// many were removed; ones already removed or unknown are skipped.
  Future<({int removed, int skipped})> deleteTransactions(List<String> ids) {
    return _db.transaction(() async {
      var removed = 0;
      for (final id in ids) {
        final tx = await transaction(id);
        if (tx == null || tx.deleted) continue;
        await _tombstone(tx);
        removed++;
      }
      return (removed: removed, skipped: ids.length - removed);
    });
  }

  Future<void> _tombstone(LedgerTransaction tx) async {
    await (_db.update(_db.ledgerTransactions)..where((t) => t.id.equals(tx.id))).write(
      LedgerTransactionsCompanion(deleted: const Value(true), updatedAt: Value(_at)),
    );
    await _queue(tx.scope, 'transaction', tx.id, op: 'delete');
  }

  /// An account's live transactions, newest first.
  Future<List<LedgerTransaction>> transactions(String accountId, {int? limit, int offset = 0}) {
    final query = _db.select(_db.ledgerTransactions)
      ..where((t) => t.accountId.equals(accountId) & t.deleted.equals(false) & t.parentId.isNull())
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Every live transaction of a scope, split children included (the
  /// builders in ledger_builders.dart read them).
  Future<List<LedgerTransaction>> allTransactions(String scope) =>
      (_db.select(_db.ledgerTransactions)..where((t) => t.scope.equals(scope) & t.deleted.equals(false))).get();

  /// A scope's accounts, closed ones included.
  Future<List<LedgerAccount>> accounts(String scope) =>
      (_db.select(_db.ledgerAccounts)
            ..where((a) => a.scope.equals(scope) & a.deleted.equals(false))
            ..orderBy([(a) => OrderingTerm(expression: a.sort)]))
          .get();

  /// Payee id → name for a scope.
  Future<Map<String, String>> payeeNames(String scope) async => {
    for (final p in await (_db.select(_db.ledgerPayees)..where((p) => p.scope.equals(scope))).get()) p.id: p.name,
  };

  /// Every budget amount of a scope, all months (envelopes carry over).
  Future<List<LedgerBudget>> allBudgets(String scope) =>
      (_db.select(_db.ledgerBudgets)..where((b) => b.scope.equals(scope))).get();

  /// The budget style ('tracking' unless chosen otherwise). For the phone's
  /// scope it's the user's choice (Phase 7); for an Actual budget, Actual's.
  Future<String?> budgetMode(String scope) async =>
      (await (_db.select(_db.ledgerSyncState)..where((s) => s.scope.equals(scope))).getSingleOrNull())?.budgetMode;

  Future<void> setBudgetMode(String scope, String mode) => _db
      .into(_db.ledgerSyncState)
      .insert(
        LedgerSyncStateCompanion.insert(scope: scope, budgetMode: Value(mode)),
        onConflict: DoUpdate((_) => LedgerSyncStateCompanion(budgetMode: Value(mode))),
      );

  /// Fires whenever a ledger table changes, for screens that recompute.
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.ledgerAccounts,
          _db.ledgerPayees,
          _db.ledgerTransactions,
          _db.ledgerBudgets,
          _db.ledgerSyncState,
        ]),
      )
      .map((_) {});

  // Budget amounts -----------------------------------------------------------

  Future<void> setBudget(String scope, String categoryId, String month, int cents) {
    _checkMonth(month);
    return _db.transaction(() async {
      await _db
          .into(_db.ledgerBudgets)
          .insert(
            LedgerBudgetsCompanion.insert(
              scope: scope,
              categoryId: categoryId,
              month: month,
              budgetedCents: cents,
              updatedAt: _at,
            ),
            onConflict: DoUpdate(
              (_) => LedgerBudgetsCompanion(budgetedCents: Value(cents), updatedAt: Value(_at)),
              target: [_db.ledgerBudgets.scope, _db.ledgerBudgets.categoryId, _db.ledgerBudgets.month],
            ),
          );
      await _queue(scope, 'budget', '$categoryId|$month');
    });
  }

  Future<Map<String, int>> budgets(String scope, String month) async {
    _checkMonth(month);
    final rows = await (_db.select(
      _db.ledgerBudgets,
    )..where((b) => b.scope.equals(scope) & b.month.equals(month))).get();
    return {for (final b in rows) b.categoryId: b.budgetedCents};
  }

  /// Copies last month's amounts into [month] for categories that have none
  /// there yet. Returns how many were copied.
  Future<int> copyPreviousMonth(String scope, String month) async {
    _checkMonth(month);
    final previous = await budgets(scope, previousMonth(month));
    final current = await budgets(scope, month);
    var copied = 0;
    for (final MapEntry(key: categoryId, value: cents) in previous.entries) {
      if (current.containsKey(categoryId) || cents == 0) continue;
      await setBudget(scope, categoryId, month, cents);
      copied++;
    }
    return copied;
  }

  // Outbox -------------------------------------------------------------------

  /// Entries waiting for the sync, oldest first.
  Future<List<LedgerOutboxData>> outbox(String scope) =>
      (_db.select(_db.ledgerOutbox)
            ..where((o) => o.scope.equals(scope))
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  Stream<int> watchOutboxCount(String scope) {
    final count = _db.ledgerOutbox.seq.count();
    return (_db.selectOnly(_db.ledgerOutbox)
          ..addColumns([count])
          ..where(_db.ledgerOutbox.scope.equals(scope)))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  /// One entry per row: a later change keeps the entry's place in the queue
  /// and only updates what to do with it.
  Future<void> _queue(String scope, String kind, String rowId, {String op = 'put'}) async {
    await _db
        .into(_db.ledgerOutbox)
        .insert(
          LedgerOutboxCompanion.insert(scope: scope, kind: kind, rowId: rowId, op: op, createdAt: _at),
          onConflict: DoUpdate(
            (_) => LedgerOutboxCompanion(op: Value(op), scope: Value(scope)),
            target: [_db.ledgerOutbox.kind, _db.ledgerOutbox.rowId],
          ),
        );
  }

  static final _random = Random.secure();

  static String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// YYYY-MM-DD, as the ledger and Actual store dates.
String ledgerDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The month before a YYYY-MM month.
String previousMonth(String month) {
  _checkMonth(month);
  final year = int.parse(month.substring(0, 4));
  final m = int.parse(month.substring(5, 7));
  return m == 1 ? '${year - 1}-12' : '$year-${(m - 1).toString().padLeft(2, '0')}';
}

final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

void _checkMonth(String month) {
  if (!_monthPattern.hasMatch(month)) throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
}
