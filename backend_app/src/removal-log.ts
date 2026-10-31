import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

/**
 * The backend's record of soft-deleted transactions (see undoImport in
 * actual.ts). Undoing an import never deletes anything in Actual: it zeroes
 * the amount and adds a note. This log keeps what was there before — the
 * original amount and notes — so a removal can be audited or reversed.
 *
 * Lives next to the category memory, so Docker's data volume (which sets
 * CATEGORY_DB_PATH) persists it with no extra configuration.
 */
const DB_PATH =
  process.env.REMOVAL_LOG_PATH ??
  path.join(path.dirname(process.env.CATEGORY_DB_PATH ?? './data/categories.db'), 'removed-transactions.db');

export interface RemovedTransaction {
  transactionId: string;
  budgetSyncId: string;
  accountId: string;
  importedId: string;
  date: string;
  payee?: string;
  originalAmountCents: number;
  originalNotes?: string;
  removedAt: string;
}

let db: Database.Database | undefined;

function getDb(): Database.Database {
  if (db) return db;
  const dir = path.dirname(DB_PATH);
  if (dir && dir !== '.') fs.mkdirSync(dir, { recursive: true });
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.exec(`
    CREATE TABLE IF NOT EXISTS removed_transactions (
      transaction_id        TEXT PRIMARY KEY,
      budget_sync_id        TEXT NOT NULL,
      account_id            TEXT NOT NULL,
      imported_id           TEXT NOT NULL,
      date                  TEXT NOT NULL,
      payee                 TEXT,
      original_amount_cents INTEGER NOT NULL,
      original_notes        TEXT,
      removed_at            TEXT NOT NULL
    )
  `);
  return db;
}

/**
 * Records soft-deleted transactions. A transaction already recorded keeps
 * its first entry: that one holds the real original amount, while a later
 * record would only see the zeroed one.
 */
export function recordRemovals(rows: RemovedTransaction[]): void {
  const insert = getDb().prepare(`
    INSERT OR IGNORE INTO removed_transactions
      (transaction_id, budget_sync_id, account_id, imported_id, date, payee,
       original_amount_cents, original_notes, removed_at)
    VALUES (@transactionId, @budgetSyncId, @accountId, @importedId, @date, @payee,
            @originalAmountCents, @originalNotes, @removedAt)
  `);
  getDb().transaction((all: RemovedTransaction[]) => {
    for (const r of all) insert.run({ payee: null, originalNotes: null, ...r });
  })(rows);
}

export function listRemovals(budgetSyncId: string): RemovedTransaction[] {
  const rows = getDb()
    .prepare('SELECT * FROM removed_transactions WHERE budget_sync_id = ? ORDER BY removed_at DESC')
    .all(budgetSyncId) as Array<Record<string, string | number | null>>;
  return rows.map((r) => ({
    transactionId: r.transaction_id as string,
    budgetSyncId: r.budget_sync_id as string,
    accountId: r.account_id as string,
    importedId: r.imported_id as string,
    date: r.date as string,
    payee: (r.payee as string | null) ?? undefined,
    originalAmountCents: r.original_amount_cents as number,
    originalNotes: (r.original_notes as string | null) ?? undefined,
    removedAt: r.removed_at as string,
  }));
}

export function closeRemovalLog(): void {
  if (db) {
    db.close();
    db = undefined;
  }
}
