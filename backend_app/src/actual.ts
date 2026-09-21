import { RawTransaction } from './types';
import { lookupCategory, rememberCategories } from './categorydb';
import type { BudgetRef, BudgetSession } from './budget-session';

/**
 * A transaction's dedupe basis: the fields a reader would use to recognise
 * "the same movement". NOT unique on its own — see assignImportedIds.
 */
type DedupeBasis = Pick<RawTransaction, 'date' | 'amountCents' | 'payee'>;

const basisOf = (tx: DedupeBasis): string => `${tx.date}|${tx.amountCents}|${tx.payee}`;

/**
 * Derives a stable dedupe id. Deliberately NOT random (no uuid) so
 * re-uploading the exact same statement is a safe no-op instead of
 * creating duplicates — @actual-app/api's importTransactions() dedupes on
 * this `imported_id`.
 *
 * `occurrence` distinguishes movements that share a basis: date + amount +
 * payee is genuinely NOT unique within a statement (the same person
 * sending you 10,00 twice in one day is ordinary, and banks truncate
 * payees to a fixed width, which collapses distinct names onto one).
 * Without it those rows share an id and Actual silently swallows all but
 * the first.
 *
 * Occurrence 0 hashes the bare basis, so ids already imported by earlier
 * versions keep matching and re-importing an old statement stays a no-op.
 * That compatibility is pinned by golden ids in actual.test.ts — changing
 * `basisOf` or this hash silently duplicates every past import.
 *
 * Module-private on purpose: an occurrence number is only meaningful
 * relative to a whole statement, so callers go through assignImportedIds.
 */
function deriveImportedId(tx: DedupeBasis, occurrence: number): string {
  const basis = occurrence === 0 ? basisOf(tx) : `${basisOf(tx)}|#${occurrence}`;
  // Simple, dependency-free hash. A hash collision across two different
  // bases is vanishingly unlikely at a statement's cardinality; the real
  // collision risk was the basis itself, which `occurrence` now settles.
  let hash = 0;
  for (let i = 0; i < basis.length; i++) {
    hash = (hash * 31 + basis.charCodeAt(i)) | 0;
  }
  return `pdfimport-${hash}`;
}

/**
 * Stamps a statement's transactions with dedupe ids, numbering repeats of
 * the same basis as it goes. The only way to get an id: uniqueness is a
 * property of a movement *within its statement*, so it can only be decided
 * over the whole list.
 *
 * An `importedId` the caller already carries (round-tripped from
 * POST /parse) is kept as-is, so client-side edits to date/amount/payee
 * never break dedupe. Repeats are still counted across every row, so a
 * partially-stamped list numbers the rest exactly as /parse did.
 */
export function assignImportedIds<T extends DedupeBasis & { importedId?: string }>(
  transactions: T[],
): Array<T & { importedId: string }> {
  const occurrences = new Map<string, number>();
  return transactions.map((tx) => {
    const basis = basisOf(tx);
    const occurrence = occurrences.get(basis) ?? 0;
    occurrences.set(basis, occurrence + 1);
    return { ...tx, importedId: tx.importedId ?? deriveImportedId(tx, occurrence) };
  });
}

export interface ImportableTransaction extends RawTransaction {
  /** Carried from POST /parse's response so edits don't break dedupe. Falls back to a fresh derivation if omitted. */
  importedId?: string;
  /** User's explicit category choice from the review screen. Falls back to category memory when omitted. */
  categoryId?: string;
}

export async function importToActual(
  session: BudgetSession,
  budget: BudgetRef,
  accountId: string,
  transactions: ImportableTransaction[],
): Promise<{ added: number; updated: number; categorized: number }> {
  let categorized = 0;
  const payload = assignImportedIds(transactions).map((tx) => {
    // An explicit categoryId from the review screen wins; otherwise fall
    // back to local memory (see categorydb.ts) if we've seen this exact
    // payee before in this budget — either taught directly or learned
    // from Actual's own already-categorized transactions. If neither
    // applies, the transaction still imports fine, just uncategorized.
    // (This reads the local category memory, not Actual, so it doesn't
    // need to happen inside the budget session's turn.)
    const match = tx.categoryId ? undefined : lookupCategory(tx.payee, budget.syncId);
    const categoryId = tx.categoryId ?? match?.categoryId;
    if (categoryId) categorized++;

    return {
      date: tx.date, // already YYYY-MM-DD from the parsers
      amount: tx.amountCents, // already integer cents from the parsers
      payee_name: tx.payee,
      category: categoryId,
      imported_id: tx.importedId,
      notes: tx.rawLine, // keep the original line for auditability
    };
  });

  const result = await session.withBudget(budget, (actual) => actual.importTransactions(accountId, payload));
  return {
    added: result.added?.length ?? 0,
    updated: result.updated?.length ?? 0,
    categorized,
  };
}

/**
 * Syncs the category memory (categorydb.ts) FROM Actual: pulls
 * already-categorized transactions for an account/date-range, and for
 * every payee that has a category assigned, remembers that mapping
 * locally (scoped to this budget). This is how the memory gets built
 * without a manual admin UI — categorize normally in the Actual app once,
 * then call this to backfill.
 */
export async function learnCategoriesFromActual(
  session: BudgetSession,
  budget: BudgetRef,
  accountId: string,
  startDate: string,
  endDate: string,
): Promise<{ learned: number; scanned: number }> {
  const [categories, payees, transactions] = await session.withBudget(budget, (actual) =>
    Promise.all([
      actual.getCategories(),
      actual.getPayees(),
      actual.getTransactions(accountId, startDate, endDate),
    ]),
  );

  const categoryNameById = new Map(categories.map((c) => [c.id, c.name]));
  const payeeNameById = new Map(payees.map((p) => [p.id, p.name]));

  const entries: Array<{ payee: string; categoryId: string; categoryName?: string }> = [];
  for (const tx of transactions) {
    if (!tx.category || !tx.payee) continue;
    const payeeName = payeeNameById.get(tx.payee);
    if (!payeeName) continue;
    entries.push({ payee: payeeName, categoryId: tx.category, categoryName: categoryNameById.get(tx.category) });
  }

  const learned = rememberCategories(entries, budget.syncId);
  return { learned, scanned: transactions.length };
}

/** GET /accounts. */
export function listAccounts(session: BudgetSession, budget: BudgetRef) {
  return session.withBudget(budget, (actual) => actual.getAccounts());
}

/** GET /actual/categories — grouped, with hidden groups/categories filtered out. */
export async function listCategoryGroups(session: BudgetSession, budget: BudgetRef) {
  const groups = await session.withBudget(budget, (actual) => actual.getCategoryGroups());
  return groups
    .filter((g) => !g.hidden)
    .map((g) => ({ ...g, categories: g.categories.filter((c) => !c.hidden) }));
}

/**
 * GET /budgets. Only needs the server connection, not any particular
 * budget downloaded — uses withServer so listing budgets doesn't force-
 * download whichever one happens to be default.
 */
export async function listBudgets(session: BudgetSession) {
  const budgets = await session.withServer((actual) => actual.getBudgets());
  return budgets.map((b) => ({
    syncId: b.cloudFileId,
    name: b.name,
    encrypted: b.hasKey,
  }));
}
