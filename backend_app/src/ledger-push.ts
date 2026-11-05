import fs from 'fs';
import path from 'path';
import type { BudgetRef, BudgetSession, ActualPort } from './budget-session';
import { IMPORTED_ID_PREFIX, REMOVED_NOTE_PREFIX, softDeleteNote, type SoftDeletedTransaction } from './actual';
import { lookupCategory } from './categorydb';
import { ImporterError } from './errors';
import { logger } from './logger';
import type { RawLedgerTransaction } from './ledger';
import { addManualInTurn, MANUAL_ID_PREFIX } from './transactions';

const log = logger.child({ area: 'ledger' });

/**
 * POST /ledger/push (docs/plans/local-ledger.md, Phase 5b): the phone's
 * outbox, one budget turn, answered entry by entry so one bad row doesn't
 * block the rest. Every entry is safe to send twice, because a lost response
 * means the phone sends it again:
 *
 * - a new transaction is found again by its `imported_id`;
 * - a new account or payee is found again through `LedgerClientIds`;
 * - edits, budget amounts and removals simply end up the same.
 *
 * Results carry a code, never a message: Actual's messages can name a payee.
 */

export const MAX_PUSH_ENTRIES = 500;

interface PayeeEntry {
  seq: number;
  kind: 'payee';
  op: 'put';
  id: string;
  name: string;
}

interface AccountEntry {
  seq: number;
  kind: 'account';
  op: 'put';
  id: string;
  name: string;
  offBudget?: boolean;
  closed?: boolean;
}

interface TransactionPut {
  seq: number;
  kind: 'transaction';
  op: 'put';
  id: string;
  accountId: string;
  date: string;
  amountCents: number;
  payeeId?: string | null;
  payeeName?: string | null;
  categoryId?: string | null;
  notes?: string | null;
  cleared?: boolean;
  /** A statement's or quick add's; a new row without one gets `app-<its id>`. */
  importedId?: string | null;
  startingBalance?: boolean;
}

interface TransactionDelete {
  seq: number;
  kind: 'transaction';
  op: 'delete';
  id: string;
}

interface BudgetEntry {
  seq: number;
  kind: 'budget';
  op: 'put';
  categoryId: string;
  month: string;
  budgetedCents: number;
}

export type PushEntry = PayeeEntry | AccountEntry | TransactionPut | TransactionDelete | BudgetEntry;

export type PushResult =
  /** `id` is Actual's id when the phone's differs; `gone`: no longer in Actual. */
  | { seq: number; ok: true; id?: string; gone?: boolean }
  | { seq: number; ok: false; code: string };

export interface LedgerPush {
  results: PushResult[];
  /** For the backend's removal log. */
  softDeleted: Array<SoftDeletedTransaction & { accountId: string }>;
  /** New quick-add rows' payee → category, for the category memory. */
  learned: Array<{ payee: string; categoryId: string }>;
}

// --- Phone ids ---------------------------------------------------------------

const PHONE_ID = /^(tx|acct|payee):/;
/** The app's own categories; only Actual's may reach Actual (CLAUDE.md). */
const LOCAL_CATEGORY = /^(preset|local):/;

/**
 * Which Actual account or payee each phone id became, per budget, in
 * `ledger-client-ids.json` next to the category DB. Nothing in Actual can
 * carry the phone's id, so this is what makes a resend safe for those two.
 */
export class LedgerClientIds {
  constructor(private readonly file: string) {}

  private read(): Record<string, Record<string, string>> {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf8')) as Record<string, Record<string, string>>;
    } catch {
      return {};
    }
  }

  get(syncId: string, phoneId: string): string | undefined {
    return this.read()[syncId]?.[phoneId];
  }

  set(syncId: string, phoneId: string, actualId: string): void {
    const all = this.read();
    all[syncId] = { ...all[syncId], [phoneId]: actualId };
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(all), { mode: 0o600 });
    fs.renameSync(tmp, this.file);
  }
}

export function defaultClientIdsFile(): string {
  return path.join(path.dirname(process.env.CATEGORY_DB_PATH ?? './data/categories.db'), 'ledger-client-ids.json');
}

// --- Validation --------------------------------------------------------------

class PushCodeError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

const isString = (v: unknown): v is string => typeof v === 'string' && v !== '';
const optionalString = (v: unknown) => v === undefined || v === null || typeof v === 'string';
const isCents = (v: unknown) => typeof v === 'number' && Number.isInteger(v) && Math.abs(v) <= 1_000_000_000;

