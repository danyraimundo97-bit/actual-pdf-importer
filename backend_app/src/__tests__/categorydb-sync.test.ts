import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';

// Own file and one dynamic import, like categorydb.test.ts: categorydb reads
// CATEGORY_DB_PATH once. The file starts in the shape it had before sync
// existed (scoped, but no `deleted`/`synced_at`), so opening it also proves
// the columns get added without losing rows.
test('category sync: tombstones, newest wins, the since cursor, app categories', async (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'categorydb-sync-'));
  const dbPath = path.join(dir, 'categories.db');
  process.env.CATEGORY_DB_PATH = dbPath;

  const Database = (await import('better-sqlite3')).default;
  const old = new Database(dbPath);
  old.exec(`CREATE TABLE payee_categories (
    budget_sync_id TEXT NOT NULL DEFAULT '', payee_key TEXT NOT NULL, payee_label TEXT NOT NULL,
    category_id TEXT NOT NULL, category_name TEXT, updated_at TEXT NOT NULL,
    PRIMARY KEY (budget_sync_id, payee_key))`);
  old
    .prepare('INSERT INTO payee_categories VALUES (?,?,?,?,?,?)')
    .run('b1', 'lidl', 'LIDL', 'a-groceries', 'Groceries', '2026-01-01T00:00:00.000Z');
  old.close();

  const db = await import('../categorydb');
  const at = (iso: string) => Date.parse(iso);

  await t.test('an older file keeps its rows and a first full sync returns them', () => {
    const first = db.syncCategories({ budgetSyncId: 'b1', since: null, mappings: [], appCategories: [] });
    assert.deepEqual(first.mappings, [
      { payee: 'LIDL', categoryId: 'a-groceries', categoryName: 'Groceries', updatedAt: at('2026-01-01T00:00:00.000Z'), deleted: false },
    ]);
  });

  await t.test('forgetting is a tombstone: gone from lookups, carried by the sync', () => {
    db.rememberCategory('CAFE', 'a-cafes', 'Cafés', 'b1');
    const before = Date.now() - 1;
    assert.equal(db.deleteCategoryMapping('cafe', 'b1'), true);
    assert.equal(db.deleteCategoryMapping('cafe', 'b1'), false, 'already forgotten');
    assert.equal(db.lookupCategory('CAFE', 'b1'), null);
    assert.equal(db.listCategoryMappings('b1').some((m) => m.payee === 'CAFE'), false);

    const out = db.syncCategories({ budgetSyncId: 'b1', since: before, mappings: [], appCategories: [] });
    assert.deepEqual(
      out.mappings.map((m) => [m.payee, m.deleted]),
      [['CAFE', true]],
    );

    db.rememberCategory('CAFE', 'a-cafes', 'Cafés', 'b1');
    assert.equal(db.lookupCategory('CAFE', 'b1')?.categoryId, 'a-cafes', 'remembering again revives it');
  });

  await t.test('the newer side wins; a losing change gets the newer row back', () => {
    const cursor = db.syncCategories({ budgetSyncId: 'b1', since: null, mappings: [], appCategories: [] }).now;

    // Newer than the backend's LIDL (2026-01-01): applied, not echoed.
    const won = db.syncCategories({
      budgetSyncId: 'b1',
      since: cursor,
      mappings: [{ payee: 'Lidl', categoryId: 'a-food', updatedAt: at('2026-06-01T00:00:00Z'), deleted: false }],
      appCategories: [],
    });
    assert.equal(db.lookupCategory('LIDL', 'b1')?.categoryId, 'a-food');
    assert.deepEqual(won.mappings, []);

    // Older than what's here now: ignored, and the current row comes back
    // although it hasn't changed since the cursor.
    const lost = db.syncCategories({
      budgetSyncId: 'b1',
      since: won.now,
      mappings: [{ payee: 'LIDL', categoryId: 'a-old', updatedAt: at('2026-02-01T00:00:00Z'), deleted: false }],
      appCategories: [],
    });
    assert.equal(db.lookupCategory('LIDL', 'b1')?.categoryId, 'a-food');
    assert.deepEqual(
      lost.mappings.map((m) => [m.payee, m.categoryId]),
      [['Lidl', 'a-food']],
    );
  });

  await t.test('the app can forget a mapping', () => {
    db.syncCategories({
      budgetSyncId: 'b1',
      since: null,
      mappings: [{ payee: 'LIDL', categoryId: 'a-food', updatedAt: Date.now() + 1000, deleted: true }],
      appCategories: [],
    });
    assert.equal(db.lookupCategory('LIDL', 'b1'), null);
  });

  await t.test('since returns only what changed after it, per budget', () => {
    const cursor = db.syncCategories({ budgetSyncId: 'b1', since: null, mappings: [], appCategories: [] }).now;
    db.rememberCategory('NEW SHOP', 'a-x', undefined, 'b1');
    db.rememberCategory('OTHER BUDGET', 'a-y', undefined, 'b2');
    const out = db.syncCategories({ budgetSyncId: 'b1', since: cursor, mappings: [], appCategories: [] });
    assert.deepEqual(
      out.mappings.map((m) => m.payee),
      ['NEW SHOP'],
    );
  });

  await t.test("the app's own categories: stored opaque, newest wins, returned to other phones", () => {
    const group = { kind: 'group', id: 'local:g1', data: { name: 'Pets', sort: 9 }, updatedAt: 100 };
    const first = db.syncCategories({ budgetSyncId: '', since: null, mappings: [], appCategories: [group] });
    assert.deepEqual(first.appCategories, []);

    // A second phone, from scratch, gets it.
    const fresh = db.syncCategories({ budgetSyncId: '', since: null, mappings: [], appCategories: [] });
    assert.deepEqual(fresh.appCategories, [group]);

    // An older edit loses and gets the stored version back.
    const stale = db.syncCategories({
      budgetSyncId: '',
      since: first.now,
      mappings: [],
      appCategories: [{ ...group, data: { name: 'Animals' }, updatedAt: 50 }],
    });
    assert.deepEqual(stale.appCategories, [group]);
  });
});
