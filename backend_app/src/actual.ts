import * as actualApi from '@actual-app/api';
import { RawTransaction } from './types';

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
): Promise<{ added: number; updated: number }> {
  await ensureInitialized(config);

  const payload = transactions.map((tx) => ({
    date: tx.date,               // already YYYY-MM-DD from the parsers
    amount: tx.amountCents,      // already integer cents from the parsers
    payee_name: tx.payee,
    imported_id: deriveImportedId(tx),
    notes: tx.rawLine,           // keep the original line for auditability
  }));

  const result = await actualApi.importTransactions(accountId, payload);
  return { added: result.added?.length ?? 0, updated: result.updated?.length ?? 0 };
}

export async function shutdownActual() {
  if (!initialized) return;
  await actualApi.shutdown();
  initialized = false;
}
