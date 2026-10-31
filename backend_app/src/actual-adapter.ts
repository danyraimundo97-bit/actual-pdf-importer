import fs from 'fs';
import * as actualApi from '@actual-app/api';
import type { ActualAdapter } from './budget-session';

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
    await actualApi.downloadBudget(syncId, budgetPassword ? { password: budgetPassword } : undefined);
  },

  shutdown: () => actualApi.shutdown(),

  port: {
    getBudgets: actualApi.getBudgets,
    getAccounts: actualApi.getAccounts,
    getCategories: actualApi.getCategories,
    getCategoryGroups: actualApi.getCategoryGroups,
    getPayees: actualApi.getPayees,
    getTransactions: actualApi.getTransactions,
    importTransactions: actualApi.importTransactions,
  },
};
