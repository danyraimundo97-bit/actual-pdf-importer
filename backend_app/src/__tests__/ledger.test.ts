import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { createBudgetSession } from '../budget-session';
import { changedIds, ChangeLog, LedgerEpochs, pullLedger, RawBudgetAmount, RawLedgerTransaction } from '../ledger';
import { makeFakeAdapter, SERVER } from './fake-actual';

// docs/plans/local-ledger.md, Phase 5: GET /ledger/pull.

function tempEpochs() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ledger-epochs-'));
  return { epochs: new LedgerEpochs(path.join(dir, 'ledger-epochs.json')), dir };
}

const tx = (id: string, fields: Partial<RawLedgerTransaction> = {}): RawLedgerTransaction => ({
  id,
  account: 'chk',
  date: '2026-10-01',
  amount: -1250,
  ...fields,
});

/** A budget whose log holds `log` and whose rows are `rows`/`amounts`. */
function fakeBudget(options: {
  log: ChangeLog['entries'];
  oldest?: ChangeLog['oldest'];
  rows?: RawLedgerTransaction[];
  amounts?: RawBudgetAmount[];
  budgetType?: 'tracking' | 'envelope';
}) {
  const calls = { transactions: [] as Array<string[] | 'all'>, amounts: [] as Array<string[] | 'all'> };
  const rows = options.rows ?? [];
  const amounts = options.amounts ?? [];
  const fake = makeFakeAdapter({
    getAccounts: async () => [{ id: 'chk', name: 'Checking', offbudget: false, closed: false }],
    getCategoryGroups: async () => [
      { id: 'g1', name: 'Food', is_income: false, hidden: false, categories: [{ id: 'food', name: 'Groceries' }] },
    ],
    getPayees: async () => [
      { id: 'p1', name: 'Bakery', transfer_acct: '' },
      { id: 'p2', name: 'Transfer: Savings', transfer_acct: 'sav' },
    ],
    ledger: {
      readChangeLog: async (afterId: number) => ({
        entries: options.log.filter((e) => e.id > afterId),
        oldest: options.oldest === undefined ? (options.log[0] ? { id: options.log[0].id, timestamp: 't0' } : null) : options.oldest,
        maxId: options.log.length ? options.log[options.log.length - 1].id : null,
      }),
      readTransactions: async (ids?: string[]) => {
        calls.transactions.push(ids ?? 'all');
        return ids ? rows.filter((r) => ids.includes(r.id)) : rows.filter((r) => !r.tombstone);
      },
      readBudgetType: async () => options.budgetType ?? 'envelope',
      readBudgetAmounts: async (_type: string, ids?: string[]) => {
        calls.amounts.push(ids ?? 'all');
        return ids ? amounts.filter((a) => ids.includes(a.id)) : amounts;
      },
    },
  });
  return { session: createBudgetSession(SERVER, fake.adapter), calls };
}

const log: ChangeLog['entries'] = [
  { id: 1, dataset: 'transactions', row: 't1' },
  { id: 2, dataset: 'transactions', row: 't2' },
  { id: 3, dataset: 'payees', row: 'p1' },
  { id: 4, dataset: 'zero_budgets', row: '202610-food' },
  { id: 5, dataset: 'transactions', row: 't2' },
];

test('changedIds keeps transactions and budget amounts, once each', () => {
  assert.deepEqual(changedIds(log), { transactions: ['t1', 't2'], budgets: ['202610-food'] });
});

