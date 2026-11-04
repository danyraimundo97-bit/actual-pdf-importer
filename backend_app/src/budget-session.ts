import type * as actualApi from '@actual-app/api';
import type { Logger } from 'pino';
import { ActualNotConfiguredError } from './errors';
import { logger } from './logger';

/**
 * The backend's exclusive hold on Actual Budget (see CONTEXT.md, "Budget
 * session").
 *
 * @actual-app/api is one global connection with one downloaded budget at a
 * time. Every piece of Actual work therefore runs as a *turn*: the session
 * makes sure the right budget is loaded, runs the caller's callback, and
 * only then lets the next turn start. Because the whole callback sits
 * inside the turn (not just the budget download), a request for another
 * budget can never swap the budget out from under an import that is
 * halfway done.
 *
 * Do not call withBudget()/withServer() from inside a callback — turns are
 * serialized, so the nested call would wait for its own parent forever.
 *
 * The Actual connection is optional: a session can be created with no
 * server config (every turn then fails with ACTUAL_NOT_CONFIGURED before
 * touching the SDK) and be pointed at a server later with reconfigure().
 */

export interface ServerConfig {
  serverURL: string;
  password: string;
  dataDir: string; // local cache dir @actual-app/api needs for its sync file
}

export interface BudgetRef {
  /** The budget's sync id, found in Actual's advanced settings. */
  syncId: string;
  /**
   * Password for this budget file's end-to-end encryption, if it has any
   * (see GET /budgets' `encrypted` flag). Unrelated to a bank statement
   * PDF's password.
   */
  budgetPassword?: string;
}

/** The slice of @actual-app/api that domain code is allowed to call. */
export type ActualPort = Pick<
  typeof actualApi,
  | 'getBudgets'
  | 'getAccounts'
  | 'getCategories'
  | 'getCategoryGroups'
  | 'createCategoryGroup'
  | 'createCategory'
  | 'getPayees'
  | 'getTransactions'
  | 'importTransactions'
  | 'addTransactions'
  | 'updateTransaction'
  | 'getBudgetMonth'
  | 'getBudgetMonths'
  | 'exportBudget'
>;

/**
 * The seam: the session owns the connection lifecycle, the adapter knows
 * how to drive one particular Actual client. Production uses
 * actual-adapter.ts; tests use an in-memory fake.
 */
export interface ActualAdapter {
  init(config: ServerConfig): Promise<void>;
  downloadBudget(budget: BudgetRef): Promise<void>;
  /** Pulls changes made elsewhere (web app, phone) into the loaded budget. */
  sync(): Promise<void>;
  shutdown(): Promise<void>;
  readonly port: ActualPort;
}

export interface TurnOptions {
  /**
   * The turn changes the budget. Write turns skip the sync throttle (they
   * always start from the server's latest state, so dedupe sees everything)
   * and push the change to the server as soon as the callback is done.
   */
  write?: boolean;
}

export interface BudgetSession {
  /** Runs `fn` with `budget` loaded, exclusively. */
  withBudget<T>(budget: BudgetRef, fn: (port: ActualPort) => Promise<T>, options?: TurnOptions): Promise<T>;
  /** Runs `fn` with only the server connection open (no budget download). */
  withServer<T>(fn: (port: ActualPort) => Promise<T>): Promise<T>;
  /**
   * Points the session at another server, or at none (`null`). Queued like
   * a turn, so in-flight work finishes first; the old connection is closed
   * and no budget counts as loaded afterwards.
   */
  reconfigure(config: ServerConfig | null): Promise<void>;
  /** Whether a server is configured (it may still be unreachable). */
  isConfigured(): boolean;
  shutdown(): Promise<void>;
}

export interface SessionOptions {
  log?: Logger;
  /**
   * A loaded budget is synced with the server at most this often (ms);
   * read turns in between use the local copy as it is. 0 = before every
   * turn. Write turns always sync.
   */
  syncIntervalMs?: number;
  now?: () => number;
}

