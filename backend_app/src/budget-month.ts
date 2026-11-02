import type { BudgetRef, BudgetSession } from './budget-session';
import { InvalidFieldError } from './errors';

/**
 * GET /budget-month (Milestone 4): how much is left in each category this
 * month. Read-only. Amounts come straight from Actual's `getBudgetMonth`,
 * which already knows about carryover and excludes transfers, so nothing
 * here re-implements budget arithmetic; `buildBudgetMonth` only shapes it.
 */

type Flag = boolean | 0 | 1 | undefined;

export interface RawBudgetCategory {
  id: string;
  name: string;
  is_income?: Flag;
  hidden?: Flag;
  budgeted?: number;
  spent?: number;
  balance?: number;
  carryover?: Flag;
  received?: number;
}

export interface RawBudgetGroup {
  id: string;
  name: string;
  is_income?: Flag;
  hidden?: Flag;
  categories?: RawBudgetCategory[];
}

export interface RawBudgetMonth {
  month: string;
  toBudget?: number;
  totalBudgeted?: number;
  totalSpent?: number;
  totalBalance?: number;
  totalIncome?: number;
  categoryGroups: RawBudgetGroup[];
}

export interface BudgetMonth {
  month: string;
  /** Months with budget data, oldest first, for the month switcher. */
  firstMonth: string;
  lastMonth: string;
  toBudgetCents: number;
  totalBudgetedCents: number;
  totalSpentCents: number;
  totalBalanceCents: number;
  incomeCents: number;
  groups: Array<{
    id: string;
    name: string;
    budgetedCents: number;
    spentCents: number;
    balanceCents: number;
    categories: Array<{
      id: string;
      name: string;
      budgetedCents: number;
      /** Negative = money went out (Actual's sign). */
      spentCents: number;
      /** What's left; negative = overspent. */
      balanceCents: number;
      carryover: boolean;
    }>;
  }>;
  income: Array<{ id: string; name: string; receivedCents: number }>;
}

const truthy = (v: Flag) => v === true || v === 1;
const cents = (v: number | undefined) => (typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : 0);

export function buildBudgetMonth(raw: RawBudgetMonth, months: string[]): BudgetMonth {
  const visible = raw.categoryGroups.filter((g) => !truthy(g.hidden));
  const expenseGroups = visible.filter((g) => !truthy(g.is_income));
  const incomeGroups = visible.filter((g) => truthy(g.is_income));

  const groups = expenseGroups
    .map((g) => {
      const categories = (g.categories ?? [])
        .filter((c) => !truthy(c.hidden))
        .map((c) => ({
          id: c.id,
          name: c.name,
          budgetedCents: cents(c.budgeted),
          spentCents: cents(c.spent),
          balanceCents: cents(c.balance),
          carryover: truthy(c.carryover),
        }));
      const sum = (key: 'budgetedCents' | 'spentCents' | 'balanceCents') =>
        categories.reduce((total, c) => total + c[key], 0);
      return {
        id: g.id,
        name: g.name,
        budgetedCents: sum('budgetedCents'),
        spentCents: sum('spentCents'),
        balanceCents: sum('balanceCents'),
        categories,
      };
    })
    .filter((g) => g.categories.length > 0);

  const income = incomeGroups.flatMap((g) =>
    (g.categories ?? [])
      .filter((c) => !truthy(c.hidden))
      .map((c) => ({ id: c.id, name: c.name, receivedCents: cents(c.received ?? c.spent) })),
  );

  const sorted = [...months].sort();
  return {
    month: raw.month,
    firstMonth: sorted[0] ?? raw.month,
    lastMonth: sorted[sorted.length - 1] ?? raw.month,
    toBudgetCents: cents(raw.toBudget),
    totalBudgetedCents: cents(raw.totalBudgeted),
    totalSpentCents: cents(raw.totalSpent),
    totalBalanceCents: cents(raw.totalBalance),
    incomeCents: cents(raw.totalIncome),
    groups,
    income,
  };
}

/** `YYYY-MM`, defaulting to the current month. */
export function parseMonth(raw: unknown, today: Date = new Date()): string {
  if (raw === undefined || raw === '') {
    return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  }
  if (typeof raw !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(raw)) {
    throw new InvalidFieldError('month', 'expected YYYY-MM');
  }
  return raw;
}

export async function getBudgetMonth(session: BudgetSession, budget: BudgetRef, month: string): Promise<BudgetMonth> {
  const { raw, months } = await session.withBudget(budget, async (actual) => {
    const months = await actual.getBudgetMonths();
    if (!months.includes(month)) {
      const sorted = [...months].sort();
      throw new InvalidFieldError('month', `no budget data for ${month} (available: ${sorted[0]} to ${sorted[sorted.length - 1]})`);
    }
    return { raw: (await actual.getBudgetMonth(month)) as unknown as RawBudgetMonth, months };
  });
  return buildBudgetMonth(raw, months);
}
