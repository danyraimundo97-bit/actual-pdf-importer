import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBudgetSession } from '../budget-session';
import { buildDashboard, DashTransaction, getDashboard, monthKeys } from '../dashboard';
import { makeFakeAdapter, SERVER } from './fake-actual';

const today = new Date(2026, 8, 20); // 20 Sep 2026

const accounts = [
  { id: 'chk', name: 'Checking', offbudget: 0 as const, closed: 0 as const },
  { id: 'inv', name: 'Broker', offbudget: 1 as const, closed: 0 as const },
  { id: 'old', name: 'Closed card', offbudget: 0 as const, closed: 1 as const },
];

let seq = 0;
const tx = (fields: Partial<DashTransaction> & Pick<DashTransaction, 'account' | 'date' | 'amount'>) => ({
  id: `t${++seq}`,
  ...fields,
});

function build(transactions: DashTransaction[], categories: Record<string, string> = {}) {
  return buildDashboard({
    accounts,
    transactions,
    categoryNames: new Map(Object.entries(categories)),
    payeeNames: new Map([
      ['p-shop', 'Continente'],
      ['p-boss', 'Employer'],
      ['p-cafe', 'Cafe'],
    ]),
    today,
    months: 3,
  });
}

test('monthKeys lists the last N months oldest first, across a year boundary', () => {
  assert.deepEqual(monthKeys(new Date(2026, 0, 15), 3), ['2025-11', '2025-12', '2026-01']);
});

test('balances include transfers and off-budget accounts; closed accounts are dropped', () => {
  const d = build([
    tx({ account: 'chk', date: '2026-01-01', amount: 100000, starting_balance_flag: true }),
    tx({ account: 'chk', date: '2026-09-02', amount: -20000, transfer_id: 'x' }),
    tx({ account: 'inv', date: '2026-09-02', amount: 20000, transfer_id: 'y' }),
    tx({ account: 'old', date: '2026-09-03', amount: -999 }),
  ]);
  assert.deepEqual(
    d.accounts.map((a) => [a.id, a.balanceCents, a.offbudget]),
    [
      ['chk', 80000, false],
      ['inv', 20000, true],
    ],
  );
  assert.equal(d.netWorthCents, 100000);
});

test('income and spending exclude transfers, opening balances and off-budget accounts', () => {
  const d = build([
    tx({ account: 'chk', date: '2026-09-01', amount: 100000, starting_balance_flag: true }),
    tx({ account: 'chk', date: '2026-09-01', amount: 250000, payee: 'p-boss' }),
    tx({ account: 'chk', date: '2026-09-05', amount: -4200, payee: 'p-shop', category: 'food' }),
    tx({ account: 'chk', date: '2026-09-06', amount: -50000, transfer_id: 'x' }),
    tx({ account: 'inv', date: '2026-09-06', amount: 50000, transfer_id: 'y' }),
    tx({ account: 'inv', date: '2026-09-07', amount: -1000 }),
    tx({ account: 'chk', date: '2026-08-10', amount: -300, payee: 'p-cafe' }),
    tx({ account: 'chk', date: '2026-03-10', amount: -777 }), // outside the 3-month window
  ]);
  assert.deepEqual(d.months, [
    { month: '2026-07', incomeCents: 0, spendingCents: 0 },
    { month: '2026-08', incomeCents: 0, spendingCents: 300 },
    { month: '2026-09', incomeCents: 250000, spendingCents: 4200 },
  ]);
});

test('split transactions are categorised by their children, never double counted', () => {
  const d = build(
    [
      tx({
        account: 'chk',
        date: '2026-09-10',
        amount: -10000,
        payee: 'p-shop',
        subtransactions: [
          tx({ account: 'chk', date: '2026-09-10', amount: -7000, category: 'food' }),
          tx({ account: 'chk', date: '2026-09-10', amount: -3000, category: 'home' }),
        ],
      }),
    ],
    { food: 'Groceries', home: 'Household' },
  );
  assert.equal(d.accounts[0].balanceCents, -10000);
  assert.equal(d.months[2].spendingCents, 10000);
  assert.deepEqual(
    d.topCategories.map((c) => [c.name, c.spendingCents]),
    [
      ['Groceries', 7000],
      ['Household', 3000],
    ],
  );
  // Children inherit the parent's payee.
  assert.deepEqual(d.topPayees, [{ name: 'Continente', spendingCents: 10000, count: 2 }]);
});

test('categories beyond the top six roll up into "Other"; uncategorized is named', () => {
  const categories: Record<string, string> = {};
  const transactions: DashTransaction[] = [];
  for (let i = 1; i <= 8; i++) {
    categories[`c${i}`] = `Cat ${i}`;
    transactions.push(tx({ account: 'chk', date: '2026-09-15', amount: -i * 100, category: `c${i}` }));
  }
  transactions.push(tx({ account: 'chk', date: '2026-09-15', amount: -50 }));
  const d = build(transactions, categories);
  assert.equal(d.topCategories.length, 7);
  assert.deepEqual(d.topCategories[0], { categoryId: 'c8', name: 'Cat 8', spendingCents: 800 });
  // c2 (200), c1 (100) and the uncategorized 50 fall outside the top six.
  assert.deepEqual(d.topCategories[6], { categoryId: null, name: 'Other', spendingCents: 350 });
});

test('uncategorizedCount only looks at the last 30 days of on-budget flows', () => {
  const d = build([
    tx({ account: 'chk', date: '2026-09-19', amount: -100 }),
    tx({ account: 'chk', date: '2026-08-25', amount: -100 }),
    tx({ account: 'chk', date: '2026-08-01', amount: -100 }), // older than 30 days
    tx({ account: 'chk', date: '2026-09-19', amount: -100, category: 'food' }),
    tx({ account: 'chk', date: '2026-09-19', amount: -100, transfer_id: 'x' }),
    tx({ account: 'inv', date: '2026-09-19', amount: -100 }),
  ]);
  assert.equal(d.uncategorizedCount, 2);
});

test('recent lists the newest transactions with names resolved', () => {
  const d = build(
    [
      tx({ account: 'chk', date: '2026-09-01', amount: -1, payee: 'p-cafe' }),
      tx({ account: 'chk', date: '2026-09-18', amount: -2, payee: 'p-shop', category: 'food' }),
    ],
    { food: 'Groceries' },
  );
  assert.deepEqual(
    d.recent.map((r) => [r.date, r.payee, r.category, r.account]),
    [
      ['2026-09-18', 'Continente', 'Groceries', 'Checking'],
      ['2026-09-01', 'Cafe', null, 'Checking'],
    ],
  );
});

test('getDashboard reads only open accounts, inside one turn on the requested budget', async () => {
  const requested: string[] = [];
  const fake = makeFakeAdapter({
    getAccounts: async () => accounts,
    getCategories: async () => [],
    getPayees: async () => [],
    getTransactions: (async (accountId: string) => {
      requested.push(`${accountId}@${fake.state.loaded}`);
      return [{ id: `x-${accountId}`, account: accountId, date: '2026-09-01', amount: 500 }];
    }),
  });
  const session = createBudgetSession(SERVER, fake.adapter);

  const d = await getDashboard(session, { syncId: 'budget-A' }, { months: 2, today });

  assert.deepEqual(requested.sort(), ['chk@budget-A', 'inv@budget-A']);
  assert.equal(d.netWorthCents, 1000);
  assert.equal(d.months.length, 2);
});
