import fs from 'fs';
import * as actualApi from '@actual-app/api';
import type { ActualAdapter } from './budget-session';
import { BudgetNotFoundError } from './errors';
import type { BudgetType, ChangeLog, LedgerPort, RawBudgetAmount, RawLedgerTransaction } from './ledger';

/** What `init()` hands back: Actual's internals, used only by [ledgerReads]. */
type ActualHandle = Awaited<ReturnType<typeof actualApi.init>>;
let handle: ActualHandle | null = null;

function internals(): ActualHandle {
  if (!handle) throw new Error('Actual is not initialised');
  return handle;
}

/** Narrow view of Actual's sqlite helpers (read-only use below). */
interface SqlReads {
  all(sql: string, params?: unknown[]): Promise<unknown[]>;
  first(sql: string, params?: unknown[]): Promise<unknown>;
}
const sql = (): SqlReads => internals().db as unknown as SqlReads;

const TRANSACTION_FIELDS = [
  'id',
  'account',
  'date',
  'amount',
  'payee',
  'category',
  'notes',
  'cleared',
  'imported_id',
  'starting_balance_flag',
  'transfer_id',
  'parent_id',
  'is_parent',
  'tombstone',
];

/**
 * The ledger sync's reads (docs/plans/local-ledger.md, Phase 0 result).
 * `messages_crdt` and the budget tables are Actual's internals: SELECTs
 * only, and `ledger.test.ts` pins what comes back.
 */
const ledgerReads: LedgerPort = {
  async readChangeLog(afterId: number): Promise<ChangeLog> {
    const db = sql();
    const entries = (await db.all('SELECT id, dataset, row FROM messages_crdt WHERE id > ? ORDER BY id', [
      afterId,
    ])) as ChangeLog['entries'];
    const oldest = (await db.first('SELECT id, timestamp FROM messages_crdt ORDER BY id LIMIT 1')) as
      | ChangeLog['oldest']
      | undefined;
    const max = (await db.first('SELECT MAX(id) AS id FROM messages_crdt')) as { id: number | null } | undefined;
    return { entries, oldest: oldest ?? null, maxId: max?.id ?? null };
  },

  async readTransactions(ids?: string[]): Promise<RawLedgerTransaction[]> {
    const { q } = internals();
    let query = q('transactions').options({ splits: 'all' });
    if (ids) query = query.filter({ id: { $oneof: ids } }).withDead();
    const result = (await actualApi.aqlQuery(query.select(TRANSACTION_FIELDS))) as { data: RawLedgerTransaction[] };
    return result.data;
  },

  async readBudgetType(): Promise<BudgetType> {
    const row = (await sql().first("SELECT value FROM preferences WHERE id = 'budgetType'")) as
      | { value?: string }
      | undefined;
    return row?.value === 'tracking' ? 'tracking' : 'envelope';
  },

  async readBudgetAmounts(type: BudgetType, ids?: string[]): Promise<RawBudgetAmount[]> {
    const table = type === 'tracking' ? 'reflect_budgets' : 'zero_budgets';
    const base = `SELECT id, month, category, amount, carryover FROM ${table}`;
    if (!ids) return (await sql().all(base)) as RawBudgetAmount[];
    if (ids.length === 0) return [];
    const marks = ids.map(() => '?').join(', ');
    return (await sql().all(`${base} WHERE id IN (${marks})`, ids)) as RawBudgetAmount[];
  },
};

/**
 * Errors from SDK calls that were already delivered to (and handled by) our
 * caller. The SDK's downloadBudget() rejects its returned promise *and*
 * leaks the very same Error object as an unhandled rejection, which Node
 * treats as fatal — one bad sync id took the whole server down. server.ts's
 * unhandledRejection hook drops exactly these and nothing else.
 */
const handledSdkErrors = new WeakSet<object>();

export function isHandledSdkError(reason: unknown): boolean {
  return typeof reason === 'object' && reason !== null && handledSdkErrors.has(reason);
}

/**
 * The only module that talks to @actual-app/api's lifecycle functions.
 * `port` lists its methods explicitly (rather than handing over the whole
 * namespace) so callbacks can't reach init()/downloadBudget() at runtime
 * either, not just in the types.
 */
export const actualSdkAdapter: ActualAdapter = {
  async init({ serverURL, password, dataDir }) {
    // The SDK doesn't create its cache folder: init() succeeds without it,
    // then getBudgets() fails with ENOENT scanning it for local budgets.
    fs.mkdirSync(dataDir, { recursive: true });
    handle = await actualApi.init({ serverURL, password, dataDir });
  },

  async downloadBudget({ syncId, budgetPassword }) {
    // Check first, so the common failure (an unknown sync id) gets a typed
    // error and never reaches the SDK path that leaks a rejection.
    const known = await actualApi.getBudgets();
    if (!known.some((b) => b.groupId === syncId)) throw new BudgetNotFoundError(syncId);

    try {
      await actualApi.downloadBudget(syncId, budgetPassword ? { password: budgetPassword } : undefined);
    } catch (err) {
      if (typeof err === 'object' && err !== null) handledSdkErrors.add(err);
      throw err;
    }
  },

  sync: () => actualApi.sync(),

  async shutdown() {
    handle = null;
    await actualApi.shutdown();
  },

  port: {
    getBudgets: actualApi.getBudgets,
    getAccounts: actualApi.getAccounts,
    getCategories: actualApi.getCategories,
    getCategoryGroups: actualApi.getCategoryGroups,
    createCategoryGroup: actualApi.createCategoryGroup,
    createCategory: actualApi.createCategory,
    getPayees: actualApi.getPayees,
    getTransactions: actualApi.getTransactions,
    importTransactions: actualApi.importTransactions,
    addTransactions: actualApi.addTransactions,
    updateTransaction: actualApi.updateTransaction,
    createAccount: actualApi.createAccount,
    updateAccount: actualApi.updateAccount,
    closeAccount: actualApi.closeAccount,
    reopenAccount: actualApi.reopenAccount,
    createPayee: actualApi.createPayee,
    updatePayee: actualApi.updatePayee,
    setBudgetAmount: actualApi.setBudgetAmount,
    getBudgetMonth: actualApi.getBudgetMonth,
    getBudgetMonths: actualApi.getBudgetMonths,
    exportBudget: actualApi.exportBudget,
    ledger: ledgerReads,
  },
};
