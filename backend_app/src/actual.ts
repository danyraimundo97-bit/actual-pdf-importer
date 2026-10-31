import { RawTransaction } from './types';
import { lookupCategory, rememberCategories } from './categorydb';
import type { BudgetRef, BudgetSession } from './budget-session';

/**
 * A transaction's dedupe basis: the fields a reader would use to recognise
 * "the same movement". NOT unique on its own — see assignImportedIds.
 */
type DedupeBasis = Pick<RawTransaction, 'date' | 'amountCents' | 'payee'>;

/**
 * Every `imported_id` this app writes starts with this. It's how undoing an
 * import tells its own transactions apart from anything else in Actual.
 */
export const IMPORTED_ID_PREFIX = 'pdfimport-';

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
  return `${IMPORTED_ID_PREFIX}${hash}`;
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
): Promise<{ added: number; updated: number; categorized: number; addedIds: string[] }> {
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
    // The ids of the transactions this import created, so it can be undone
    // later (undoImport). `updated` ones existed before and are never undone.
    addedIds: result.added ?? [],
  };
}

/** Starts the note on every transaction an undone import zeroed out. */
export const REMOVED_NOTE_PREFIX = '[Removed via PDF importer';

function formatCents(cents: number): string {
  return (cents / 100).toFixed(2);
}

/** What undoImport changed, for the backend's removal log (removal-log.ts). */
export interface SoftDeletedTransaction {
  transactionId: string;
  importedId: string;
  date: string;
  payee?: string;
  originalAmountCents: number;
  originalNotes?: string;
}

/**
 * Undoes one import as a soft delete, given the `addedIds` its POST
 * /import/confirm returned. Nothing is deleted in Actual: each transaction
 * keeps its place but gets amount 0.00 and a note saying it was removed and
 * what it was, so balances drop it while the history stays visible. The
 * returned list is what the caller records in the removal log.
 *
 * Only a transaction that is in that list AND still carries this app's
 * imported_id is touched, so a wrong or tampered id list can't change
 * anything this app didn't import. Ids that no longer match (deleted in
 * Actual, another account's, or already removed) count as skipped: undoing
 * twice is harmless and never overwrites the original amount in the log.
 */
export async function undoImport(
  session: BudgetSession,
  budget: BudgetRef,
  accountId: string,
  transactionIds: string[],
  now: Date = new Date(),
): Promise<{ removed: number; skipped: number; softDeleted: SoftDeletedTransaction[] }> {
  const wanted = new Set(transactionIds);
  const day = now.toISOString().slice(0, 10);
  return session.withBudget(budget, async (actual) => {
    // The whole range: the user may have re-dated a transaction since.
    const all = (await actual.getTransactions(accountId, '1900-01-01', '2999-12-31')) as Array<{
      id: string;
      imported_id?: string | null;
      imported_payee?: string | null;
      date: string;
      amount: number;
      notes?: string | null;
    }>;
    const ours = all.filter(
      (t) =>
        wanted.has(t.id) &&
        typeof t.imported_id === 'string' &&
        t.imported_id.startsWith(IMPORTED_ID_PREFIX) &&
        !(t.notes ?? '').startsWith(REMOVED_NOTE_PREFIX),
    );

    const softDeleted: SoftDeletedTransaction[] = [];
    for (const t of ours) {
      const was = `${REMOVED_NOTE_PREFIX} on ${day}, was ${formatCents(t.amount)}]`;
      await actual.updateTransaction(t.id, { amount: 0, notes: t.notes ? `${was} ${t.notes}` : was });
      softDeleted.push({
        transactionId: t.id,
        importedId: t.imported_id as string,
        date: t.date,
        payee: t.imported_payee ?? undefined,
        originalAmountCents: t.amount,
        originalNotes: t.notes ?? undefined,
      });
    }
    return { removed: ours.length, skipped: wanted.size - ours.length, softDeleted };
  });
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
    // Annotated by hand: @actual-app/api 26 declares these types in
    // @actual-app/core via package "exports", which this tsconfig's module
    // resolution doesn't follow, so they arrive untyped.
    .map((g) => ({ ...g, categories: g.categories.filter((c: { hidden?: boolean }) => !c.hidden) }));
}

/**
 * GET /budgets. Only needs the server connection, not any particular
 * budget downloaded — uses withServer so listing budgets doesn't force-
 * download whichever one happens to be default.
 *
 * `syncId` is the SDK's `groupId` — the "Sync ID" Actual shows in its
 * advanced settings, and the only id downloadBudget() looks budgets up by.
 * `cloudFileId` is the server's internal file id and is NOT interchangeable:
 * returning it here made every budget picked in the app fail with "Budget …
 * not found".
 *
 * The SDK lists local copies and server files together, so a budget already
 * downloaded into ACTUAL_DATA_DIR appears twice; one entry per groupId. A
 * local-only budget (never uploaded) has no groupId and can't be downloaded
 * by sync id, so it's left out.
 */
export async function listBudgets(session: BudgetSession) {
  const budgets = await session.withServer((actual) => actual.getBudgets());
  const bySyncId = new Map<string, { syncId: string; name: string; encrypted: boolean }>();
  for (const b of budgets) {
    if (!b.groupId || bySyncId.has(b.groupId)) continue;
    // encryptKeyId, not hasKey: hasKey only says whether this machine already
    // holds the key, but downloadBudget() demands the password for any
    // encrypted file regardless.
    bySyncId.set(b.groupId, { syncId: b.groupId, name: b.name, encrypted: Boolean(b.encryptKeyId) });
  }
  return [...bySyncId.values()];
}
