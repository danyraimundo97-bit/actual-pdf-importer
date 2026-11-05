import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBudgetSession } from '../budget-session';
import { buildMonthTransactions, getMonthTransactions, monthRange } from '../month-transactions';
import { makeFakeAdapter, SERVER } from './fake-actual';

const ACCOUNTS = [
  { id: 'chk', name: 'Checking', offbudget: false, closed: false },
  { id: 'inv', name: 'Investments', offbudget: true, closed: false },
];
const NAMES = {
  categoryNames: new Map([
    ['food', 'Groceries'],
    ['fun', 'Fun'],
  ]),
  payeeNames: new Map([['lidl', 'Lidl']]),
};

test('monthRange ends on the real last day, leap years included', () => {
  assert.deepEqual(monthRange('2026-11'), { from: '2026-11-01', to: '2026-11-30' });
  assert.deepEqual(monthRange('2028-02'), { from: '2028-02-01', to: '2028-02-29' });
  assert.deepEqual(monthRange('2026-12'), { from: '2026-12-01', to: '2026-12-31' });
});

test('lists every account newest first, with names resolved', () => {
  const result = buildMonthTransactions({
    month: '2026-11',
    accounts: ACCOUNTS,
    ...NAMES,
    transactions: [
      { id: 'a', account: 'chk', date: '2026-11-02', amount: -450, payee: 'lidl', category: 'food' },
      { id: 'b', account: 'inv', date: '2026-11-20', amount: 1000 },
    ],
  });
  assert.deepEqual(
    result.transactions.map((t) => [t.id, t.accountName, t.payee, t.category]),
    [
      ['b', 'Investments', null, null],
      ['a', 'Checking', 'Lidl', 'Groceries'],
    ],
  );
});

test('totals leave out transfers, opening balances and off-budget accounts, and read splits by part', () => {
  const result = buildMonthTransactions({
    month: '2026-11',
    accounts: ACCOUNTS,
    ...NAMES,
    transactions: [
      { id: 'pay', account: 'chk', date: '2026-11-01', amount: 200_000 },
      { id: 'open', account: 'chk', date: '2026-11-01', amount: 50_000, starting_balance_flag: true },
      { id: 'move', account: 'chk', date: '2026-11-03', amount: -30_000, transfer_id: 'x' },
      { id: 'off', account: 'inv', date: '2026-11-03', amount: -999 },
      {
        id: 'split',
        account: 'chk',
        date: '2026-11-04',
        amount: -300,
        subtransactions: [
          { id: 's1', date: '2026-11-04', amount: -500, category: 'food' },
          { id: 's2', date: '2026-11-04', amount: 200, category: 'fun' },
        ],
      },
    ],
  });
  assert.equal(result.incomeCents, 200_200);
  assert.equal(result.spendingCents, 500);
  // Everything is still listed: the totals only skip what isn't a flow.
  assert.equal(result.transactions.length, 5);
  assert.deepEqual(result.transactions.find((t) => t.id === 'split')?.splits?.map((s) => s.category), ['Groceries', 'Fun']);
});

test('getMonthTransactions asks each account for exactly that month', async () => {
  const asked: Array<[string, string, string]> = [];
  const { adapter } = makeFakeAdapter({
    getAccounts: async () => ACCOUNTS,
    getCategories: async () => [],
    getPayees: async () => [],
    getTransactions: async (id: string, from: string, to: string) => {
      asked.push([id, from, to]);
      return id === 'chk' ? [{ id: 't', date: '2026-02-10', amount: -1 }] : [];
    },
  } as never);
  const result = await getMonthTransactions(createBudgetSession(SERVER, adapter), { syncId: 'B' }, '2026-02');
  assert.deepEqual(asked, [
    ['chk', '2026-02-01', '2026-02-28'],
    ['inv', '2026-02-01', '2026-02-28'],
  ]);
  assert.equal(result.transactions[0].accountId, 'chk');
});
