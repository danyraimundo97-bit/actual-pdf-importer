import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildAccountPage, parseLimit } from '../account-page';

const account = { id: 'a', name: 'Checking', offbudget: false, closed: false };
const tx = (id: string, date: string, amount: number, extra = {}) => ({ id, date, amount, ...extra });

const base = {
  account,
  transactions: [
    tx('t1', '2026-10-01', 10000, { starting_balance_flag: true }),
    tx('t2', '2026-10-05', -450, { payee: 'p1', category: 'c1', sort_order: 1 }),
    tx('t3', '2026-10-05', -1200, { payee: 'p1', sort_order: 2, subtransactions: [tx('s1', '2026-10-05', -1000, { category: 'c1' }), tx('s2', '2026-10-05', -200, { category: null })] }),
    tx('t4', '2026-10-09', -5000, { transfer_id: 'x' }),
  ],
  categoryNames: new Map([['c1', 'Groceries']]),
  payeeNames: new Map([['p1', 'LIDL']]),
};

test('balance over everything; newest first, same day by sort order; names resolved; splits folded', () => {
  const page = buildAccountPage({ ...base, limit: 10 });
  assert.equal(page.account.balanceCents, 10000 - 450 - 1200 - 5000);
  assert.deepEqual(page.transactions.map((t) => t.id), ['t4', 't3', 't2', 't1']);
  assert.equal(page.transactions[0].transfer, true);
  assert.deepEqual(page.transactions[1].splits, [
    { amountCents: -1000, category: 'Groceries' },
    { amountCents: -200, category: null },
  ]);
  assert.equal(page.transactions[2].payee, 'LIDL');
  assert.equal(page.transactions[2].category, 'Groceries');
  assert.equal(page.nextCursor, undefined);
});

test('pages with a cursor until the end', () => {
  const first = buildAccountPage({ ...base, limit: 3 });
  assert.deepEqual(first.transactions.map((t) => t.id), ['t4', 't3', 't2']);
  assert.equal(first.nextCursor, 't2');
  const second = buildAccountPage({ ...base, limit: 3, before: first.nextCursor });
  assert.deepEqual(second.transactions.map((t) => t.id), ['t1']);
  assert.equal(second.nextCursor, undefined);
  assert.throws(() => buildAccountPage({ ...base, limit: 3, before: 'gone' }), { code: 'INVALID_FIELD' });
});

test('limit parsing', () => {
  assert.equal(parseLimit(undefined), 50);
  assert.equal(parseLimit('500'), 200);
  assert.throws(() => parseLimit('0'), { code: 'INVALID_FIELD' });
  assert.throws(() => parseLimit('abc'), { code: 'INVALID_FIELD' });
});