/** True when the entry isn't well formed. */
function invalid(e: Record<string, unknown>): boolean {
  switch (`${String(e.kind)}/${String(e.op)}`) {
    case 'payee/put':
      return !isString(e.id) || !isString(e.name);
    case 'account/put':
      return !isString(e.id) || !isString(e.name);
    case 'transaction/delete':
      return !isString(e.id);
    case 'transaction/put':
      return (
        !isString(e.id) ||
        !isString(e.accountId) ||
        !optionalString(e.importedId) ||
        !/^\d{4}-\d{2}-\d{2}$/.test(String(e.date)) ||
        !isCents(e.amountCents) ||
        !optionalString(e.payeeId) ||
        !optionalString(e.payeeName) ||
        !optionalString(e.categoryId) ||
        !optionalString(e.notes)
      );
    case 'budget/put':
      return !isString(e.categoryId) || !/^\d{4}-(0[1-9]|1[0-2])$/.test(String(e.month)) || !isCents(e.budgetedCents);
    default:
      return true;
  }
}

// --- The push ----------------------------------------------------------------

const truthy = (v: unknown) => v === true || v === 1;
const softDeleted = (t: RawLedgerTransaction) => (t.notes ?? '').startsWith(REMOVED_NOTE_PREFIX);
/** Actual keeps these in step across rows; the phone doesn't change them. */
const linked = (t: RawLedgerTransaction) => Boolean(t.transfer_id) || Boolean(t.parent_id) || truthy(t.is_parent);

const isNewStatementRow = (e: PushEntry): e is TransactionPut =>
  e.kind === 'transaction' && e.op === 'put' && PHONE_ID.test(e.id) && (e.importedId ?? '').startsWith(IMPORTED_ID_PREFIX);

function codeOf(err: unknown): string {
  if (err instanceof PushCodeError) return err.code;
  if (err instanceof ImporterError) return err.code;
  return 'ACTUAL_REJECTED';
}

export async function pushLedger(
  session: BudgetSession,
  budget: BudgetRef,
  entries: unknown[],
  clientIds: LedgerClientIds,
  now: Date = new Date(),
): Promise<LedgerPush> {
  const push: LedgerPush = { results: [], softDeleted: [], learned: [] };
  const valid: PushEntry[] = [];
  for (const raw of entries) {
    const e = (raw ?? {}) as Record<string, unknown>;
    if (typeof e.seq !== 'number') continue; // nothing to answer it by
    if (invalid(e)) push.results.push({ seq: e.seq, ok: false, code: 'INVALID_FIELD' });
    else valid.push(raw as PushEntry);
  }
  if (valid.length === 0) return push;

  const syncId = budget.syncId;
  await session.withBudget(
    budget,
    async (port) => {
      /** What a phone id became: in this push, or in an earlier one. */
      const known = new Map<string, string>();
      const resolve = (id: string) => known.get(id) ?? (PHONE_ID.test(id) ? clientIds.get(syncId, id) : undefined) ?? id;
      const fail = (e: PushEntry, err: unknown) => {
        const code = codeOf(err);
        log.warn({ kind: e.kind, seq: e.seq, code }, 'Ledger change not applied');
        push.results.push({ seq: e.seq, ok: false, code });
      };

      for (let i = 0; i < valid.length; i++) {
        const entry = valid[i];
        if (isNewStatementRow(entry)) {
          // A statement's lines go in one call, like POST /import/confirm:
          // separately, a second identical line would fuzzy-match the first.
          const run = [entry];
          while (
            i + 1 < valid.length &&
            isNewStatementRow(valid[i + 1]) &&
            resolve((valid[i + 1] as TransactionPut).accountId) === resolve(entry.accountId)
          ) {
            run.push(valid[++i] as TransactionPut);
          }
          await importRun(port, syncId, run, resolve, push, fail);
          continue;
        }
        try {
          const result = await applyOne(port, syncId, entry, resolve, known, clientIds, push, now);
          push.results.push({ seq: entry.seq, ok: true, ...result });
        } catch (err) {
          fail(entry, err);
        }
      }
    },
    { write: true },
  );
  return push;
}

