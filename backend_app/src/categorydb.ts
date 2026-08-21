import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';

/**
 * Local, offline "memory" of which category a payee usually belongs to.
 * A single SQLite file — no server process, easy to back up (just copy the
 * file), fits the project's self-hosted/offline constraints.
 *
 * Populated two ways:
 *   - directly, via rememberCategory() (see the POST /categories route in
 *     server.ts)
 *   - by syncing already-categorized transactions back from Actual itself
 *     (see learnCategoriesFromActual() in actual.ts, POST
 *     /categories/learn-from-actual)
 *
 * Matching is exact, on cleaned-and-normalized payee text — it does not do
 * fuzzy/substring matching the way Actual's own rules engine can. That's
 * fine for "this exact merchant string recurs verbatim," which is the
 * common case once a bank parser's prefix-stripping settles the payee down
 * to just the merchant name. For anything fuzzier, Actual's own rules are
 * still the right tool — this cache and that rules engine are complementary,
 * not a replacement for each other.
 *
 * Scoped per budget (budgetSyncId): a category id only means something
 * inside the budget it was created in, so a mapping learned in one budget
 * would otherwise silently mis-categorize transactions in another. Every
 * function below takes an optional budgetSyncId (default '' = "unscoped").
 * lookupCategory() falls back to the '' bucket when a budget-specific
 * lookup misses, which is also where every mapping written before this
 * scoping existed lives after the one-time migration below — nothing
 * learned pre-upgrade is lost.
 */

const DB_PATH = process.env.CATEGORY_DB_PATH ?? './data/categories.db';
const UNSCOPED = '';

let db: Database.Database | undefined;

function createTableSql(): string {
  return `
    CREATE TABLE IF NOT EXISTS payee_categories (
      budget_sync_id TEXT NOT NULL DEFAULT '',
      payee_key      TEXT NOT NULL,
      payee_label    TEXT NOT NULL,
      category_id    TEXT NOT NULL,
      category_name  TEXT,
      updated_at     TEXT NOT NULL,
      PRIMARY KEY (budget_sync_id, payee_key)
    )
  `;
}

function getDb(): Database.Database {
  if (db) return db;

  const dir = path.dirname(DB_PATH);
  if (dir && dir !== '.') fs.mkdirSync(dir, { recursive: true });

  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  const existing = db
    .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'payee_categories'")
    .get();

  const hasBudgetColumn = existing
    ? (db.prepare('PRAGMA table_info(payee_categories)').all() as Array<{ name: string }>).some(
        (c) => c.name === 'budget_sync_id',
      )
    : false;

  if (existing && !hasBudgetColumn) {
    // Pre-multi-budget install: migrate the old single-budget table
    // forward into the '' ("unscoped") bucket instead of dropping it.
    db.exec('ALTER TABLE payee_categories RENAME TO payee_categories_legacy');
    db.exec(createTableSql());
    db.exec(`
      INSERT INTO payee_categories (budget_sync_id, payee_key, payee_label, category_id, category_name, updated_at)
      SELECT '', payee_key, payee_label, category_id, category_name, updated_at FROM payee_categories_legacy
    `);
    db.exec('DROP TABLE payee_categories_legacy');
  } else {
    db.exec(createTableSql());
  }

  return db;
}

function normalizeKey(payee: string): string {
  return payee.trim().toLowerCase().replace(/\s+/g, ' ');
}

function normalizeBudget(budgetSyncId?: string): string {
  return budgetSyncId?.trim() || UNSCOPED;
}

export interface CategoryMapping {
  payee: string;
  categoryId: string;
  categoryName?: string;
  updatedAt: string;
}

export function lookupCategory(
  payee: string,
  budgetSyncId?: string,
): { categoryId: string; categoryName?: string } | null {
  const scope = normalizeBudget(budgetSyncId);
  const key = normalizeKey(payee);
  const database = getDb();

  const row = database
    .prepare('SELECT category_id, category_name FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ?')
    .get(scope, key) as { category_id: string; category_name: string | null } | undefined;
  if (row) return { categoryId: row.category_id, categoryName: row.category_name ?? undefined };

  if (scope !== UNSCOPED) {
    const legacy = database
      .prepare('SELECT category_id, category_name FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ?')
      .get(UNSCOPED, key) as { category_id: string; category_name: string | null } | undefined;
    if (legacy) return { categoryId: legacy.category_id, categoryName: legacy.category_name ?? undefined };
  }

  return null;
}

export function rememberCategory(
  payee: string,
  categoryId: string,
  categoryName?: string,
  budgetSyncId?: string,
): void {
  getDb()
    .prepare(
      `INSERT INTO payee_categories (budget_sync_id, payee_key, payee_label, category_id, category_name, updated_at)
       VALUES (@budgetSyncId, @key, @label, @categoryId, @categoryName, @updatedAt)
       ON CONFLICT(budget_sync_id, payee_key) DO UPDATE SET
         payee_label = excluded.payee_label,
         category_id = excluded.category_id,
         category_name = excluded.category_name,
         updated_at = excluded.updated_at`,
    )
    .run({
      budgetSyncId: normalizeBudget(budgetSyncId),
      key: normalizeKey(payee),
      label: payee,
      categoryId,
      categoryName: categoryName ?? null,
      updatedAt: new Date().toISOString(),
    });
}

/** Bulk upsert used by the learn-from-Actual sync. Returns how many rows were written. */
export function rememberCategories(
  entries: Array<{ payee: string; categoryId: string; categoryName?: string }>,
  budgetSyncId?: string,
): number {
  const runAll = getDb().transaction((items: typeof entries) => {
    for (const item of items) rememberCategory(item.payee, item.categoryId, item.categoryName, budgetSyncId);
  });
  runAll(entries);
  return entries.length;
}

export function listCategoryMappings(budgetSyncId?: string): CategoryMapping[] {
  const rows = getDb()
    .prepare(
      'SELECT payee_label, category_id, category_name, updated_at FROM payee_categories WHERE budget_sync_id = ? ORDER BY payee_label',
    )
    .all(normalizeBudget(budgetSyncId)) as Array<{
    payee_label: string;
    category_id: string;
    category_name: string | null;
    updated_at: string;
  }>;

  return rows.map((r) => ({
    payee: r.payee_label,
    categoryId: r.category_id,
    categoryName: r.category_name ?? undefined,
    updatedAt: r.updated_at,
  }));
}

export function deleteCategoryMapping(payee: string, budgetSyncId?: string): boolean {
  const result = getDb()
    .prepare('DELETE FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ?')
    .run(normalizeBudget(budgetSyncId), normalizeKey(payee));
  return result.changes > 0;
}

export function closeCategoryDb(): void {
  if (db) {
    db.close();
    db = undefined;
  }
}
