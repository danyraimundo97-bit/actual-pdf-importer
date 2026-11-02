import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildBudgetMonth, parseMonth } from '../budget-month';

// The shape @actual-app/api's getBudgetMonth returns (integer cents).
const RAW = {
  month: '2026-11',
  toBudget: 12000,
  totalBudgeted: -90000,
  totalSpent: -45000,
  totalBalance: 45000,
  totalIncome: 150000,
  categoryGroups: [
    {
      id: 'g-food',
      name: 'Food',
      is_income: false,
      hidden: false,
      categories: [
        { id: 'c-groc', name: 'Groceries', budgeted: 40000, spent: -42000, balance: -2000, carryover: false },
        { id: 'c-rest', name: 'Restaurants', budgeted: 10000, spent: -3000, balance: 7000, carryover: true },
        { id: 'c-old', name: 'Old', hidden: true, budgeted: 0, spent: 0, balance: 0 },
      ],
    },
    { id: 'g-hidden', name: 'Hidden', hidden: true, categories: [{ id: 'c-h', name: 'H', budgeted: 1 }] },
    { id: 'g-empty', name: 'Empty', categories: [] },
    { id: 'g-inc', name: 'Income', is_income: true, categories: [{ id: 'c-sal', name: 'Salary', received: 150000 }] },
  ],
};

test('shapes the month: expense groups with totals, hidden left out, income separate', () => {
  const month = buildBudgetMonth(RAW, ['2026-01', '2026-11', '2026-12']);
  assert.equal(month.toBudgetCents, 12000);
  assert.equal(month.firstMonth, '2026-01');
  assert.equal(month.lastMonth, '2026-12');
  assert.deepEqual(month.groups.map((g) => g.id), ['g-food']);
  const food = month.groups[0];
  assert.equal(food.balanceCents, 5000);
  assert.deepEqual(food.categories.map((c) => [c.name, c.balanceCents, c.carryover]), [
    ['Groceries', -2000, false],
    ['Restaurants', 7000, true],
  ]);
  assert.deepEqual(month.income, [{ id: 'c-sal', name: 'Salary', receivedCents: 150000 }]);
});

test('month parsing', () => {
  assert.equal(parseMonth(undefined, new Date(2026, 10, 2)), '2026-11');
  assert.equal(parseMonth('2026-01'), '2026-01');
  assert.throws(() => parseMonth('2026-13'), { code: 'INVALID_FIELD' });
  assert.throws(() => parseMonth('nov'), { code: 'INVALID_FIELD' });
});
