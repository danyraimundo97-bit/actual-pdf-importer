import * as actualApi from '@actual-app/api';
import { RawTransaction } from './types';
import { lookupCategory, rememberCategories } from './categorydb';

interface ActualConfig {
  serverURL: string;
  password: string;
  dataDir: string; // local cache dir @actual-app/api needs for its sync file
  budgetSyncId: string; // the budget's sync id, found in Actual's advanced settings
}

let initialized = false;

async function ensureInitialized(config: ActualConfig) {
  if (initialized) return;
  await actualApi.init({
    serverURL: config.serverURL,
    password: config.password,
    dataDir: config.dataDir,
  });
  await actualApi.downloadBudget(config.budgetSyncId);
  initialized = true;
}

/**
 * @actual-app/api's importTransactions() dedupes using an `imported_id`.
 * We derive a stable one from the transaction's own fields (not a random
 * uuid) so re-uploading the same statement twice is a safe no-op instead
 * of creating duplicates.
 */
function deriveImportedId(tx: RawTransaction): string {
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

export async function importToActual(
  config: ActualConfig,
  accountId: string,
  transactions: RawTransaction[],
): Promise<{ added: number; updated: number; categorized: number }> {
  await ensureInitialized(config);

  let categorized = 0;
  const payload = transactions.map((tx) => {
    // Pre-fill the category from local memory (see categorydb.ts) if we've
    // seen this exact payee before — either taught directly or learned
    // from Actual's own already-categorized transactions. If we haven't,
    // the transaction still imports fine, just uncategorized (or caught
    // later by Actual's own rules, if any match).
    const match = lookupCategory(tx.payee);
    if (match) categorized++;

    return {
      date: tx.date,               // already YYYY-MM-DD from the parsers
      amount: tx.amountCents,      // already integer cents from the parsers
      payee_name: tx.payee,
      category: match?.categoryId,
      imported_id: deriveImportedId(tx),
      notes: tx.rawLine,           // keep the original line for auditability
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
 * locally. This is how the memory gets built without a manual admin UI —
 * categorize normally in the Actual app once, then call this to backfill.
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

  const learned = rememberCategories(entries);
  return { learned, scanned: transactions.length };
}

export async function shutdownActual() {
  if (!initialized) return;
  await actualApi.shutdown();
  initialized = false;
}
