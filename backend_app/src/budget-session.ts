import type * as actualApi from '@actual-app/api';

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
  | 'getPayees'
  | 'getTransactions'
  | 'importTransactions'
>;

/**
 * The seam: the session owns the connection lifecycle, the adapter knows
 * how to drive one particular Actual client. Production uses
 * actual-adapter.ts; tests use an in-memory fake.
 */
export interface ActualAdapter {
  init(config: ServerConfig): Promise<void>;
  downloadBudget(budget: BudgetRef): Promise<void>;
  shutdown(): Promise<void>;
  readonly port: ActualPort;
}

export interface BudgetSession {
  /** Runs `fn` with `budget` loaded, exclusively. */
  withBudget<T>(budget: BudgetRef, fn: (port: ActualPort) => Promise<T>): Promise<T>;
  /** Runs `fn` with only the server connection open (no budget download). */
  withServer<T>(fn: (port: ActualPort) => Promise<T>): Promise<T>;
  shutdown(): Promise<void>;
}

export function createBudgetSession(serverConfig: ServerConfig, adapter: ActualAdapter): BudgetSession {
  let serverReady = false;
  let loadedSyncId: string | null = null;
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

  /** One turn: server connection open, `budget` loaded if given, then `fn`. */
  function run<T>(budget: BudgetRef | undefined, fn: (port: ActualPort) => Promise<T>): Promise<T> {
    return turn(async () => {
      if (!serverReady) {
        await adapter.init(serverConfig);
        serverReady = true;
      }
      if (budget && loadedSyncId !== budget.syncId) {
        // If the download fails we can't tell which budget the SDK still
        // has open, so claim none: the next turn always re-downloads.
        loadedSyncId = null;
        await adapter.downloadBudget(budget);
        loadedSyncId = budget.syncId;
      }
      return fn(adapter.port);
    });
  }

  return {
    withServer: (fn) => run(undefined, fn),
    withBudget: run,

    /** Queued like any turn, so it never kills a running import halfway. */
    shutdown() {
      return turn(async () => {
        if (!serverReady) return;
        try {
          await adapter.shutdown();
        } finally {
          serverReady = false;
          loadedSyncId = null;
        }
      });
    },
  };
}
