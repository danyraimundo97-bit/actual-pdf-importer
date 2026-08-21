import * as actualApi from '@actual-app/api';
import { RawTransaction } from './types';
import { lookupCategory, rememberCategories } from './categorydb';

export interface ActualConfig {
  serverURL: string;
  password: string;
  dataDir: string; // local cache dir @actual-app/api needs for its sync file
  budgetSyncId: string; // the budget's sync id, found in Actual's advanced settings
  /**
   * Password for this specific budget file's end-to-end encryption, if it
   * has any (see GET /budgets' `encrypted` flag). Completely unrelated to
   * a bank statement PDF's password (see index.ts's PdfPasswordRequiredError)
   * — the two are never the same secret, and the UI must never conflate them.
   */
  budgetPassword?: string;
}

// --- init bookkeeping -----------------------------------------------------
//
// @actual-app/api is a single global connection: actualApi.init() opens
// one connection to the Actual server, and actualApi.downloadBudget()
// swaps in one budget's local sqlite cache at a time. Supporting a budget
// picker (GET /budgets) means two requests for two different budgets must
// never race each other into a half-swapped state, and a request for a
// budget that's already loaded should skip re-downloading it. Both
// properties come from serializing every init/download through one queue.

let serverInitialized = false;
let loadedSyncId: string | null = null;
let queue: Promise<void> = Promise.resolve();

async function ensureServerInitialized(
  config: Pick<ActualConfig, 'serverURL' | 'password' | 'dataDir'>,
): Promise<void> {
  const run = queue.then(async () => {
    if (serverInitialized) return;
    await actualApi.init({
      serverURL: config.serverURL,
      password: config.password,
      dataDir: config.dataDir,
    });
    serverInitialized = true;
  });
  // Keep the queue alive even if this attempt fails, so the *next* request
  // gets a fresh turn instead of inheriting a permanently-rejected chain.
  queue = run.catch(() => {});
  return run;
}

async function ensureInitialized(config: ActualConfig): Promise<void> {
  const run = queue.then(async () => {
    if (!serverInitialized) {
      await actualApi.init({
        serverURL: config.serverURL,
        password: config.password,
        dataDir: config.dataDir,
      });
      serverInitialized = true;
    }
    if (loadedSyncId === config.budgetSyncId) return;
    await actualApi.downloadBudget(
      config.budgetSyncId,
      config.budgetPassword ? { password: config.budgetPassword } : undefined,
    );
    loadedSyncId = config.budgetSyncId;
  });
  queue = run.catch(() => {});
  return run;
}

/**
 * Converts a Portuguese-formatted amount string into a stable dedupe id.
 * Deliberately NOT random (no uuid) so re-uploading the exact same
 * statement is a safe no-op instead of creating duplicates —
 * @actual-app/api's importTransactions() dedupes on this `imported_id`.
 * Exported so server.ts can hand the same id back to the client from
 * POST /parse, and the client can round-trip it to POST /import/confirm
 * unchanged even if it edits the date/amount/payee — see the dedupe note
 * in the front-end plan (§7.3).
 */
export function deriveImportedId(tx: Pick<RawTransaction, 'date' | 'amountCents' | 'payee'>): string {
  const basis = `${tx.date}|${tx.amountCents}|${tx.payee}`;
  // Simple, dependency-free hash — collisions are extremely unlikely for
  // this cardinality (a few hundred transactions per statement) and even
  // if one occurred, worst case is a legitimate duplicate gets merged,
  // not corrupted data.
  let hash = 0;
  for (let i = 0; i < basis.length; i++) {
    hash = (hash * 31 + basis.charCodeAt(i)) | 0;
  }
  return `pdfimport-${hash}`;
}

export interface ImportableTransaction extends RawTransaction {
  /** Carried from POST /parse's response so edits don't break dedupe. Falls back to a fresh derivation if omitted. */
  importedId?: string;
  /** User's explicit category choice from the review screen. Falls back to category memory when omitted. */
  categoryId?: string;
}

export async function importToActual(
  config: ActualConfig,
  accountId: string,
  transactions: ImportableTransaction[],
): Promise<{ added: number; updated: number; categorized: number }> {
  await ensureInitialized(config);

  let categorized = 0;
  const payload = transactions.map((tx) => {
    // An explicit categoryId from the review screen wins; otherwise fall
    // back to local memory (see categorydb.ts) if we've seen this exact
    // payee before in this budget — either taught directly or learned
    // from Actual's own already-categorized transactions. If neither
    // applies, the transaction still imports fine, just uncategorized.
    const match = tx.categoryId ? undefined : lookupCategory(tx.payee, config.budgetSyncId);
    const categoryId = tx.categoryId ?? match?.categoryId;
    if (categoryId) categorized++;

    return {
      date: tx.date, // already YYYY-MM-DD from the parsers
      amount: tx.amountCents, // already integer cents from the parsers
      payee_name: tx.payee,
      category: categoryId,
      imported_id: tx.importedId ?? deriveImportedId(tx),
      notes: tx.rawLine, // keep the original line for auditability
    };
  });

  const result = await actualApi.importTransactions(accountId, payload);
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
  config: ActualConfig,
  accountId: string,
  startDate: string,
  endDate: string,
): Promise<{ learned: number; scanned: number }> {
  await ensureInitialized(config);

  const [categories, payees, transactions] = await Promise.all([
    actualApi.getCategories(),
    actualApi.getPayees(),
    actualApi.getTransactions(accountId, startDate, endDate),
  ]);

  const categoryNameById = new Map(categories.map((c) => [c.id, c.name]));
  const payeeNameById = new Map(payees.map((p) => [p.id, p.name]));

  const entries: Array<{ payee: string; categoryId: string; categoryName?: string }> = [];
  for (const tx of transactions) {
    if (!tx.category || !tx.payee) continue;
    const payeeName = payeeNameById.get(tx.payee);
    if (!payeeName) continue;
    entries.push({ payee: payeeName, categoryId: tx.category, categoryName: categoryNameById.get(tx.category) });
  }

  const learned = rememberCategories(entries, config.budgetSyncId);
  return { learned, scanned: transactions.length };
}

/** GET /accounts. */
export async function listAccounts(config: ActualConfig) {
  await ensureInitialized(config);
  return actualApi.getAccounts();
}

/** GET /actual/categories — grouped, with hidden groups/categories filtered out. */
export async function listCategoryGroups(config: ActualConfig) {
  await ensureInitialized(config);
  const groups = await actualApi.getCategoryGroups();
  return groups
    .filter((g) => !g.hidden)
    .map((g) => ({ ...g, categories: g.categories.filter((c) => !c.hidden) }));
}

/**
 * GET /budgets. Only needs the server connection, not any particular
 * budget's local cache downloaded — kept separate from ensureInitialized
 * so listing budgets doesn't force-download whichever one happens to be
 * default.
 */
export async function listBudgets(config: Pick<ActualConfig, 'serverURL' | 'password' | 'dataDir'>) {
  await ensureServerInitialized(config);
  const budgets = await actualApi.getBudgets();
  return budgets.map((b) => ({
    syncId: b.cloudFileId,
    name: b.name,
    encrypted: b.hasKey,
  }));
}

export async function shutdownActual() {
  if (!serverInitialized) return;
  await actualApi.shutdown();
  serverInitialized = false;
  loadedSyncId = null;
}
