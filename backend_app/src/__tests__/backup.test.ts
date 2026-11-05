import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import zlib from 'zlib';
import { createBudgetSession } from '../budget-session';
import { makeFakeAdapter, SERVER } from './fake-actual';

// categorydb and removal-log read their paths once, at first use: set them
// before the dynamic imports, in a fresh temporary folder.
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'backup-test-'));
process.env.CATEGORY_DB_PATH = path.join(root, 'data', 'categories.db');

const load = async () => ({
  backup: await import('../backup'),
  schedule: await import('../backup-schedule'),
  db: await import('../categorydb'),
  removals: await import('../removal-log'),
});

const ls = (dir: string) => (fs.existsSync(dir) ? fs.readdirSync(dir).sort() : []);
const tmpDir = (name: string) => fs.mkdtempSync(path.join(root, `${name}-`));

test('backupStamp is local time, sortable', async () => {
  const { backup } = await load();
  assert.equal(backup.backupStamp(new Date(2026, 0, 5, 3, 7, 9)), '2026-01-05_030709');
});

test('app data: written gzipped and atomically, read back with its manifest', async () => {
  const { backup, db, removals } = await load();
  db.syncCategories({
    budgetSyncId: 'budget-1',
    since: null,
    mappings: [{ payee: 'LIDL', categoryId: 'a-food', categoryName: 'Food', updatedAt: 1000, deleted: false }],
    appCategories: [{ kind: 'category', id: 'local:1', data: { name: 'Pets' }, updatedAt: 1000 }],
  });
  removals.recordRemovals([
    {
      transactionId: 't1',
      budgetSyncId: 'budget-1',
      accountId: 'acc',
      importedId: 'pdfimport-x',
      date: '2026-01-01',
      originalAmountCents: -500,
      removedAt: '2026-01-02T00:00:00.000Z',
    },
  ]);

  const dir = tmpDir('appdata');
  const made = backup.backupAppData(dir, { now: new Date(2026, 1, 3, 4, 5, 6), appVersion: '9.9.9' });
  assert.equal(made.file, '2026-02-03_040506.json.gz');
  assert.deepEqual(ls(path.join(dir, 'app-data')), ['2026-02-03_040506.json.gz']); // no .tmp left

  const data = backup.readAppDataBackup(fs.readFileSync(path.join(dir, 'app-data', made.file)));
  assert.equal(data.manifest.kind, 'app-data');
  assert.equal(data.manifest.schemaVersion, backup.APP_DATA_SCHEMA_VERSION);
  assert.equal(data.manifest.appVersion, '9.9.9');
  assert.deepEqual(data.appCategories, [{ kind: 'category', id: 'local:1', data: { name: 'Pets' }, updatedAt: 1000 }]);
  assert.deepEqual(data.mappings, [
    { budgetSyncId: 'budget-1', payee: 'LIDL', categoryId: 'a-food', categoryName: 'Food', updatedAt: 1000 },
  ]);
  assert.equal(data.removals.length, 1);

  // Same second again: a second file, not an overwrite.
  const again = backup.backupAppData(dir, { now: new Date(2026, 1, 3, 4, 5, 6) });
  assert.equal(again.file, '2026-02-03_040506-2.json.gz');
});

test('app data: a newer schema or a foreign file is refused', async () => {
  const { backup } = await load();
  const gz = (v: unknown) => zlib.gzipSync(Buffer.from(JSON.stringify(v)));
  assert.throws(
    () =>
      backup.readAppDataBackup(
        gz({ manifest: { kind: 'app-data', schemaVersion: 99 }, appCategories: [], mappings: [], removals: [] }),
      ),
    { code: 'BACKUP_TOO_NEW' },
  );
  // A phone's file: readable, with its own budget left out of what's restored here.
  const phone = backup.readAppDataBackup(
    gz({
      manifest: { kind: 'app-data', schemaVersion: 2 },
      appCategories: [],
      mappings: [],
      removals: [],
      ledger: { accounts: [] },
    }),
  );
  assert.equal(phone.manifest.schemaVersion, 2);
  assert.throws(() => backup.readAppDataBackup(Buffer.from('not gzip')), { code: 'BACKUP_INVALID' });
  assert.throws(() => backup.readAppDataBackup(gz({ hello: 1 })), { code: 'BACKUP_INVALID' });
});

