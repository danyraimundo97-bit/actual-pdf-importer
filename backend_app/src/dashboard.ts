import type { BudgetRef, BudgetSession } from './budget-session';

/**
 * GET /dashboard: read-only metrics computed from one budget's own data.
 *
 * Split in two: `getDashboard` does the single Actual round-trip, and
 * `buildDashboard` is a pure function over plain data so the arithmetic
 * (what counts as income, how transfers and splits are treated) is unit
 * tested without an SDK or a database.
 */

/** The subset of Actual's entities the aggregation reads. */
export interface DashAccount {
  id: string;
  name: string;
  offbudget: boolean | 0 | 1;
  closed: boolean | 0 | 1;
}

export interface DashTransaction {
  id: string;
  account: string;
  date: string; // YYYY-MM-DD
  amount: number; // integer cents, negative = outflow
  payee?: string | null;
  category?: string | null;
  transfer_id?: string | null;
  starting_balance_flag?: boolean;
  subtransactions?: DashTransaction[];
}

export interface Dashboard {
  netWorthCents: number;
  accounts: Array<{ id: string; name: string; offbudget: boolean; balanceCents: number }>;
  months: Array<{ month: string; incomeCents: number; spendingCents: number }>;
  topCategories: Array<{ categoryId: string | null; name: string; spendingCents: number }>;
  topPayees: Array<{ name: string; spendingCents: number; count: number }>;
  uncategorizedCount: number;
  recent: Array<{
    id: string;
    date: string;
    amountCents: number;
    payee: string | null;
    category: string | null;
    account: string;
  }>;
}

export interface DashboardInput {
  accounts: DashAccount[];
  /** Every transaction of every open account, top-level (splits nested). */
  transactions: DashTransaction[];
  categoryNames: Map<string, string>;
  payeeNames: Map<string, string>;
  /** "Now", injectable for tests. */
  today: Date;
  months: number;
}

const TOP_CATEGORIES = 6;
const TOP_PAYEES = 5;
const RECENT = 8;
const UNCATEGORIZED_WINDOW_DAYS = 30;

const monthOf = (date: string) => date.slice(0, 7);

