import 'package:drift/drift.dart';

// The local ledger (docs/plans/local-ledger.md): the phone's own accounts,
// payees, transactions and budget amounts, schema 3.
//
// Every row has a `scope`: '' for the phone's own budget (no Actual yet), or
// the `budgetSyncId` of the Actual budget it mirrors (Phase 5). Ids are the
// phone's ('acct:<uuid>', 'payee:<uuid>', 'tx:<uuid>') until a row reaches
// Actual, then Actual's. Times are epoch milliseconds. Nothing is deleted:
// `deleted` is a tombstone the sync carries to Actual as a soft delete.

class LedgerAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get name => text()();
  BoolColumn get offBudget => boolean().withDefault(const Constant(false))();
  BoolColumn get closed => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer()();

  /// The statement parser's bank id, to suggest this account on import.
  TextColumn get bankId => text().nullable()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LedgerPayees extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get name => text()();

  /// Set for Actual's transfer payees ("Transfer: Savings").
  TextColumn get transferAccountId => text().nullable()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'ledger_transactions_account_date', columns: {#accountId, #date})
@TableIndex(name: 'ledger_transactions_scope_date', columns: {#scope, #date})
@TableIndex(name: 'ledger_transactions_account_imported', columns: {#accountId, #importedId})
class LedgerTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get accountId => text().references(LedgerAccounts, #id)();

  /// YYYY-MM-DD.
  TextColumn get date => text()();
  IntColumn get amountCents => integer()();
  TextColumn get payeeId => text().nullable()();

  /// The phone's category id (`preset:…`, `local:<uuid>`, `actual:<id>`).
  /// No foreign key: an Actual category can arrive after its transactions.
  TextColumn get categoryId => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get cleared => boolean().withDefault(const Constant(false))();

  /// `pdfimport-…` (a statement) or `app-<clientId>` (quick add), as in
  /// Actual: importing the same statement twice adds nothing.
  TextColumn get importedId => text().nullable()();
  BoolColumn get startingBalance => boolean().withDefault(const Constant(false))();

  /// From Actual (Phase 5); read-only on the phone in v1.
  TextColumn get transferId => text().nullable()();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isParent => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  // Not unique (schema 4): Actual doesn't enforce it, so a pulled budget
  // can hold two rows with one importedId. LedgerStore still skips a
  // known importedId when the phone adds rows.
}

/// An Actual budget's categories, as pulled (schema 4; the phone's own
/// budget uses the app's categories in app_database.dart). The group is
/// kept on each row: the budget lists them grouped and in order.
class LedgerCategories extends Table {
  TextColumn get scope => text()();
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer()();
  TextColumn get groupId => text()();
  TextColumn get groupName => text()();
  BoolColumn get groupIsIncome => boolean().withDefault(const Constant(false))();
  BoolColumn get groupHidden => boolean().withDefault(const Constant(false))();
  IntColumn get groupSort => integer()();

  @override
  Set<Column> get primaryKey => {scope, id};
}

/// The amount budgeted for a category in a month.
class LedgerBudgets extends Table {
  TextColumn get scope => text()();
  TextColumn get categoryId => text()();

  /// YYYY-MM.
  TextColumn get month => text()();
  IntColumn get budgetedCents => integer()();

  /// Envelope budgets: overspending carries into next month.
  BoolColumn get carryover => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {scope, categoryId, month};
}

/// Rows changed on the phone and not yet sent to Actual. One entry per row
/// (a second change keeps the entry and its place in the queue); the sync
/// sends the row as it is when it runs.
class LedgerOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get scope => text()();

  /// 'account' | 'payee' | 'transaction' | 'budget'.
  TextColumn get kind => text()();

  /// The row's id; for a budget amount, `<categoryId>|<YYYY-MM>`.
  TextColumn get rowId => text()();

  /// 'put' | 'delete'.
  TextColumn get op => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// An error code from the last attempt, never a message carrying data.
  TextColumn get lastError => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {kind, rowId},
  ];
}

class LedgerSyncState extends Table {
  TextColumn get scope => text()();

  /// 'tracking' | 'envelope'; for the phone's own scope, the user's choice.
  TextColumn get budgetMode => text().nullable()();
  IntColumn get lastPulledAt => integer().nullable()();

  /// The backend's change-log cursor (Phase 0).
  TextColumn get cursorEpoch => text().nullable()();
  IntColumn get cursorLastId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {scope};
}