test('app data restore: safety copy first, then the backup wins everywhere through the sync', async () => {
  const { backup, db } = await load();
  const dir = tmpDir('restore');
  db.syncCategories({
    budgetSyncId: 'budget-r',
    since: null,
    mappings: [{ payee: 'SHOP', categoryId: 'a-old', updatedAt: 2000, deleted: false }],
    appCategories: [{ kind: 'group', id: 'local:g', data: { name: 'Before' }, updatedAt: 2000 }],
  });
  const { file } = backup.backupAppData(dir, { now: new Date(2026, 2, 1, 10, 0, 0) });

  // After the backup: an edit, a new mapping, and a phone's later rename.
  const after = db.syncCategories({
    budgetSyncId: 'budget-r',
    since: null,
    mappings: [
      { payee: 'SHOP', categoryId: 'a-new', updatedAt: 3000, deleted: false },
      { payee: 'LATER', categoryId: 'a-x', updatedAt: 3000, deleted: false },
    ],
    appCategories: [{ kind: 'group', id: 'local:g', data: { name: 'After' }, updatedAt: 3000 }],
  });

  const restoreAt = new Date(2026, 2, 2, 9, 0, 0);
  const result = backup.restoreAppData(dir, file, { now: restoreAt });
  assert.ok(result.safetyCopy.file.endsWith('-before-restore.json.gz'));
  assert.ok(result.forgotten >= 1);

  // The safety copy holds the state just before the restore.
  const safety = backup.readAppDataBackup(fs.readFileSync(path.join(dir, 'app-data', result.safetyCopy.file)));
  assert.equal(safety.mappings.find((m) => m.payee === 'SHOP')?.categoryId, 'a-new');

  // A phone that synced before the restore hears about it on its next sync.
  const next = db.syncCategories({ budgetSyncId: 'budget-r', since: after.now, mappings: [], appCategories: [] });
  const shop = next.mappings.find((m) => m.payee === 'SHOP');
  const later = next.mappings.find((m) => m.payee === 'LATER');
  assert.equal(shop?.categoryId, 'a-old');
  assert.equal(shop?.updatedAt, restoreAt.getTime());
  assert.equal(later?.deleted, true);
  const group = next.appCategories.find((c) => c.id === 'local:g');
  assert.deepEqual(group?.data, { name: 'Before' });

  // The phone's own older edit now loses.
  const stale = db.syncCategories({
    budgetSyncId: 'budget-r',
    since: next.now,
    mappings: [{ payee: 'SHOP', categoryId: 'a-new', updatedAt: 3000, deleted: false }],
    appCategories: [],
  });
  assert.equal(stale.mappings.find((m) => m.payee === 'SHOP')?.categoryId, 'a-old');
  assert.equal(db.lookupCategory('shop', 'budget-r')?.categoryId, 'a-old');
});

test('files are only reached through the listing', async () => {
  const { backup } = await load();
  const dir = tmpDir('paths');
  backup.backupAppData(dir, { now: new Date(2026, 3, 1, 0, 0, 0) });
  fs.writeFileSync(path.join(root, 'secret.txt'), 'x');
  for (const [folder, file] of [
    ['app-data', '../../secret.txt'],
    ['..', 'secret.txt'],
    ['app-data', '.2026-04-01_000000.json.gz.tmp'],
    ['app-data', 'nope.json.gz'],
  ]) {
    assert.throws(() => backup.findBackup(dir, folder, file), { code: 'BACKUP_NOT_FOUND' }, `${folder}/${file}`);
  }
  assert.ok(backup.findBackup(dir, 'app-data', '2026-04-01_000000.json.gz'));
});

test('pruning keeps the newest, the one just made and every safety copy', async () => {
  const { backup } = await load();
  const dir = tmpDir('prune');
  const folder = path.join(dir, 'b1');
  fs.mkdirSync(folder);
  for (const name of [
    '2026-01-01_030000.zip',
    '2026-01-02_030000.zip',
    '2026-01-03_030000.zip',
    '2026-01-04_030000.zip',
    '2026-01-01_120000-before-restore.json.gz',
  ]) {
    fs.writeFileSync(path.join(folder, name), 'x');
  }
  const deleted = backup.pruneBackups(dir, 'b1', 2, '2026-01-01_030000.zip');
  assert.deepEqual(deleted.sort(), ['2026-01-02_030000.zip']);
  assert.deepEqual(ls(folder), [
    '2026-01-01_030000.zip',
    '2026-01-01_120000-before-restore.json.gz',
    '2026-01-03_030000.zip',
    '2026-01-04_030000.zip',
  ]);
});

test('budget backup: one session turn, Actual export written to the budget folder', async () => {
  const { backup } = await load();
  const dir = tmpDir('budget');
  const zip = new Uint8Array([80, 75, 3, 4, 1, 2, 3]);
  const { adapter, state } = makeFakeAdapter({ exportBudget: async () => zip });
  const session = createBudgetSession(SERVER, adapter);
  const made = await backup.backupBudget(session, { syncId: 'budget-1' }, dir, {
    now: () => new Date(2026, 4, 6, 7, 8, 9),
  });
  assert.deepEqual(state.downloads, ['budget-1']);
  assert.equal(made.folder, 'budget-1');
  assert.equal(made.file, '2026-05-06_070809.zip');
  assert.deepEqual(new Uint8Array(fs.readFileSync(path.join(dir, 'budget-1', made.file))), zip);
  assert.deepEqual(ls(path.join(dir, 'budget-1')), ['2026-05-06_070809.zip']);
  await session.shutdown();
});

