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
      deleted        INTEGER NOT NULL DEFAULT 0,
      synced_at      INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (budget_sync_id, payee_key)
    )
  `;
}

/**
 * The app's own categories (groups, categories, links to Actual), kept here
 * so app-data backups and a new phone get them back. Opaque to the backend:
 * `data` is the app's JSON for the row. Newest `updated_at` (epoch ms) wins.
 */
const APP_CATEGORIES_SQL = `
  CREATE TABLE IF NOT EXISTS app_categories (
    kind       TEXT NOT NULL,
    id         TEXT NOT NULL,
    data       TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    synced_at  INTEGER NOT NULL,
    PRIMARY KEY (kind, id)
  )
`;

/**
 * Columns added after the table first shipped. Each is added when missing,
 * so any older file opens: `deleted` makes forgetting a tombstone the app's
 * sync can carry; `synced_at` (epoch ms, server clock) is when the row was
 * last written here, the sync's "since" cursor. 0 = before sync existed,
 * so a first full sync still gets it.
 */
function addMissingColumns(database: Database.Database): void {
  const columns = new Set(
    (database.prepare('PRAGMA table_info(payee_categories)').all() as Array<{ name: string }>).map((c) => c.name),
  );
  if (!columns.has('deleted')) database.exec('ALTER TABLE payee_categories ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0');
  if (!columns.has('synced_at'))
    database.exec('ALTER TABLE payee_categories ADD COLUMN synced_at INTEGER NOT NULL DEFAULT 0');
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
  addMissingColumns(db);
  db.exec(APP_CATEGORIES_SQL);

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
    .prepare('SELECT category_id, category_name FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ? AND deleted = 0')
    .get(scope, key) as { category_id: string; category_name: string | null } | undefined;
  if (row) return { categoryId: row.category_id, categoryName: row.category_name ?? undefined };

  if (scope !== UNSCOPED) {
    const legacy = database
      .prepare('SELECT category_id, category_name FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ? AND deleted = 0')
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
      `INSERT INTO payee_categories
         (budget_sync_id, payee_key, payee_label, category_id, category_name, updated_at, deleted, synced_at)
       VALUES (@budgetSyncId, @key, @label, @categoryId, @categoryName, @updatedAt, 0, @syncedAt)
       ON CONFLICT(budget_sync_id, payee_key) DO UPDATE SET
         payee_label = excluded.payee_label,
         category_id = excluded.category_id,
         category_name = excluded.category_name,
         updated_at = excluded.updated_at,
         deleted = 0,
         synced_at = excluded.synced_at`,
    )
    .run({
      budgetSyncId: normalizeBudget(budgetSyncId),
      key: normalizeKey(payee),
      label: payee,
      categoryId,
      categoryName: categoryName ?? null,
      updatedAt: new Date().toISOString(),
      syncedAt: Date.now(),
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
      'SELECT payee_label, category_id, category_name, updated_at FROM payee_categories WHERE budget_sync_id = ? AND deleted = 0 ORDER BY payee_label',
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

/** Forgets a mapping. A tombstone, not a DELETE, so the app's sync hears of it. */
export function deleteCategoryMapping(payee: string, budgetSyncId?: string): boolean {
  const result = getDb()
    .prepare(
      `UPDATE payee_categories SET deleted = 1, updated_at = ?, synced_at = ?
       WHERE budget_sync_id = ? AND payee_key = ? AND deleted = 0`,
    )
    .run(new Date().toISOString(), Date.now(), normalizeBudget(budgetSyncId), normalizeKey(payee));
  return result.changes > 0;
}

/**
 * Forgets every mapping in one budget's scope and returns how many went.
 * Only that scope: the unscoped bucket is shared by every budget as a
 * fallback, so clearing one budget must not reach into it.
 */
export function clearCategoryMappings(budgetSyncId?: string): number {
  return getDb()
    .prepare(
      `UPDATE payee_categories SET deleted = 1, updated_at = ?, synced_at = ?
       WHERE budget_sync_id = ? AND deleted = 0`,
    )
    .run(new Date().toISOString(), Date.now(), normalizeBudget(budgetSyncId)).changes;
}

// --- Sync with the app (POST /categories/sync) -----------------------------

/** One mapping as the sync carries it. `updatedAt` is epoch ms. */
export interface MappingChange {
  payee: string;
  categoryId: string;
  categoryName?: string;
  updatedAt: number;
  deleted: boolean;
}

/** One of the app's own category rows; `data` is opaque JSON. */
export interface AppCategoryChange {
  kind: string;
  id: string;
  data: unknown;
  updatedAt: number;
}

/**
 * Applies the app's changes (newest `updatedAt` wins per mapping or row,
 * ties keep what's here) and returns everything written here after `since`
 * (server clock, the `now` of the app's previous sync; null = all), with
 * tombstones, plus the new `now`.
 *
 * Mappings are per budget; the app's categories are app-wide. A change the
 * app sends comes back in the same answer only if it lost, which is how the
 * app learns the newer version.
 */
export function syncCategories(input: {
  budgetSyncId: string;
  since: number | null;
  mappings: MappingChange[];
  appCategories: AppCategoryChange[];
}): { mappings: MappingChange[]; appCategories: AppCategoryChange[]; now: number } {
  const database = getDb();
  const scope = normalizeBudget(input.budgetSyncId);
  const now = Date.now();
  const since = input.since ?? 0;

  const run = database.transaction(() => {
    const currentMapping = database.prepare(
      'SELECT updated_at FROM payee_categories WHERE budget_sync_id = ? AND payee_key = ?',
    );
    const writeMapping = database.prepare(
      `INSERT INTO payee_categories
         (budget_sync_id, payee_key, payee_label, category_id, category_name, updated_at, deleted, synced_at)
       VALUES (@scope, @key, @label, @categoryId, @categoryName, @updatedAt, @deleted, @now)
       ON CONFLICT(budget_sync_id, payee_key) DO UPDATE SET
         payee_label = excluded.payee_label, category_id = excluded.category_id,
         category_name = excluded.category_name, updated_at = excluded.updated_at,
         deleted = excluded.deleted, synced_at = excluded.synced_at`,
    );
    const applied = new Set<string>();
    const lost = new Set<string>();
    for (const m of input.mappings) {
      const key = normalizeKey(m.payee);
      const row = currentMapping.get(scope, key) as { updated_at: string } | undefined;
      if (row && Date.parse(row.updated_at) >= m.updatedAt) {
        lost.add(key);
        continue;
      }
      writeMapping.run({
        scope,
        key,
        label: m.payee.trim(),
        categoryId: m.categoryId,
        categoryName: m.categoryName ?? null,
        updatedAt: new Date(m.updatedAt).toISOString(),
        deleted: m.deleted ? 1 : 0,
        now,
      });
      applied.add(key);
    }

    const currentApp = database.prepare('SELECT updated_at FROM app_categories WHERE kind = ? AND id = ?');
    const writeApp = database.prepare(
      `INSERT INTO app_categories (kind, id, data, updated_at, synced_at) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(kind, id) DO UPDATE SET
         data = excluded.data, updated_at = excluded.updated_at, synced_at = excluded.synced_at`,
    );
    const appliedApp = new Set<string>();
    const lostApp = new Set<string>();
    for (const c of input.appCategories) {
      const row = currentApp.get(c.kind, c.id) as { updated_at: number } | undefined;
      if (row && row.updated_at >= c.updatedAt) {
        lostApp.add(`${c.kind}|${c.id}`);
        continue;
      }
      writeApp.run(c.kind, c.id, JSON.stringify(c.data), c.updatedAt, now);
      appliedApp.add(`${c.kind}|${c.id}`);
    }

    const mappings = (
      database
        .prepare(
          `SELECT payee_key, payee_label, category_id, category_name, updated_at, deleted, synced_at
           FROM payee_categories WHERE budget_sync_id = ?`,
        )
        .all(scope) as Array<{
        payee_key: string;
        payee_label: string;
        category_id: string;
        category_name: string | null;
        updated_at: string;
        deleted: number;
        synced_at?: number;
      }>
    )
      // Changed here since the app's last sync, or the app's change lost to
      // this row (which may be older than the cursor). `>=`: a write in the
      // same millisecond as the previous sync's `now` must not be missed;
      // the cost is an occasional repeat, which the app ignores (not newer).
      .filter((r) => !applied.has(r.payee_key) && ((r.synced_at ?? 0) >= since || lost.has(r.payee_key)))
      .map((r) => ({
        payee: r.payee_label,
        categoryId: r.category_id,
        categoryName: r.category_name ?? undefined,
        updatedAt: Date.parse(r.updated_at),
        deleted: r.deleted === 1,
      }));
    const appCategories = (
      database
        .prepare('SELECT kind, id, data, updated_at, synced_at FROM app_categories')
        .all() as Array<{ kind: string; id: string; data: string; updated_at: number; synced_at: number }>
    )
      .filter((r) => {
        const key = `${r.kind}|${r.id}`;
        return !appliedApp.has(key) && (r.synced_at >= since || lostApp.has(key));
      })
      .map((r) => ({ kind: r.kind, id: r.id, data: JSON.parse(r.data) as unknown, updatedAt: r.updated_at }));
    return { mappings, appCategories };
  });

  return { ...run(), now };
}

/** True when the budget's scope holds no live mapping (repopulate: rebuild from Actual). */
export function hasNoMappings(budgetSyncId: string): boolean {
  return !getDb()
    .prepare('SELECT 1 FROM payee_categories WHERE budget_sync_id = ? AND deleted = 0 LIMIT 1')
    .get(normalizeBudget(budgetSyncId));
}

export function closeCategoryDb(): void {
  if (db) {
    db.close();
    db = undefined;
  }
}
