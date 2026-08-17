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
 */

const DB_PATH = process.env.CATEGORY_DB_PATH ?? './data/categories.db';

let db: Database.Database | undefined;

function getDb(): Database.Database {
  if (db) return db;

  const dir = path.dirname(DB_PATH);
  if (dir && dir !== '.') fs.mkdirSync(dir, { recursive: true });

  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.exec(`
    CREATE TABLE IF NOT EXISTS payee_categories (
      payee_key     TEXT PRIMARY KEY,
      payee_label   TEXT NOT NULL,
      category_id   TEXT NOT NULL,
      category_name TEXT,
      updated_at    TEXT NOT NULL
    )
  `);
  return db;
}

function normalizeKey(payee: string): string {
  return payee.trim().toLowerCase().replace(/\s+/g, ' ');
}

export interface CategoryMapping {
  payee: string;
  categoryId: string;
  categoryName?: string;
  updatedAt: string;
}

export function lookupCategory(payee: string): { categoryId: string; categoryName?: string } | null {
  const row = getDb()
    .prepare('SELECT category_id, category_name FROM payee_categories WHERE payee_key = ?')
    .get(normalizeKey(payee)) as { category_id: string; category_name: string | null } | undefined;

  if (!row) return null;
  return { categoryId: row.category_id, categoryName: row.category_name ?? undefined };
}

export function rememberCategory(payee: string, categoryId: string, categoryName?: string): void {
  getDb()
    .prepare(
      `INSERT INTO payee_categories (payee_key, payee_label, category_id, category_name, updated_at)
       VALUES (@key, @label, @categoryId, @categoryName, @updatedAt)
       ON CONFLICT(payee_key) DO UPDATE SET
         payee_label = excluded.payee_label,
         category_id = excluded.category_id,
         category_name = excluded.category_name,
         updated_at = excluded.updated_at`,
    )
    .run({
      key: normalizeKey(payee),
      label: payee,
      categoryId,
      categoryName: categoryName ?? null,
      updatedAt: new Date().toISOString(),
    });
}

/** Bulk upsert used by the learn-from-Actual sync. Returns how many rows were written. */
export function rememberCategories(entries: Array<{ payee: string; categoryId: string; categoryName?: string }>): number {
  const runAll = getDb().transaction((items: typeof entries) => {
    for (const item of items) rememberCategory(item.payee, item.categoryId, item.categoryName);
  });
  runAll(entries);
  return entries.length;
}

export function listCategoryMappings(): CategoryMapping[] {
  const rows = getDb()
    .prepare('SELECT payee_label, category_id, category_name, updated_at FROM payee_categories ORDER BY payee_label')
    .all() as Array<{ payee_label: string; category_id: string; category_name: string | null; updated_at: string }>;

  return rows.map((r) => ({
    payee: r.payee_label,
    categoryId: r.category_id,
    categoryName: r.category_name ?? undefined,
    updatedAt: r.updated_at,
  }));
}

export function deleteCategoryMapping(payee: string): boolean {
  const result = getDb().prepare('DELETE FROM payee_categories WHERE payee_key = ?').run(normalizeKey(payee));
  return result.changes > 0;
}

export function closeCategoryDb(): void {
  if (db) {
    db.close();
    db = undefined;
  }
}
