import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import type { BudgetRef, BudgetSession } from './budget-session';
import { REMOVED_NOTE_PREFIX } from './actual';
import { logger } from './logger';

const log = logger.child({ area: 'ledger' });

/**
 * GET /ledger/pull (docs/plans/local-ledger.md, Phase 5): the phone keeps a
 * copy of the budget and asks only for what changed since its cursor.
 *
 * Actual has no "changed since" call, so this reads Actual's own change log
 * (`messages_crdt`, through `LedgerPort`, see actual-adapter.ts). The cursor
 * is `{ epoch, lastId }`: `lastId` is the log's `id` (the order the backend
 * received changes, not the other device's clock), and `epoch` names one
 * life of the log. A cursor from another epoch gets everything (a full
 * pull), which at a personal budget's size costs about what opening it does.
 *
 * Accounts, categories and payees are small, so they always come whole; the
 * phone replaces its copy. Transactions and budget amounts come as changes
 * (tombstones included) unless the pull is full.
 */

/** Actual's change log, as far as the pull needs it. */
export interface ChangeLog {
  /** Entries after the requested id, oldest first. */
  entries: Array<{ id: number; dataset: string; row: string }>;
  /** The log's first entry; a different one means a new life of the log. */
  oldest: { id: number; timestamp: string } | null;
  maxId: number | null;
}

/** A transaction as Actual's query returns it (splits as separate rows). */
export interface RawLedgerTransaction {
  id: string;
  account: string;
  date: string; // YYYY-MM-DD
  amount: number;
  payee?: string | null;
  category?: string | null;
  notes?: string | null;
  cleared?: boolean | 0 | 1;
  imported_id?: string | null;
  starting_balance_flag?: boolean | 0 | 1;
  transfer_id?: string | null;
  parent_id?: string | null;
  is_parent?: boolean | 0 | 1;
  tombstone?: boolean | 0 | 1;
}

/** A row of `zero_budgets` (envelope) or `reflect_budgets` (tracking). */
export interface RawBudgetAmount {
  id: string;
  month: number; // YYYYMM
  category: string;
  amount: number;
  carryover?: number | boolean | null;
}

export type BudgetType = 'tracking' | 'envelope';

/**
 * The reads the pull needs beyond the public API. They touch Actual's
 * internals (its sqlite file), so they live in actual-adapter.ts only, and
 * `ledger.test.ts` pins the shapes they return.
 */
export interface LedgerPort {
  readChangeLog(afterId: number): Promise<ChangeLog>;
  /** By id with tombstones, or every live transaction when `ids` is absent. */
  readTransactions(ids?: string[]): Promise<RawLedgerTransaction[]>;
  /** The budget's mode: Actual's `budgetType` preference (unset = envelope). */
  readBudgetType(): Promise<BudgetType>;
  /** The mode's amounts table, every row or only `ids`. */
  readBudgetAmounts(type: BudgetType, ids?: string[]): Promise<RawBudgetAmount[]>;
}

export interface LedgerCursor {
  epoch?: string;
  lastId?: number;
}

export interface LedgerPull {
  epoch: string;
  lastId: number;
  /** True when this is everything (the phone drops what it had). */
  full: boolean;
  budgetType: BudgetType;
  accounts: Array<{ id: string; name: string; offbudget: boolean; closed: boolean }>;
  categoryGroups: Array<{
    id: string;
    name: string;
    isIncome: boolean;
    hidden: boolean;
    categories: Array<{ id: string; name: string; hidden: boolean }>;
  }>;
  payees: Array<{ id: string; name: string; transferAccountId: string | null }>;
  transactions: Array<{
    id: string;
    accountId: string;
    date: string;
    amountCents: number;
    payeeId: string | null;
    categoryId: string | null;
    notes: string | null;
    cleared: boolean;
    importedId: string | null;
    startingBalance: boolean;
    transferId: string | null;
    parentId: string | null;
    isParent: boolean;
    deleted: boolean;
  }>;
  budgets: Array<{ month: string; categoryId: string; budgetedCents: number; carryover: boolean }>;
}

// --- Epochs ------------------------------------------------------------------

interface EpochState {
  epoch: string;
  oldestId: number | null;
  oldestTimestamp: string | null;
}

/**
 * One epoch per budget, in `ledger-epochs.json` next to the category DB.
 * Replaced whenever the log can't be trusted to continue the old one.
 */
export class LedgerEpochs {
  constructor(private readonly file: string) {}

  private read(): Record<string, EpochState> {
    try {
      return JSON.parse(fs.readFileSync(this.file, 'utf8')) as Record<string, EpochState>;
    } catch {
      return {};
    }
  }