function checkTransactionRefs(accountId: string, category: string | null | undefined) {
  if (PHONE_ID.test(accountId)) throw new PushCodeError('WAITING_FOR_ACCOUNT');
  if (category && LOCAL_CATEGORY.test(category)) throw new PushCodeError('LOCAL_CATEGORY');
}

async function importRun(
  port: ActualPort,
  syncId: string,
  run: TransactionPut[],
  resolve: (id: string) => string,
  push: LedgerPush,
  fail: (e: PushEntry, err: unknown) => void,
): Promise<void> {
  const accountId = resolve(run[0].accountId);
  const sendable: TransactionPut[] = [];
  for (const e of run) {
    try {
      checkTransactionRefs(accountId, e.categoryId);
      sendable.push(e);
    } catch (err) {
      fail(e, err);
    }
  }
  if (sendable.length === 0) return;
  try {
    await port.importTransactions(
      accountId,
      sendable.map((e) => ({
        date: e.date,
        amount: e.amountCents,
        payee_name: e.payeeName ?? undefined,
        // As /import/confirm: no choice on the phone falls back to the memory.
        category: e.categoryId ?? (e.payeeName ? lookupCategory(e.payeeName, syncId)?.categoryId : undefined),
        imported_id: e.importedId as string,
        notes: e.notes ?? undefined,
      })),
    );
    // Actual may have matched a line to a row it already had: find each by
    // its imported_id, wherever it landed.
    const rows = (await port.getTransactions(accountId, '1900-01-01', '2999-12-31')) as Array<{
      id: string;
      imported_id?: string | null;
    }>;
    const byImported = new Map(rows.filter((r) => r.imported_id).map((r) => [r.imported_id as string, r.id]));
    for (const e of sendable) {
      const id = byImported.get(e.importedId as string);
      if (id) push.results.push({ seq: e.seq, ok: true, id });
      else fail(e, new PushCodeError('NOT_ADDED'));
    }
  } catch (err) {
    for (const e of sendable) fail(e, err);
  }
}

async function applyOne(
  port: ActualPort,
  syncId: string,
  entry: PushEntry,
  resolve: (id: string) => string,
  known: Map<string, string>,
  clientIds: LedgerClientIds,
  push: LedgerPush,
  now: Date,
): Promise<{ id?: string; gone?: boolean }> {
  switch (entry.kind) {
    case 'payee':
      return applyPayee(port, syncId, entry, known, clientIds);
    case 'account':
      return applyAccount(port, syncId, entry, known, clientIds);
    case 'budget':
      if (LOCAL_CATEGORY.test(entry.categoryId)) throw new PushCodeError('LOCAL_CATEGORY');
      await port.setBudgetAmount(entry.month, entry.categoryId, entry.budgetedCents);
      return {};
    case 'transaction':
      return entry.op === 'delete'
        ? removeTransaction(port, entry, push, now)
        : putTransaction(port, entry, resolve, push);
  }
}

async function applyPayee(
  port: ActualPort,
  syncId: string,
  entry: PayeeEntry,
  known: Map<string, string>,
  clientIds: LedgerClientIds,
): Promise<{ id?: string }> {
  const payees = await port.getPayees();
  if (!PHONE_ID.test(entry.id)) {
    const current = payees.find((p) => p.id === entry.id);
    if (current && current.name !== entry.name) await port.updatePayee(entry.id, { name: entry.name });
    return {};
  }
  const earlier = clientIds.get(syncId, entry.id);
  let id = earlier && payees.some((p) => p.id === earlier) ? earlier : undefined;
  if (!id) {
    // A payee is its name: reuse one the budget already has.
    const key = entry.name.trim().toLowerCase();
    id = payees.find((p) => !p.transfer_acct && p.name.trim().toLowerCase() === key)?.id;
  }
  id ??= await port.createPayee({ name: entry.name });
  clientIds.set(syncId, entry.id, id);
  known.set(entry.id, id);
  return { id };
}