export function createBudgetSession(
  initialConfig: ServerConfig | null,
  adapter: ActualAdapter,
  options: SessionOptions = {},
): BudgetSession {
  const log = options.log ?? logger.child({ area: 'session' });
  const syncIntervalMs = options.syncIntervalMs ?? 0;
  const now = options.now ?? Date.now;

  let config = initialConfig;
  let serverReady = false;
  let loadedSyncId: string | null = null;
  let lastSyncAt = -Infinity;
  let tail: Promise<void> = Promise.resolve();

  function turn<T>(work: () => Promise<T>): Promise<T> {
    const run = tail.then(work);
    // A failed turn must not poison the queue: the next request gets a
    // fresh turn instead of inheriting a rejected chain.
    tail = run.then(
      () => {},
      () => {},
    );
    return run;
  }

  async function closeConnection(): Promise<void> {
    if (!serverReady) return;
    try {
      await adapter.shutdown();
      log.info('Closed the Actual connection');
    } finally {
      serverReady = false;
      loadedSyncId = null;
      lastSyncAt = -Infinity;
    }
  }

  async function syncLoaded(budgetSyncId: string): Promise<void> {
    try {
      await adapter.sync();
      lastSyncAt = now();
    } catch (err) {
      // A failed sync leaves the copy's state unknown: re-download next time.
      loadedSyncId = null;
      log.error({ budgetSyncId, err }, 'Sync with Actual failed');
      throw err;
    }
  }

  /** One turn: server connection open, `budget` loaded if given, then `fn`. */
  function run<T>(budget: BudgetRef | undefined, fn: (port: ActualPort) => Promise<T>, opts: TurnOptions = {}): Promise<T> {
    const queuedAt = now();
    return turn(async () => {
      if (!config) throw new ActualNotConfiguredError();
      const startedAt = now();
      const budgetSyncId = budget?.syncId;
      let action: 'none' | 'download' | 'sync' | 'cached' = 'none';
      if (!serverReady) {
        await adapter.init(config);
        serverReady = true;
        log.info('Connected to the Actual server');
      }
      if (budget && loadedSyncId !== budget.syncId) {
        // If the download fails we can't tell which budget the SDK still
        // has open, so claim none: the next turn always re-downloads.
        action = 'download';
        loadedSyncId = null;
        await adapter.downloadBudget(budget);
        loadedSyncId = budget.syncId;
        lastSyncAt = now();
        log.info({ budgetSyncId, ms: now() - startedAt }, 'Budget downloaded');
      } else if (budget) {
        // Already loaded, but possibly from long ago: without a sync,
        // accounts or transactions added in Actual since then stay invisible
        // and import dedupe checks against stale data. Reads within
        // syncIntervalMs of the last sync reuse the local copy.
        if (opts.write || now() - lastSyncAt >= syncIntervalMs) {
          action = 'sync';
          await syncLoaded(budget.syncId);
        } else {
          action = 'cached';
        }
      }
      const prepMs = now() - startedAt;
      try {
        const result = await fn(adapter.port);
        if (budget && opts.write) {
          // Push the change now rather than waiting for the next turn. The
          // change is already in the local copy, so a failure here is not
          // the write failing: the next sync retries it.
          await syncLoaded(budget.syncId).catch(() => undefined);
        }
        return result;
      } finally {
        log.debug(
          { budgetSyncId, action, write: Boolean(opts.write), waitMs: startedAt - queuedAt, prepMs, runMs: now() - startedAt - prepMs },
          'Turn finished',
        );
      }
    });
  }

  return {
    withServer: (fn) => run(undefined, fn),
    withBudget: (budget, fn, opts) => run(budget, fn, opts),
    isConfigured: () => config !== null,

    reconfigure(next) {
      return turn(async () => {
        await closeConnection();
        config = next;
        log.info({ configured: next !== null }, next ? 'Actual server changed' : 'Actual server removed');
      });
    },

    /** Queued like any turn, so it never kills a running import halfway. */
    shutdown() {
      return turn(closeConnection);
    },
  };
}
