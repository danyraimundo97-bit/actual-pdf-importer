import { accountBalanceCents } from './account-page';
import type { ActualPort, BudgetRef, BudgetSession } from './budget-session';
import { AccountNotFoundError, ImporterError, InvalidFieldError } from './errors';

/**
 * Quick add (docs/plans/core-app.md, Milestone 2): one transaction typed in
 * the app, e.g. a cash purchase.
 *
 * Created with `addTransactions`, not `importTransactions`: an import
 * fuzzy-matches against any transaction with the same amount within ±7 days
 * in that account, so a second 4,50 coffee would be swallowed as "already
 * there". `addTransactions` still runs Actual's rules on the payee.
 *
 * Retries are safe: the app sends a `clientId` generated once per form, kept
 * as `imported_id: "app-<clientId>"`, and a transaction already carrying it
 * is returned instead of added again. The `app-` prefix keeps these out of
 * the PDF undo path, which only touches `pdfimport-` ids.
 */

export const MANUAL_ID_PREFIX = 'app-';

export interface ManualTransaction {
  accountId: string;
  date: string; // YYYY-MM-DD
  amountCents: number; // negative = outflow
  payeeName?: string;
  categoryId?: string;
  notes?: string;
  clientId: string;
}

class MissingFieldError extends ImporterError {
  constructor(field: string) {
    super('MISSING_FIELD', `Missing required field "${field}".`, 400);
  }
}

const optionalString = (body: Record<string, unknown>, key: string, max: number): string | undefined => {
  const value = body[key];
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string') throw new InvalidFieldError(key, 'must be a string');
  const trimmed = value.trim();
  if (trimmed.length > max) throw new InvalidFieldError(key, `longer than ${max} characters`);
  return trimmed || undefined;
};

/** Validates POST /transactions' body. */
export function parseManualTransaction(body: unknown): ManualTransaction {
  const b = (body ?? {}) as Record<string, unknown>;
  for (const field of ['accountId', 'date', 'amountCents', 'clientId']) {
    if (b[field] === undefined || b[field] === null || b[field] === '') throw new MissingFieldError(field);
  }
  if (typeof b.accountId !== 'string') throw new InvalidFieldError('accountId', 'must be a string');
  if (typeof b.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(b.date) || Number.isNaN(Date.parse(b.date))) {
    throw new InvalidFieldError('date', 'expected YYYY-MM-DD');
  }
  if (typeof b.amountCents !== 'number' || !Number.isInteger(b.amountCents)) {
    throw new InvalidFieldError('amountCents', 'must be whole cents');
  }
  if (b.amountCents === 0) throw new InvalidFieldError('amountCents', 'must not be zero');
  if (Math.abs(b.amountCents) > 1_000_000_000) throw new InvalidFieldError('amountCents', 'too large');
  if (typeof b.clientId !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(b.clientId)) {
    throw new InvalidFieldError('clientId', 'expected 8-64 letters, digits or dashes');
  }
  return {
    accountId: b.accountId,
    date: b.date,
    amountCents: b.amountCents,
    payeeName: optionalString(b, 'payeeName', 200),
    categoryId: optionalString(b, 'categoryId', 100),
    notes: optionalString(b, 'notes', 1000),
    clientId: b.clientId,
  };
}

export async function addManualTransaction(
  session: BudgetSession,
  budget: BudgetRef,
  input: ManualTransaction,
): Promise<{ id: string | null; created: boolean }> {
  return session.withBudget(
    budget,
    (actual) => addManualInTurn(actual, { ...input, importedId: `${MANUAL_ID_PREFIX}${input.clientId}` }),
    { write: true },
  );
}

