import { ActualAdapter, ActualPort } from '../budget-session';

/**
 * Test doubles for the port. Deliberately looser than ActualPort: matching
 * the SDK's overloaded signatures exactly would make every stub need its
 * own cast, and `as never` at a call site switches off the argument
 * checking the stub most needs. The one cast lives below, where this is
 * handed to ActualAdapter.
 */
type FakePort = Partial<Record<keyof ActualPort, (...args: never[]) => Promise<unknown>>>;

export const SERVER = { serverURL: 'http://fake', password: '', dataDir: './fake' };
export const tick = (ms = 5) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * In-memory stand-in for @actual-app/api: tracks which budget is "loaded"
 * so tests can assert on the concurrency invariant directly.
 *
 * `port` only needs the methods a given test calls; anything else throws
 * "is not a function", which is the failure we want if code reaches for a
 * method the test didn't expect.
 */
export function makeFakeAdapter(port: FakePort = {}) {
  const state = {
    inits: 0,
    downloads: [] as string[],
    shutdowns: 0,
    loaded: null as string | null,
    failNextDownload: false,
  };

  const adapter: ActualAdapter = {
    async init() {
      state.inits++;
    },
    async downloadBudget({ syncId }) {
      await tick();
      state.downloads.push(syncId);
      if (state.failNextDownload) {
        state.failNextDownload = false;
        throw new Error('download failed');
      }
      state.loaded = syncId;
    },
    async shutdown() {
      state.shutdowns++;
      state.loaded = null;
    },
    port: port as unknown as ActualPort, // the one cast: see FakePort above
  };

  return { adapter, state };
}
