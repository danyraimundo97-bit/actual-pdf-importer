import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';

// categorydb.ts reads CATEGORY_DB_PATH once at module load (its module-level
// `getDb()` lazily opens the file the first time it's called), so the env
// var has to be set before the module is first imported — hence the
// dynamic import here rather than a static one. Only one test per file
// imports categorydb: within a single process/file, a second dynamic
// import() would just return the already-cached module (ignoring a
// changed env var) — see categorydb-migration.test.ts, which is split
// into its own file for exactly that reason.
test('categorydb scopes mappings per budget, with an unscoped fallback', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'categorydb-test-'));
  process.env.CATEGORY_DB_PATH = path.join(dir, 'categories.db');

  const categorydb = await import('../categorydb');

  categorydb.rememberCategory('CONTINENTE', 'cat-unscoped', 'Groceries');
  assert.deepEqual(categorydb.lookupCategory('CONTINENTE'), {
    categoryId: 'cat-unscoped',
    categoryName: 'Groceries',
  });

  // A budget with no mapping of its own falls back to the unscoped one.
  assert.deepEqual(categorydb.lookupCategory('CONTINENTE', 'budget-B'), {
    categoryId: 'cat-unscoped',
    categoryName: 'Groceries',
  });

  // Once budget-B has its own mapping, it wins there — and budget A
  // (unscoped) is untouched.
  categorydb.rememberCategory('CONTINENTE', 'cat-b', 'Groceries B', 'budget-B');
  assert.equal(categorydb.lookupCategory('CONTINENTE', 'budget-B')?.categoryId, 'cat-b');
  assert.equal(categorydb.lookupCategory('CONTINENTE')?.categoryId, 'cat-unscoped');

  assert.equal(categorydb.deleteCategoryMapping('CONTINENTE', 'budget-B'), true);
  assert.equal(categorydb.lookupCategory('CONTINENTE', 'budget-B')?.categoryId, 'cat-unscoped');

  categorydb.closeCategoryDb();
  fs.rmSync(dir, { recursive: true, force: true });
});