  private write(all: Record<string, EpochState>): void {
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = `${this.file}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(all), { mode: 0o600 });
    fs.renameSync(tmp, this.file);
  }

  /**
   * The budget's epoch for a log whose first entry is `oldest`. A new one
   * when there was none, or the first entry differs: a fresh cache or a
   * "Reset sync" starts the log again from id 1.
   */
  current(syncId: string, oldest: ChangeLog['oldest']): string {
    const all = this.read();
    const known = all[syncId];
    const same =
      known !== undefined &&
      known.oldestId === (oldest?.id ?? null) &&
      known.oldestTimestamp === (oldest?.timestamp ?? null);
    // An empty log that was empty before is the same life of it.
    if (same) return known.epoch;
    // The log grew from empty: still the same life.
    if (known !== undefined && known.oldestId === null && oldest !== null) {
      all[syncId] = { ...known, oldestId: oldest.id, oldestTimestamp: oldest.timestamp };
      this.write(all);
      return known.epoch;
    }
    const epoch = crypto.randomUUID();
    all[syncId] = { epoch, oldestId: oldest?.id ?? null, oldestTimestamp: oldest?.timestamp ?? null };
    this.write(all);
    log.info({ budgetSyncId: syncId }, 'Ledger change log started a new epoch');
    return epoch;
  }
}

export function defaultEpochsFile(): string {
  return path.join(path.dirname(process.env.CATEGORY_DB_PATH ?? './data/categories.db'), 'ledger-epochs.json');
}

// --- Shaping (pure) ----------------------------------------------------------

const truthy = (v: unknown) => v === true || v === 1;

/** Datasets whose rows the pull resends as changes. */
const TRANSACTION_DATASET = 'transactions';
const BUDGET_DATASETS = new Set(['zero_budgets', 'reflect_budgets']);

/** The changed transaction and budget-amount ids named by `entries`. */
export function changedIds(entries: ChangeLog['entries']): { transactions: string[]; budgets: string[] } {
  const transactions = new Set<string>();
  const budgets = new Set<string>();
  for (const e of entries) {
    if (e.dataset === TRANSACTION_DATASET) transactions.add(e.row);
    else if (BUDGET_DATASETS.has(e.dataset)) budgets.add(e.row);
  }
  return { transactions: [...transactions], budgets: [...budgets] };
}

/**
 * A transaction this app removed is kept in Actual at 0 with a note (the
 * soft delete, see /import/undo), so the phone treats it as removed too.
 */
const softDeleted = (t: RawLedgerTransaction) => (t.notes ?? '').startsWith(REMOVED_NOTE_PREFIX);

export function shapeTransaction(t: RawLedgerTransaction): LedgerPull['transactions'][number] {
  return {
    id: t.id,
    accountId: t.account,
    date: t.date,
    amountCents: Math.round(t.amount),
    payeeId: t.payee ?? null,
    categoryId: t.category ?? null,
    notes: t.notes ?? null,
    cleared: truthy(t.cleared),
    importedId: t.imported_id ?? null,
    startingBalance: truthy(t.starting_balance_flag),
    transferId: t.transfer_id ?? null,
    parentId: t.parent_id ?? null,
    isParent: truthy(t.is_parent),
    deleted: truthy(t.tombstone) || softDeleted(t),
  };
}

export function shapeBudgetAmount(b: RawBudgetAmount): LedgerPull['budgets'][number] {
  const month = String(b.month);
  return {
    month: `${month.slice(0, 4)}-${month.slice(4, 6)}`,
    categoryId: b.category,
    budgetedCents: Math.round(b.amount ?? 0),
    carryover: truthy(b.carryover),
  };
}

// --- The pull ----------------------------------------------------------------

export async function pullLedger(
  session: BudgetSession,
  budget: BudgetRef,
  cursor: LedgerCursor,
  epochs: LedgerEpochs,
): Promise<LedgerPull> {
  return session.withBudget(budget, async (port) => {
    const ledger = port.ledger;
    const changes = await ledger.readChangeLog(cursor.lastId ?? 0);
    const epoch = epochs.current(budget.syncId, changes.oldest);
    const maxId = changes.maxId ?? 0;
    // A cursor past the log's end means the log went backwards.
    const full = cursor.epoch !== epoch || cursor.lastId === undefined || cursor.lastId > maxId;

    const [accounts, groups, payees, budgetType] = await Promise.all([
      port.getAccounts(),
      port.getCategoryGroups(),
      port.getPayees(),
      ledger.readBudgetType(),
    ]);

    let transactions: RawLedgerTransaction[];
    let budgets: RawBudgetAmount[];
    if (full) {
      [transactions, budgets] = await Promise.all([
        ledger.readTransactions(),
        ledger.readBudgetAmounts(budgetType),
      ]);
    } else {
      const ids = changedIds(changes.entries);
      [transactions, budgets] = await Promise.all([
        ids.transactions.length === 0 ? Promise.resolve([]) : ledger.readTransactions(ids.transactions),
        ids.budgets.length === 0 ? Promise.resolve([]) : ledger.readBudgetAmounts(budgetType, ids.budgets),
      ]);
    }

    return {
      epoch,
      lastId: maxId,
      full,
      budgetType,
      accounts: accounts.map((a) => ({
        id: a.id,
        name: a.name,
        offbudget: truthy(a.offbudget),
        closed: truthy(a.closed),
      })),
      categoryGroups: groups.map((g) => ({
        id: g.id,
        name: g.name,
        isIncome: truthy(g.is_income),
        hidden: truthy(g.hidden),
        categories: (g.categories ?? []).map((c: { id: string; name: string; hidden?: boolean }) => ({
          id: c.id,
          name: c.name,
          hidden: truthy(c.hidden),
        })),
      })),
      payees: payees.map((p) => ({ id: p.id, name: p.name, transferAccountId: p.transfer_acct || null })),
      transactions: transactions.map(shapeTransaction),
      budgets: budgets.map(shapeBudgetAmount),
    };
  });
}