function isoDate(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** The last `count` months as YYYY-MM, oldest first, ending with `today`'s. */
export function monthKeys(today: Date, count: number): string[] {
  const keys: string[] = [];
  for (let i = count - 1; i >= 0; i--) {
    const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
    keys.push(isoDate(d).slice(0, 7));
  }
  return keys;
}

/**
 * A split's parent carries the total but no category; its children carry
 * the categories. Flows (income/spending/categories) read the leaves;
 * balances read the top level, so a split is never counted twice.
 */
function leaves(tx: DashTransaction): DashTransaction[] {
  return tx.subtransactions && tx.subtransactions.length > 0
    ? tx.subtransactions.map((s) => ({ ...s, date: s.date ?? tx.date, payee: s.payee ?? tx.payee }))
    : [tx];
}

/** Money moving between your own accounts, or an opening balance, is not a flow. */
const isFlow = (tx: DashTransaction) => !tx.transfer_id && !tx.starting_balance_flag;

const truthy = (v: boolean | 0 | 1) => v === true || v === 1;

export function buildDashboard(input: DashboardInput): Dashboard {
  const { categoryNames, payeeNames, today } = input;
  const openAccounts = input.accounts.filter((a) => !truthy(a.closed));
  const accountById = new Map(openAccounts.map((a) => [a.id, a]));
  const transactions = input.transactions.filter((t) => accountById.has(t.account));

  // Balances: every top-level transaction, transfers included.
  const balances = new Map<string, number>();
  for (const tx of transactions) {
    balances.set(tx.account, (balances.get(tx.account) ?? 0) + tx.amount);
  }
  const accounts = openAccounts.map((a) => ({
    id: a.id,
    name: a.name,
    offbudget: truthy(a.offbudget),
    balanceCents: balances.get(a.id) ?? 0,
  }));
  const netWorthCents = accounts.reduce((sum, a) => sum + a.balanceCents, 0);

  // Flows: on-budget accounts only, transfers and opening balances excluded.
  const flows = transactions
    .filter((t) => !truthy(accountById.get(t.account)!.offbudget))
    .flatMap(leaves)
    .filter(isFlow);

  const keys = monthKeys(today, input.months);
  const byMonth = new Map(keys.map((k) => [k, { month: k, incomeCents: 0, spendingCents: 0 }]));
  for (const tx of flows) {
    const bucket = byMonth.get(monthOf(tx.date));
    if (!bucket) continue;
    if (tx.amount > 0) bucket.incomeCents += tx.amount;
    else bucket.spendingCents += -tx.amount;
  }

  const currentMonth = keys[keys.length - 1];
  const spentThisMonth = flows.filter((t) => t.amount < 0 && monthOf(t.date) === currentMonth);

  const byCategory = new Map<string | null, number>();
  for (const tx of spentThisMonth) {
    const key = tx.category ?? null;
    byCategory.set(key, (byCategory.get(key) ?? 0) - tx.amount);
  }
  const rankedCategories = [...byCategory.entries()]
    .map(([categoryId, spendingCents]) => ({
      categoryId,
      name: categoryId ? (categoryNames.get(categoryId) ?? 'Unknown category') : 'Uncategorized',
      spendingCents,
    }))
    .sort((a, b) => b.spendingCents - a.spendingCents);
  const topCategories = rankedCategories.slice(0, TOP_CATEGORIES);
  const rest = rankedCategories.slice(TOP_CATEGORIES);
  if (rest.length > 0) {
    topCategories.push({
      categoryId: null,
      name: 'Other',
      spendingCents: rest.reduce((sum, c) => sum + c.spendingCents, 0),
    });
  }

  const byPayee = new Map<string, { spendingCents: number; count: number }>();
  for (const tx of spentThisMonth) {
    const name = tx.payee ? payeeNames.get(tx.payee) : undefined;
    if (!name) continue;
    const entry = byPayee.get(name) ?? { spendingCents: 0, count: 0 };
    entry.spendingCents -= tx.amount;
    entry.count++;
    byPayee.set(name, entry);
  }
  const topPayees = [...byPayee.entries()]
    .map(([name, v]) => ({ name, ...v }))
    .sort((a, b) => b.spendingCents - a.spendingCents)
    .slice(0, TOP_PAYEES);

  const cutoff = new Date(today);
  cutoff.setDate(cutoff.getDate() - UNCATEGORIZED_WINDOW_DAYS);
  const cutoffIso = isoDate(cutoff);
  const uncategorizedCount = flows.filter((t) => !t.category && t.date >= cutoffIso).length;

  const recent = [...transactions]
    .sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0))
    .slice(0, RECENT)
    .map((t) => ({
      id: t.id,
      date: t.date,
      amountCents: t.amount,
      payee: t.payee ? (payeeNames.get(t.payee) ?? null) : null,
      category: t.category ? (categoryNames.get(t.category) ?? null) : null,
      account: accountById.get(t.account)!.name,
    }));

  return {
    netWorthCents,
    accounts,
    months: keys.map((k) => byMonth.get(k)!),
    topCategories,
    topPayees,
    uncategorizedCount,
    recent,
  };
}

/**
 * Fetches everything in one budget turn, then aggregates outside it so the
 * session is released as soon as the data is in hand. Balances need the
 * full history, so transactions are read from the beginning of time; for a
 * personal budget that is a few thousand rows.
 */
export async function getDashboard(
  session: BudgetSession,
  budget: BudgetRef,
  options: { months: number; today?: Date },
): Promise<Dashboard> {
  const today = options.today ?? new Date();
  const { accounts, categories, payees, transactions } = await session.withBudget(
    budget,
    async (actual) => {
      const [accounts, categories, payees] = await Promise.all([
        actual.getAccounts(),
        actual.getCategories(),
        actual.getPayees(),
      ]);
      const open = accounts.filter((a) => !a.closed);
      const perAccount = await Promise.all(
        open.map((a) => actual.getTransactions(a.id, '1970-01-01', isoDate(today))),
      );
      return { accounts, categories, payees, transactions: perAccount.flat() };
    },
  );

  return buildDashboard({
    accounts: accounts as DashAccount[],
    transactions: transactions as DashTransaction[],
    categoryNames: new Map(categories.map((c) => [c.id, c.name])),
    payeeNames: new Map(payees.map((p) => [p.id, p.name])),
    today,
    months: options.months,
  });
}