// --- Schedule ---------------------------------------------------------------------

test('addPeriod clamps months and leap years', async () => {
  const { schedule } = await load();
  const d = (y: number, m: number, day: number) => new Date(y, m - 1, day);
  const same = (a: Date, b: Date) => assert.equal(a.toDateString(), b.toDateString());
  same(schedule.addPeriod(d(2026, 1, 31), 'daily'), d(2026, 2, 1));
  same(schedule.addPeriod(d(2026, 12, 29), 'weekly'), d(2027, 1, 5));
  same(schedule.addPeriod(d(2026, 1, 31), 'monthly'), d(2026, 2, 28));
  same(schedule.addPeriod(d(2028, 1, 31), 'monthly'), d(2028, 2, 29));
  same(schedule.addPeriod(d(2026, 12, 15), 'monthly'), d(2027, 1, 15));
  same(schedule.addPeriod(d(2028, 2, 29), 'yearly'), d(2029, 2, 28));
  same(schedule.addPeriod(d(2027, 3, 1), 'yearly'), d(2028, 3, 1));
});

test('nextDue: off, first run, on time, missed while off, retry after a failure', async () => {
  const { schedule } = await load();
  const daily = { frequency: 'daily' as const, time: '03:00' };
  const now = new Date(2026, 5, 10, 14, 0, 0);
  assert.equal(schedule.nextDue({ frequency: 'off', time: '03:00' }, undefined, now), null);
  assert.equal(schedule.isDue({ frequency: 'off', time: '03:00' }, undefined, now), false);

  // Never backed up: due right away.
  assert.equal(schedule.isDue(daily, undefined, now), true);

  // Backed up today at 03:00: next is tomorrow 03:00.
  const today = { lastAttemptAt: new Date(2026, 5, 10, 3, 0).toISOString(), lastSuccessAt: new Date(2026, 5, 10, 3, 0).toISOString() };
  assert.equal(schedule.nextDue(daily, today, now)?.getTime(), new Date(2026, 5, 11, 3, 0).getTime());
  assert.equal(schedule.isDue(daily, today, now), false);
  assert.equal(schedule.isDue(daily, today, new Date(2026, 5, 11, 3, 0)), true);

  // The backend was off for two days: due at the first check, not tomorrow.
  const old = { lastAttemptAt: new Date(2026, 5, 7, 3, 0).toISOString(), lastSuccessAt: new Date(2026, 5, 7, 3, 0).toISOString() };
  assert.equal(schedule.isDue(daily, old, now), true);

  // Weekly and monthly, from the day of the last success.
  const weekly = { frequency: 'weekly' as const, time: '03:00' };
  assert.equal(schedule.nextDue(weekly, today, now)?.getTime(), new Date(2026, 5, 17, 3, 0).getTime());
  const jan31 = { lastAttemptAt: new Date(2026, 0, 31, 3, 0).toISOString(), lastSuccessAt: new Date(2026, 0, 31, 3, 0).toISOString() };
  assert.equal(
    schedule.nextDue({ frequency: 'monthly', time: '03:00' }, jan31, now)?.getTime(),
    new Date(2026, 1, 28, 3, 0).getTime(),
  );

  // Last attempt failed: tried again an hour later.
  const failed = { ...today, lastAttemptAt: new Date(2026, 5, 11, 3, 0).toISOString(), lastError: { code: 'X', message: 'x' } };
  assert.equal(schedule.nextDue(daily, failed, now)?.getTime(), new Date(2026, 5, 11, 4, 0).getTime());
});

test('settings: checked, passwords kept or forgotten, never shown', async () => {
  const { schedule } = await load();
  const current = { ...schedule.DEFAULT_SETTINGS, budgets: [{ syncId: 'b1', name: 'Home', password: 'pw' }] };
  const kept = schedule.parseSettings({ frequency: 'weekly', budgets: [{ syncId: 'b1' }] }, current);
  assert.equal(kept.frequency, 'weekly');
  assert.equal(kept.budgets[0].password, 'pw');
  assert.equal(kept.budgets[0].name, 'Home');
  const forgot = schedule.parseSettings({ budgets: [{ syncId: 'b1', password: null }] }, current);
  assert.equal(forgot.budgets[0].password, undefined);
  assert.deepEqual(schedule.publicSettings(current).budgets, [{ syncId: 'b1', name: 'Home', hasPassword: true }]);
  assert.equal(JSON.stringify(schedule.publicSettings(current)).includes('pw'), false);

  for (const bad of [
    { frequency: 'hourly' },
    { time: '25:00' },
    { time: '3:00' },
    { keep: 0 },
    { keep: 1.5 },
    { budgets: [{ syncId: '../x' }] },
  ]) {
    assert.throws(() => schedule.parseSettings(bad, current), { code: 'INVALID_FIELD' }, JSON.stringify(bad));
  }
});