/** One manual row, inside a budget turn; also the ledger push's way in. */
export async function addManualInTurn(
  actual: ActualPort,
  input: Omit<ManualTransaction, 'clientId'> & { importedId: string; cleared?: boolean; startingBalance?: boolean },
): Promise<{ id: string | null; created: boolean }> {
  const account = (await actual.getAccounts()).find((a) => a.id === input.accountId);
  if (!account || account.closed) throw new AccountNotFoundError(input.accountId);

  const findOurs = async () =>
    (await actual.getTransactions(input.accountId, input.date, input.date)).find(
      (t) => t.imported_id === input.importedId,
    );

  const existing = await findOurs();
  if (existing) return { id: existing.id, created: false };

  await actual.addTransactions(
    input.accountId,
    [
      {
        date: input.date,
        amount: input.amountCents,
        payee_name: input.payeeName,
        category: input.categoryId,
        notes: input.notes,
        imported_id: input.importedId,
        cleared: input.cleared,
        ...(input.startingBalance ? { starting_balance_flag: true } : {}),
      },
    ],
    { runTransfers: false, learnCategories: false },
  );
  return { id: (await findOurs())?.id ?? null, created: true };
}

// --- POST /accounts/:id/balance ---------------------------------------------

export const BALANCE_ADJUSTMENT_NOTE = 'Balance adjustment';

export interface BalanceAdjustment {
  accountId: string;
  date: string; // YYYY-MM-DD
  balanceCents: number; // what the account really holds; negative = owed
  clientId: string;
}

/** Validates POST /accounts/:id/balance's body. */
export function parseBalanceAdjustment(accountId: string, body: unknown): BalanceAdjustment {
  const b = (body ?? {}) as Record<string, unknown>;
  for (const field of ['date', 'balanceCents', 'clientId']) {
    if (b[field] === undefined || b[field] === null || b[field] === '') throw new MissingFieldError(field);
  }
  if (typeof b.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(b.date) || Number.isNaN(Date.parse(b.date))) {
    throw new InvalidFieldError('date', 'expected YYYY-MM-DD');
  }
  if (typeof b.balanceCents !== 'number' || !Number.isInteger(b.balanceCents)) {
    throw new InvalidFieldError('balanceCents', 'must be whole cents');
  }
  if (Math.abs(b.balanceCents) > 1_000_000_000) throw new InvalidFieldError('balanceCents', 'too large');
  if (typeof b.clientId !== 'string' || !/^[A-Za-z0-9-]{8,64}$/.test(b.clientId)) {
    throw new InvalidFieldError('clientId', 'expected 8-64 letters, digits or dashes');
  }
  return { accountId, date: b.date, balanceCents: b.balanceCents, clientId: b.clientId };
}

/**
 * Makes an account hold what the user says it holds, the way Actual's own
 * reconcile does: nothing is rewritten, one cleared, uncategorized
 * transaction makes up the difference.
 *
 * The difference is worked out here, inside the write turn (which syncs
 * first), never on the phone: the balance on its screen may be stale. A
 * retry with the same clientId returns the adjustment already made; working
 * it out again would see no difference and report 0.
 */
export async function setAccountBalance(
  session: BudgetSession,
  budget: BudgetRef,
  input: BalanceAdjustment,
): Promise<{ id: string | null; created: boolean; adjustmentCents: number; balanceCents: number }> {
  const importedId = `${MANUAL_ID_PREFIX}${input.clientId}`;
  return session.withBudget(
    budget,
    async (actual) => {
      const account = (await actual.getAccounts()).find((a) => a.id === input.accountId);
      if (!account || account.closed) throw new AccountNotFoundError(input.accountId);

      const all = () => actual.getTransactions(input.accountId, '1970-01-01', '2999-12-31');
      const before = await all();

      const existing = before.find((t) => t.imported_id === importedId);
      if (existing) {
        return {
          id: existing.id,
          created: false,
          adjustmentCents: existing.amount,
          balanceCents: accountBalanceCents(before),
        };
      }

      const adjustmentCents = input.balanceCents - accountBalanceCents(before);
      if (adjustmentCents === 0) {
        return { id: null, created: false, adjustmentCents: 0, balanceCents: input.balanceCents };
      }

      await actual.addTransactions(
        input.accountId,
        [
          {
            date: input.date,
            amount: adjustmentCents,
            notes: BALANCE_ADJUSTMENT_NOTE,
            cleared: true,
            imported_id: importedId,
          },
        ],
        { runTransfers: false, learnCategories: false },
      );
      const added = (await all()).find((t) => t.imported_id === importedId);
      return { id: added?.id ?? null, created: true, adjustmentCents, balanceCents: input.balanceCents };
    },
    { write: true },
  );
}

