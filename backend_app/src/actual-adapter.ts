import fs from 'fs';
import * as actualApi from '@actual-app/api';
import type { ActualAdapter } from './budget-session';
import { BudgetNotFoundError } from './errors';

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
    await actualApi.init({ serverURL, password, dataDir });
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

  shutdown: () => actualApi.shutdown(),

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
    getBudgetMonth: actualApi.getBudgetMonth,
    getBudgetMonths: actualApi.getBudgetMonths,
    exportBudget: actualApi.exportBudget,
  },
};