function memoryStore<T>(initial: T) {
  let value = structuredClone(initial);
  return { read: () => structuredClone(value), write: (v: T) => (value = structuredClone(v)) };
}

test('scheduler: backs up what is due, records failures, prunes only after success', async () => {
  const { schedule } = await load();
  const dir = tmpDir('scheduler');
  let exportFails = false;
  const { adapter } = makeFakeAdapter({
    getBudgets: async () => [
      { groupId: 'plain', name: 'Plain', encryptKeyId: null },
      { groupId: 'locked', name: 'Locked', encryptKeyId: 'key' },
    ],
    exportBudget: async () => {
      if (exportFails) throw new Error('disk full');
      return new Uint8Array([1, 2, 3]);
    },
  });
  const session = createBudgetSession(SERVER, adapter);
  let clock = new Date(2026, 6, 1, 3, 0, 0);
  const settingsStore = memoryStore({
    frequency: 'daily' as const,
    time: '03:00',
    keep: 2,
    budgets: [{ syncId: 'plain' }, { syncId: 'locked' }],
  });
  const stateStore = memoryStore({} as Record<string, import('../backup-schedule').TargetState>);
  const scheduler = schedule.createBackupScheduler({ dir, session, settingsStore, stateStore, now: () => clock });

  const first = await scheduler.check();
  assert.deepEqual(
    first.map((r) => [r.folder, r.ok, r.error?.code]),
    [
      ['app-data', true, undefined],
      ['plain', true, undefined],
      ['locked', false, 'BUDGET_PASSWORD_REQUIRED'],
    ],
  );
  assert.equal(stateStore.read().locked.lastError?.code, 'BUDGET_PASSWORD_REQUIRED');

  // Nothing new is due ten minutes later (the failure waits an hour).
  clock = new Date(2026, 6, 1, 3, 10, 0);
  assert.deepEqual(await scheduler.check(), []);

  // Three more days: pruned to keep = 2 each time.
  for (const day of [2, 3, 4]) {
    clock = new Date(2026, 6, day, 3, 0, 0);
    await scheduler.check();
  }
  assert.deepEqual(ls(path.join(dir, 'plain')), ['2026-07-03_030000.zip', '2026-07-04_030000.zip']);

  // A failure prunes nothing and keeps the last success.
  exportFails = true;
  clock = new Date(2026, 6, 5, 3, 0, 0);
  const failed = await scheduler.check();
  assert.equal(failed.find((r) => r.folder === 'plain')?.error?.code, 'BACKUP_FAILED');
  assert.deepEqual(ls(path.join(dir, 'plain')), ['2026-07-03_030000.zip', '2026-07-04_030000.zip']);
  assert.equal(stateStore.read().plain.lastFile, '2026-07-04_030000.zip');

  // Off: nothing runs.
  settingsStore.write({ ...settingsStore.read(), frequency: 'off' as never });
  clock = new Date(2026, 6, 9, 3, 0, 0);
  assert.deepEqual(await scheduler.check(), []);
  await session.shutdown();
});

test('scheduler: without Actual, app data still backs up and budgets wait', async () => {
  const { schedule } = await load();
  const dir = tmpDir('no-actual');
  const { adapter } = makeFakeAdapter({});
  const session = createBudgetSession(null, adapter);
  const scheduler = schedule.createBackupScheduler({
    dir,
    session,
    settingsStore: memoryStore({ ...schedule.DEFAULT_SETTINGS, frequency: 'daily' as const, budgets: [{ syncId: 'b1' }] }),
    stateStore: memoryStore({}),
    now: () => new Date(2026, 7, 1, 3, 0, 0),
  });
  const scheduled = await scheduler.check();
  assert.deepEqual(scheduled.map((r) => [r.folder, r.ok]), [['app-data', true]]);

  // Asked for by hand, the budget says why it can't.
  const manual = await scheduler.runNow({ kind: 'budget' });
  assert.deepEqual(manual.map((r) => [r.folder, r.error?.code]), [['b1', 'ACTUAL_NOT_CONFIGURED']]);
  await session.shutdown();
});