async function applyAccount(
  port: ActualPort,
  syncId: string,
  entry: AccountEntry,
  known: Map<string, string>,
  clientIds: LedgerClientIds,
): Promise<{ id?: string; gone?: boolean }> {
  const accounts = await port.getAccounts();
  if (PHONE_ID.test(entry.id)) {
    const earlier = clientIds.get(syncId, entry.id);
    // The opening balance comes as its own transaction, so it keeps its date.
    // A new account is never closed here: its rows are still on their way.
    const id =
      earlier && accounts.some((a) => a.id === earlier)
        ? earlier
        : await port.createAccount({ name: entry.name, offbudget: entry.offBudget === true });
    clientIds.set(syncId, entry.id, id);
    known.set(entry.id, id);
    return { id };
  }
  const current = accounts.find((a) => a.id === entry.id);
  if (!current) return { gone: true };
  // On or off budget isn't changed afterwards: Actual doesn't offer it.
  if (current.name !== entry.name) await port.updateAccount(entry.id, { name: entry.name });
  if (entry.closed === true && !truthy(current.closed)) await port.closeAccount(entry.id);
  if (entry.closed === false && truthy(current.closed)) await port.reopenAccount(entry.id);
  return {};
}

async function putTransaction(
  port: ActualPort,
  entry: TransactionPut,
  resolve: (id: string) => string,
  push: LedgerPush,
): Promise<{ id?: string; gone?: boolean }> {
  const accountId = resolve(entry.accountId);
  checkTransactionRefs(accountId, entry.categoryId);

  if (PHONE_ID.test(entry.id)) {
    const opening = entry.startingBalance ? await startingBalanceLook(port) : undefined;
    const result = await addManualInTurn(port, {
      accountId,
      date: entry.date,
      amountCents: entry.amountCents,
      payeeName: opening?.payeeName ?? entry.payeeName ?? undefined,
      categoryId: opening?.categoryId ?? entry.categoryId ?? undefined,
      notes: entry.notes ?? undefined,
      importedId: entry.importedId?.startsWith(MANUAL_ID_PREFIX)
        ? entry.importedId
        : `${MANUAL_ID_PREFIX}${entry.id.slice(entry.id.indexOf(':') + 1)}`,
      cleared: entry.cleared,
      startingBalance: entry.startingBalance,
    });
    if (!result.id) throw new PushCodeError('NOT_ADDED');
    if (result.created && entry.payeeName && entry.categoryId) {
      push.learned.push({ payee: entry.payeeName, categoryId: entry.categoryId });
    }
    return { id: result.id };
  }

  const payee = entry.payeeId ? resolve(entry.payeeId) : null;
  if (payee && PHONE_ID.test(payee)) throw new PushCodeError('WAITING_FOR_PAYEE');
  const [current] = await port.ledger.readTransactions([entry.id]);
  if (!current || truthy(current.tombstone) || softDeleted(current)) return { gone: true };
  if (linked(current)) throw new PushCodeError('READ_ONLY');
  await port.updateTransaction(entry.id, {
    account: accountId,
    date: entry.date,
    amount: entry.amountCents,
    payee,
    category: entry.categoryId ?? null,
    notes: entry.notes ?? null,
    cleared: entry.cleared === true,
  });
  return {};
}

/**
 * What Actual gives an account's opening balance itself: the "Starting
 * Balance" payee and the income category of that name (or, as Actual does, the
 * first income category). Without them it counts as uncategorized in Actual.
 */
async function startingBalanceLook(port: ActualPort): Promise<{ payeeName: string; categoryId?: string }> {
  const categories = (await port.getCategories()) as Array<{ id: string; name: string; is_income?: boolean | number }>;
  const income = categories.filter((c) => truthy(c.is_income));
  const category = income.find((c) => c.name.trim().toLowerCase() === 'starting balances') ?? income[0];
  return { payeeName: 'Starting Balance', categoryId: category?.id };
}

/** The soft delete, as POST /import/undo: nothing is deleted in Actual. */
async function removeTransaction(
  port: ActualPort,
  entry: TransactionDelete,
  push: LedgerPush,
  now: Date,
): Promise<{ gone?: boolean }> {
  if (PHONE_ID.test(entry.id)) return { gone: true };
  const [current] = await port.ledger.readTransactions([entry.id]);
  if (!current || truthy(current.tombstone) || softDeleted(current)) return { gone: true };
  if (linked(current)) throw new PushCodeError('READ_ONLY');
  await port.updateTransaction(entry.id, {
    amount: 0,
    notes: softDeleteNote(current.amount, current.notes, now),
  });
  push.softDeleted.push({
    transactionId: current.id,
    accountId: current.account,
    importedId: current.imported_id ?? '',
    date: current.date,
    originalAmountCents: current.amount,
    originalNotes: current.notes ?? undefined,
  });
  return {};
}
