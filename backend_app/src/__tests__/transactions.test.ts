import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBudgetSession } from '../budget-session';
import { addManualTransaction, buildQuickAddOptions, parseManualTransaction } from '../transactions';
import { makeFakeAdapter, SERVER } from './fake-actual';

const VALID = { accountId: 'acc-1', date: '2026-11-02', amountCents: -450, payeeName: ' Café ', clientId: 'c0ffee00-1234' };

test('parseManualTransaction: validates and trims', () => {
  assert.deepEqual(parseManualTransaction(VALID), {
    accountId: 'acc-1',
    date: '2026-11-02',
    amountCents: -450,
    payeeName: 'Café',
    categoryId: undefined,
    notes: undefined,
    clientId: 'c0ffee00-1234',
  });
  assert.throws(() => parseManualTransaction({ ...VALID, accountId: undefined }), { code: 'MISSING_FIELD' });
  assert.throws(() => parseManualTransaction({ ...VALID, date: '02-11-2026' }), { code: 'INVALID_FIELD' });
  assert.throws(() => parseManualTransaction({ ...VALID, amountCents: 4.5 }), { code: 'INVALID_FIELD' });
  assert.throws(() => parseManualTransaction({ ...VALID, amountCents: 0 }), { code: 'INVALID_FIELD' });
  assert.throws(() => parseManualTransaction({ ...VALID, clientId: 'x' }), { code: 'INVALID_FIELD' });
});

/** A tiny in-memory budget: accounts and the transactions added to them. */
function budgetWith(accounts: Array<{ id: string; closed?: boolean }>) {
  const rows: Array<{ id: string; account: string; date: string; amount: number; imported_id?: string; payee_name?: string }> = [];
  let calls = 0;
  const { adapter } = makeFakeAdapter({
    getAccounts: async () => accounts.map((a) => ({ id: a.id, name: a.id, offbudget: false, closed: Boolean(a.closed) })),
    getTransactions: async (accountId: string, from: string, to: string) =>
      rows.filter((r) => r.account === accountId && r.date >= from && r.date <= to),
    addTransactions: async (accountId: string, txs: Array<{ date: string; amount: number; imported_id?: string }>) => {
      calls++;
      for (const t of txs) rows.push({ ...t, id: `tx-${rows.length + 1}`, account: accountId });
      return 'ok';
    },
  } as never);
  return { session: createBudgetSession(SERVER, adapter), rows, addCalls: () => calls };
}

test('addManualTransaction adds once; a retry with the same clientId returns the same transaction', async () => {
  const { session, rows, addCalls } = budgetWith([{ id: 'acc-1' }]);
  const input = parseManualTransaction(VALID);

  const first = await addManualTransaction(session, { syncId: 'B' }, input);
  assert.deepEqual(first, { id: 'tx-1', created: true });
  assert.equal(rows[0].imported_id, 'app-c0ffee00-1234');

  const retry = await addManualTransaction(session, { syncId: 'B' }, input);
  assert.deepEqual(retry, { id: 'tx-1', created: false });
  assert.equal(addCalls(), 1);
});

test('two identical purchases with different clientIds are both added (no fuzzy matching)', async () => {
  const { session, rows } = budgetWith([{ id: 'acc-1' }]);
  await addManualTransaction(session, { syncId: 'B' }, parseManualTransaction(VALID));
  await addManualTransaction(session, { syncId: 'B' }, parseManualTransaction({ ...VALID, clientId: 'c0ffee00-5678' }));
  assert.equal(rows.length, 2);
});

test('an unknown or closed account is ACCOUNT_NOT_FOUND', async () => {
  const { session } = budgetWith([{ id: 'acc-closed', closed: true }]);
  await assert.rejects(addManualTransaction(session, { syncId: 'B' }, parseManualTransaction(VALID)), {
    code: 'ACCOUNT_NOT_FOUND',
  });
  await assert.rejects(
    addManualTransaction(session, { syncId: 'B' }, parseManualTransaction({ ...VALID, accountId: 'acc-closed' })),
    { code: 'ACCOUNT_NOT_FOUND' },
  );
});

test('buildQuickAddOptions: open accounts on-budget first, visible categories, recent payees newest first', () => {
  const options = buildQuickAddOptions({
    accounts: [
      { id: 'inv', name: 'Investments', offbudget: true, closed: false },
      { id: 'old', name: 'Old', offbudget: false, closed: 1 },
      { id: 'chk', name: 'Checking', offbudget: false, closed: false },
    ],
    categoryGroups: [
      { id: 'g1', name: 'Food', categories: [{ id: 'c1', name: 'Groceries' }, { id: 'c2', name: 'Hidden', hidden: true }] },
      { id: 'g2', name: 'Gone', hidden: true, categories: [{ id: 'c3', name: 'X' }] },
      { id: 'g3', name: 'Income', is_income: 1, categories: [{ id: 'c4', name: 'Salary' }] },
    ],
    payees: [
      { id: 'p1', name: 'LIDL' },
      { id: 'p2', name: 'CAFE' },
      { id: 'p3', name: 'Savings', transfer_acct: 'sav' },
    ],
    transactions: [
      { date: '2026-10-01', payee: 'p1', category: 'c0' },
      { date: '2026-10-20', payee: 'p1', category: 'c1' },
      { date: '2026-10-15', payee: 'p2', category: null },
      { date: '2026-10-25', payee: 'p3', category: null, transfer_id: 't' },
      { date: '2026-10-30', payee: 'p2', category: 'c1', is_parent: true },
    ],
  });
  assert.deepEqual(options.accounts.map((a) => a.id), ['chk', 'inv']);
  assert.deepEqual(options.categoryGroups, [
    { id: 'g1', name: 'Food', isIncome: false, categories: [{ id: 'c1', name: 'Groceries' }] },
    { id: 'g3', name: 'Income', isIncome: true, categories: [{ id: 'c4', name: 'Salary' }] },
  ]);
  assert.deepEqual(options.recentPayees, [
    { name: 'CAFE', lastCategoryId: null }, // newest is a split parent: no single category
    { name: 'LIDL', lastCategoryId: 'c1' },
  ]);
});