test('a first pull is full and shapes every row', async () => {
  const { epochs } = tempEpochs();
  const { session, calls } = fakeBudget({
    log,
    rows: [
      tx('t1', { payee: 'p1', category: 'food', imported_id: 'pdfimport-a', cleared: 1 }),
      tx('t2', { amount: 0, notes: '[Removed via PDF importer on 2026-10-02]' }),
      tx('t3', { tombstone: true }),
    ],
    amounts: [{ id: '202610-food', month: 202610, category: 'food', amount: 30000, carryover: 1 }],
  });

  const pull = await pullLedger(session, { syncId: 'b1' }, {}, epochs);

  assert.equal(pull.full, true);
  assert.equal(pull.lastId, 5);
  assert.equal(pull.budgetType, 'envelope');
  assert.deepEqual(calls.transactions, ['all']);
  assert.deepEqual(pull.transactions[0], {
    id: 't1',
    accountId: 'chk',
    date: '2026-10-01',
    amountCents: -1250,
    payeeId: 'p1',
    categoryId: 'food',
    notes: null,
    cleared: true,
    importedId: 'pdfimport-a',
    startingBalance: false,
    transferId: null,
    parentId: null,
    isParent: false,
    deleted: false,
  });
  // The app's soft delete reads as removed on the phone.
  assert.equal(pull.transactions[1].deleted, true);
  assert.equal(pull.transactions.length, 2);
  assert.deepEqual(pull.budgets, [{ month: '2026-10', categoryId: 'food', budgetedCents: 30000, carryover: true }]);
  assert.deepEqual(pull.payees[1], { id: 'p2', name: 'Transfer: Savings', transferAccountId: 'sav' });
  assert.deepEqual(pull.categoryGroups[0].categories, [{ id: 'food', name: 'Groceries', hidden: false }]);
});

test('with the same epoch only the rows the log names since the cursor come back, tombstones included', async () => {
  const { epochs } = tempEpochs();
  const { session, calls } = fakeBudget({
    log,
    rows: [tx('t1'), tx('t2', { tombstone: true })],
    amounts: [{ id: '202610-food', month: 202610, category: 'food', amount: 1 }],
  });
  const first = await pullLedger(session, { syncId: 'b1' }, {}, epochs);

  const next = await pullLedger(session, { syncId: 'b1' }, { epoch: first.epoch, lastId: 4 }, epochs);

  assert.equal(next.full, false);
  assert.equal(next.epoch, first.epoch);
  assert.deepEqual(calls.transactions.at(-1), ['t2']);
  assert.deepEqual(
    next.transactions.map((t) => [t.id, t.deleted]),
    [['t2', true]],
  );
  // No budget row changed after id 4.
  assert.deepEqual(next.budgets, []);
});

test('nothing new is an empty delta at the same position', async () => {
  const { epochs } = tempEpochs();
  const { session } = fakeBudget({ log });
  const first = await pullLedger(session, { syncId: 'b1' }, {}, epochs);
  const next = await pullLedger(session, { syncId: 'b1' }, { epoch: first.epoch, lastId: 5 }, epochs);
  assert.deepEqual([next.full, next.lastId, next.transactions.length], [false, 5, 0]);
});

test('a different first entry (fresh cache, reset sync) starts a new epoch and a full pull', async () => {
  const { epochs } = tempEpochs();
  const before = await pullLedger(fakeBudget({ log }).session, { syncId: 'b1' }, {}, epochs);

  const after = await pullLedger(
    fakeBudget({ log, oldest: { id: 1, timestamp: 'another clock' } }).session,
    { syncId: 'b1' },
    { epoch: before.epoch, lastId: 5 },
    epochs,
  );

  assert.notEqual(after.epoch, before.epoch);
  assert.equal(after.full, true);
});

test('a cursor past the end of the log gets a full pull', async () => {
  const { epochs } = tempEpochs();
  const { session } = fakeBudget({ log });
  const first = await pullLedger(session, { syncId: 'b1' }, {}, epochs);
  const next = await pullLedger(session, { syncId: 'b1' }, { epoch: first.epoch, lastId: 99 }, epochs);
  assert.equal(next.full, true);
});

test('an empty log that starts filling keeps its epoch; budgets have their own', () => {
  const { epochs, dir } = tempEpochs();
  const empty = epochs.current('b1', null);
  assert.equal(epochs.current('b1', { id: 1, timestamp: 't' }), empty);
  assert.equal(epochs.current('b1', { id: 1, timestamp: 't' }), empty);
  assert.notEqual(epochs.current('b2', { id: 1, timestamp: 't' }), empty);
  // Kept on disk, owner-only.
  const file = path.join(dir, 'ledger-epochs.json');
  assert.equal(new LedgerEpochs(file).current('b1', { id: 1, timestamp: 't' }), empty);
  assert.equal(fs.statSync(file).mode & 0o777, 0o600);
});
