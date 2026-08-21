import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';

test('categorydb migrates a pre-scoping (legacy) table into the unscoped bucket', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'categorydb-migrate-'));
  const dbPath = path.join(dir, 'categories.db');
  process.env.CATEGORY_DB_PATH = dbPath;

  // Build the OLD (pre-multi-budget) schema by hand and seed a row, the
  // way a real pre-upgrade install's file would look.
  const Database = (await import('better-sqlite3')).default;
  const legacyDb = new Database(dbPath);
  legacyDb.exec(`CREATE TABLE payee_categories (
    payee_key TEXT PRIMARY KEY, payee_label TEXT NOT NULL, category_id TEXT NOT NULL,
    category_name TEXT, updated_at TEXT NOT NULL)`);
  legacyDb
    .prepare('INSERT INTO payee_categories VALUES (?,?,?,?,?)')
    .run('continente', 'CONTINENTE', 'cat-groceries', 'Groceries', new Date().toISOString());
  legacyDb.close();

  const categorydb = await import('../categorydb');
  // The first call to getDb() (inside lookupCategory) triggers the migration.
  assert.deepEqual(categorydb.lookupCategory('CONTINENTE'), {
    categoryId: 'cat-groceries',
    categoryName: 'Groceries',
  });

  categorydb.closeCategoryDb();
  fs.rmSync(dir, { recursive: true, force: true });
});
