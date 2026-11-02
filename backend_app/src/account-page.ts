import type { BudgetRef, BudgetSession } from './budget-session';
import { AccountNotFoundError, InvalidFieldError } from './errors';

/**
 * GET /accounts/:id/transactions (Milestone 3): one account's balance and
 * its transactions, newest first, a page at a time. Names are resolved here
 * so the app needs one call per page. Same split as dashboard.ts: one
 * budget turn to read, then the pure `buildAccountPage`.
 */

export interface APAccount {
  id: string;
  name: string;
  offbudget: boolean | 0 | 1;
  closed: boolean | 0 | 1;
}

export interface APTransaction {
  id: string;
  date: string;
  amount: number;
  payee?: string | null;
  category?: string | null;
  notes?: string | null;
  transfer_id?: string | null;
  starting_balance_flag?: boolean;
  cleared?: boolean;
  sort_order?: number | null;
  subtransactions?: APTransaction[];
}

export interface AccountPageRow {
  id: string;
  date: string;
  amountCents: number;
  payee: string | null;
  category: string | null;
  notes: string | null;
  transfer: boolean;
  cleared: boolean;
  /** For a split: its parts, each with its own category. */
  splits?: Array<{ amountCents: number; category: string | null }>;
}

export interface AccountPage {
  account: { id: string; name: string; offbudget: boolean; balanceCents: number };
  transactions: AccountPageRow[];
  /** Pass back as `before` for the next page; absent on the last one. */
  nextCursor?: string;
}

export const DEFAULT_PAGE = 50;
export const MAX_PAGE = 200;

const truthy = (v: boolean | 0 | 1 | undefined) => v === true || v === 1;

/** Newest first; within a day, Actual's own order (higher sort_order first), then id. */
function compareNewestFirst(a: APTransaction, b: APTransaction): number {
  return (
    b.date.localeCompare(a.date) || (b.sort_order ?? 0) - (a.sort_order ?? 0) || b.id.localeCompare(a.id)
  );
}

export function buildAccountPage(input: {
  account: APAccount;
  transactions: APTransaction[];
  categoryNames: Map<string, string>;
  payeeNames: Map<string, string>;
  before?: string;
  limit: number;
}): AccountPage {
  const { account, categoryNames, payeeNames } = input;
  const sorted = [...input.transactions].sort(compareNewestFirst);
  const balanceCents = sorted.reduce((sum, t) => sum + t.amount, 0);

  // The cursor is the last row's id: stable even when rows share a date.
  let start = 0;
  if (input.before) {
    const index = sorted.findIndex((t) => t.id === input.before);
    if (index < 0) throw new InvalidFieldError('before', 'unknown cursor (the list changed; reload from the top)');
    start = index + 1;
  }
  const page = sorted.slice(start, start + input.limit);

  const name = (map: Map<string, string>, id?: string | null) => (id ? (map.get(id) ?? null) : null);
  return {
    account: { id: account.id, name: account.name, offbudget: truthy(account.offbudget), balanceCents },
    transactions: page.map((t) => ({
      id: t.id,
      date: t.date,
      amountCents: t.amount,
      payee: name(payeeNames, t.payee),
      category: name(categoryNames, t.category),
      notes: t.notes ?? null,
      transfer: Boolean(t.transfer_id),
      cleared: Boolean(t.cleared),
      ...(t.subtransactions && t.subtransactions.length > 0
        ? { splits: t.subtransactions.map((s) => ({ amountCents: s.amount, category: name(categoryNames, s.category) })) }
        : {}),
    })),
    ...(start + input.limit < sorted.length ? { nextCursor: page[page.length - 1].id } : {}),
  };
}

export function parseLimit(raw: unknown): number {
  if (raw === undefined || raw === '') return DEFAULT_PAGE;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) throw new InvalidFieldError('limit', 'must be a positive whole number');
  return Math.min(n, MAX_PAGE);
}

export async function getAccountPage(
  session: BudgetSession,
  budget: BudgetRef,
  accountId: string,
  options: { before?: string; limit: number },
): Promise<AccountPage> {
  const data = await session.withBudget(budget, async (actual) => {
    const account = (await actual.getAccounts()).find((a) => a.id === accountId);
    if (!account) throw new AccountNotFoundError(accountId);
    const [transactions, categories, payees] = await Promise.all([
      // Far future too: scheduled or post-dated rows still move the balance.
      actual.getTransactions(accountId, '1970-01-01', '2999-12-31'),
      actual.getCategories(),
      actual.getPayees(),
    ]);
    return { account, transactions, categories, payees };
  });
  return buildAccountPage({
    account: data.account as APAccount,
    transactions: data.transactions as APTransaction[],
    categoryNames: new Map(data.categories.map((c) => [c.id, c.name])),
    payeeNames: new Map(data.payees.map((p) => [p.id, p.name])),
    before: options.before,
    limit: options.limit,
  });
}
