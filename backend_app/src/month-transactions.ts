import { accountPageRow, APAccount, APTransaction, AccountPageRow, compareNewestFirst } from './account-page';
import type { BudgetRef, BudgetSession } from './budget-session';

/**
 * GET /month-transactions: every transaction of one month, across all
 * accounts, newest first, so a whole month can be looked through in one
 * list. Read-only. Same split as dashboard.ts: one budget turn to read, then
 * the pure `buildMonthTransactions`. A month is small enough not to page.
 *
 * A transfer shows up twice, once per account, because both rows exist. The
 * totals follow the dashboard's rules: on-budget accounts only, transfers and
 * opening balances left out, splits read by their parts.
 */

export type MonthTransaction = APTransaction & { account: string };

export interface MonthTransactions {
  month: string;
  incomeCents: number;
  spendingCents: number;
  transactions: Array<AccountPageRow & { accountId: string; accountName: string }>;
}

const truthy = (v: boolean | 0 | 1 | undefined) => v === true || v === 1;

/** First and last day of `YYYY-MM`; the last one is real, since Actual reads these as dates. */
export function monthRange(month: string): { from: string; to: string } {
  const [year, monthNumber] = month.split('-').map(Number);
  const lastDay = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
  return { from: `${month}-01`, to: `${month}-${String(lastDay).padStart(2, '0')}` };
}

export function buildMonthTransactions(input: {
  month: string;
  accounts: APAccount[];
  transactions: MonthTransaction[];
  categoryNames: Map<string, string>;
  payeeNames: Map<string, string>;
}): MonthTransactions {
  const accounts = new Map(input.accounts.map((a) => [a.id, a]));

  let incomeCents = 0;
  let spendingCents = 0;
  for (const tx of input.transactions) {
    if (truthy(accounts.get(tx.account)?.offbudget)) continue;
    const parts = tx.subtransactions && tx.subtransactions.length > 0 ? tx.subtransactions : [tx];
    for (const part of parts) {
      if (part.transfer_id || part.starting_balance_flag) continue;
      if (part.amount > 0) incomeCents += part.amount;
      else spendingCents -= part.amount;
    }
  }

  return {
    month: input.month,
    incomeCents,
    spendingCents,
    transactions: [...input.transactions].sort(compareNewestFirst).map((t) => ({
      ...accountPageRow(t, input.categoryNames, input.payeeNames),
      accountId: t.account,
      accountName: accounts.get(t.account)?.name ?? 'Unknown account',
    })),
  };
}

export async function getMonthTransactions(
  session: BudgetSession,
  budget: BudgetRef,
  month: string,
): Promise<MonthTransactions> {
  const { from, to } = monthRange(month);
  const data = await session.withBudget(budget, async (actual) => {
    const [accounts, categories, payees] = await Promise.all([
      actual.getAccounts(),
      actual.getCategories(),
      actual.getPayees(),
    ]);
    // Closed accounts too: what happened in them that month still happened.
    const perAccount = await Promise.all(
      accounts.map(async (a) =>
        (await actual.getTransactions(a.id, from, to)).map((t) => ({ ...t, account: t.account ?? a.id })),
      ),
    );
    return { accounts, categories, payees, transactions: perAccount.flat() };
  });
  return buildMonthTransactions({
    month,
    accounts: data.accounts as APAccount[],
    transactions: data.transactions as unknown as MonthTransaction[],
    categoryNames: new Map(data.categories.map((c) => [c.id, c.name])),
    payeeNames: new Map(data.payees.map((p) => [p.id, p.name])),
  });
}