// --- GET /quick-add/options ------------------------------------------------

export interface QAAccount {
  id: string;
  name: string;
  offbudget: boolean | 0 | 1;
  closed: boolean | 0 | 1;
}

export interface QATransaction {
  date: string;
  payee?: string | null;
  category?: string | null;
  transfer_id?: string | null;
  starting_balance_flag?: boolean;
  is_parent?: boolean;
}

export interface QAPayee {
  id: string;
  name: string;
  transfer_acct?: string | null;
}

export interface QACategoryGroup {
  id: string;
  name: string;
  is_income?: boolean | 0 | 1;
  hidden?: boolean | 0 | 1;
  categories?: Array<{ id: string; name: string; hidden?: boolean | 0 | 1 }>;
}

export interface QuickAddOptions {
  accounts: Array<{ id: string; name: string; offbudget: boolean }>;
  categoryGroups: Array<{
    id: string;
    name: string;
    isIncome: boolean;
    categories: Array<{ id: string; name: string }>;
  }>;
  /** Most recently used first, each with the category it last had. */
  recentPayees: Array<{ name: string; lastCategoryId: string | null }>;
}

const truthy = (v: boolean | 0 | 1 | undefined) => v === true || v === 1;

export const RECENT_PAYEES = 50;

/** Everything the quick-add screen needs, in one response. */
export function buildQuickAddOptions(input: {
  accounts: QAAccount[];
  categoryGroups: QACategoryGroup[];
  payees: QAPayee[];
  transactions: QATransaction[];
}): QuickAddOptions {
  const accounts = input.accounts
    .filter((a) => !truthy(a.closed))
    .map((a) => ({ id: a.id, name: a.name, offbudget: truthy(a.offbudget) }))
    // On-budget first: where everyday spending usually goes.
    .sort((a, b) => Number(a.offbudget) - Number(b.offbudget));

  const categoryGroups = input.categoryGroups
    .filter((g) => !truthy(g.hidden))
    .map((g) => ({
      id: g.id,
      name: g.name,
      isIncome: truthy(g.is_income),
      categories: (g.categories ?? []).filter((c) => !truthy(c.hidden)).map((c) => ({ id: c.id, name: c.name })),
    }))
    .filter((g) => g.categories.length > 0);

  // Transfers' payees are other accounts, not someone you pay.
  const payeeNames = new Map(input.payees.filter((p) => !p.transfer_acct).map((p) => [p.id, p.name]));
  const seen = new Set<string>();
  const recentPayees: QuickAddOptions['recentPayees'] = [];
  const newestFirst = [...input.transactions]
    .filter((t) => !t.transfer_id && !t.starting_balance_flag && t.payee)
    .sort((a, b) => b.date.localeCompare(a.date));
  for (const tx of newestFirst) {
    const name = payeeNames.get(tx.payee!);
    if (!name || seen.has(name)) continue;
    seen.add(name);
    recentPayees.push({ name, lastCategoryId: tx.is_parent ? null : (tx.category ?? null) });
    if (recentPayees.length >= RECENT_PAYEES) break;
  }

  return { accounts, categoryGroups, recentPayees };
}

const RECENT_DAYS = 120;

export async function getQuickAddOptions(
  session: BudgetSession,
  budget: BudgetRef,
  today: Date = new Date(),
): Promise<QuickAddOptions> {
  const since = new Date(today.getTime() - RECENT_DAYS * 86_400_000).toISOString().slice(0, 10);
  const until = today.toISOString().slice(0, 10);
  const data = await session.withBudget(budget, async (actual) => {
    const [accounts, categoryGroups, payees] = await Promise.all([
      actual.getAccounts(),
      actual.getCategoryGroups(),
      actual.getPayees(),
    ]);
    const open = accounts.filter((a) => !a.closed);
    const perAccount = await Promise.all(open.map((a) => actual.getTransactions(a.id, since, until)));
    return { accounts, categoryGroups, payees, transactions: perAccount.flat() };
  });
  return buildQuickAddOptions({
    accounts: data.accounts as QAAccount[],
    categoryGroups: data.categoryGroups as QACategoryGroup[],
    payees: data.payees as QAPayee[],
    transactions: data.transactions as QATransaction[],
  });
}
