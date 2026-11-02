import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBudgetSession } from '../budget-session';
import { makeFakeAdapter, SERVER, tick } from './fake-actual';

test('turns for different budgets never overlap, and each sees its own budget', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  let running = 0;
  let maxRunning = 0;
  const seen: Array<[string, string | null]> = [];

  const work = (syncId: string) =>
    session.withBudget({ syncId }, async () => {
      running++;
      maxRunning = Math.max(maxRunning, running);
      await tick(15); // long enough for the other request to arrive mid-work
      seen.push([syncId, state.loaded]);
      running--;
    });

  await Promise.all([work('A'), work('B'), work('A')]);

  assert.equal(maxRunning, 1);
  // Every callback ran with the budget it asked for still loaded.
  assert.deepEqual(seen, [
    ['A', 'A'],
    ['B', 'B'],
    ['A', 'A'],
  ]);
});

test('server init runs once and an already-loaded budget is not re-downloaded', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.withBudget({ syncId: 'A' }, async () => {});
  await session.withBudget({ syncId: 'A' }, async () => {});
  await session.withServer(async () => {});

  assert.equal(state.inits, 1);
  assert.deepEqual(state.downloads, ['A']);
});

// Regression: an account created in Actual's web app after the backend had
// downloaded the budget stayed invisible until the backend restarted.
test('reusing a loaded budget syncs it first; a fresh download needs no sync', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.withBudget({ syncId: 'A' }, async () => {
    assert.deepEqual(state.syncs, []); // just downloaded: already current
  });
  await session.withBudget({ syncId: 'A' }, async () => {
    assert.deepEqual(state.syncs, ['A']); // synced before fn runs
  });
  await session.withServer(async () => {});

  assert.deepEqual(state.syncs, ['A']); // withServer touches no budget
  assert.deepEqual(state.downloads, ['A']);
});

test('a failed sync fails the turn and forces a re-download next time', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.withBudget({ syncId: 'A' }, async () => {});
  state.failNextSync = true;
  await assert.rejects(session.withBudget({ syncId: 'A' }, async () => {}), /sync failed/);
  await session.withBudget({ syncId: 'A' }, async () => {});

  assert.deepEqual(state.downloads, ['A', 'A']);
});

test('withServer does not download any budget', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.withServer(async () => {});

  assert.equal(state.inits, 1);
  assert.deepEqual(state.downloads, []);
});

test('a failed download forces a re-download on the next turn', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.withBudget({ syncId: 'A' }, async () => {});

  state.failNextDownload = true;
  await assert.rejects(() => session.withBudget({ syncId: 'B' }, async () => {}), /download failed/);

  // The SDK may or may not still have A open; the session must not assume it does.
  await session.withBudget({ syncId: 'A' }, async () => {});
  assert.deepEqual(state.downloads, ['A', 'B', 'A']);
});

test('a callback that throws still frees the queue', async () => {
  const { adapter } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await assert.rejects(
    () =>
      session.withBudget({ syncId: 'A' }, async () => {
        throw new Error('boom');
      }),
    /boom/,
  );

  const result = await session.withBudget({ syncId: 'A' }, async () => 'next');
  assert.equal(result, 'next');
});

test('shutdown closes the connection; the next turn re-initializes and re-downloads', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  await session.shutdown(); // never started: a no-op
  assert.equal(state.shutdowns, 0);

  await session.withBudget({ syncId: 'A' }, async () => {});
  await session.shutdown();
  await session.withBudget({ syncId: 'A' }, async () => {});

  assert.equal(state.shutdowns, 1);
  assert.equal(state.inits, 2);
  assert.deepEqual(state.downloads, ['A', 'A']);
});

test('callbacks receive the adapter port', async () => {
  const { adapter } = makeFakeAdapter({});
  const session = createBudgetSession(SERVER, adapter);

  assert.equal(await session.withBudget({ syncId: 'A' }, async (port) => port), adapter.port);
  assert.equal(await session.withServer(async (port) => port), adapter.port);
});

test('shutdown waits for in-flight work instead of killing it', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);

  const order: string[] = [];
  let release!: () => void;
  const gate = new Promise<void>((resolve) => (release = resolve));

  const running = session.withBudget({ syncId: 'A' }, async () => {
    await gate;
    order.push('work done');
  });
  const stopping = session.shutdown().then(() => order.push('shutdown'));

  await tick(20);
  assert.equal(state.shutdowns, 0); // still blocked behind the running turn

  release();
  await Promise.all([running, stopping]);
  assert.deepEqual(order, ['work done', 'shutdown']);
  assert.equal(state.shutdowns, 1);
});

// --- Optional connection, reconfigure, sync throttling --------------------

test('with no server configured, every turn fails with ACTUAL_NOT_CONFIGURED and the SDK is never touched', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(null, adapter);

  assert.equal(session.isConfigured(), false);
  await assert.rejects(session.withBudget({ syncId: 'A' }, async () => {}), { code: 'ACTUAL_NOT_CONFIGURED' });
  await assert.rejects(session.withServer(async () => {}), { code: 'ACTUAL_NOT_CONFIGURED' });
  assert.equal(state.inits, 0);
  assert.deepEqual(state.downloads, []);
});

test('reconfigure waits for in-flight work, closes the connection and forgets the loaded budget', async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);
  await session.withBudget({ syncId: 'A' }, async () => {});

  let finished = false;
  const running = session.withBudget({ syncId: 'A' }, async () => {
    await tick(15);
    finished = true;
  });
  await session.reconfigure({ ...SERVER, serverURL: 'http://other' });
  assert.equal(finished, true, 'reconfigure ran only after the in-flight turn');
  await running;

  assert.equal(state.shutdowns, 1);
  await session.withBudget({ syncId: 'A' }, async () => {});
  assert.equal(state.inits, 2, 're-initialized against the new server');
  assert.deepEqual(state.downloads, ['A', 'A'], 're-downloaded: nothing counted as loaded');
});

test('reconfigure(null) disconnects; reconfiguring again reconnects without a restart', async () => {
  const { adapter } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);
  await session.withServer(async () => {});

  await session.reconfigure(null);
  assert.equal(session.isConfigured(), false);
  await assert.rejects(session.withServer(async () => {}), { code: 'ACTUAL_NOT_CONFIGURED' });

  await session.reconfigure(SERVER);
  assert.equal(session.isConfigured(), true);
  await session.withServer(async () => {});
});

test('reads within the sync interval reuse the local copy; after it they sync', async () => {
  const { adapter, state } = makeFakeAdapter();
  let clock = 1_000;
  const session = createBudgetSession(SERVER, adapter, { syncIntervalMs: 5_000, now: () => clock });

  await session.withBudget({ syncId: 'A' }, async () => {}); // download counts as fresh
  clock += 4_000;
  await session.withBudget({ syncId: 'A' }, async () => {});
  assert.deepEqual(state.syncs, [], 'within 5 s of the download: no sync');

  clock += 1_000;
  await session.withBudget({ syncId: 'A' }, async () => {});
  assert.deepEqual(state.syncs, ['A'], '5 s later: synced');

  clock += 1_000;
  await session.withBudget({ syncId: 'A' }, async () => {});
  assert.deepEqual(state.syncs, ['A'], 'the sync reset the interval');
});

test('a write turn always syncs before, and pushes after, even inside the interval', async () => {
  const { adapter, state } = makeFakeAdapter();
  const clock = 1_000;
  const session = createBudgetSession(SERVER, adapter, { syncIntervalMs: 60_000, now: () => clock });
  await session.withBudget({ syncId: 'A' }, async () => {});

  let syncsWhenWriting = -1;
  await session.withBudget(
    { syncId: 'A' },
    async () => {
      syncsWhenWriting = state.syncs.length;
    },
    { write: true },
  );
  assert.equal(syncsWhenWriting, 1, 'synced before the write');
  assert.equal(state.syncs.length, 2, 'and pushed after it');
});

test("a failed push after a write doesn't fail the write", async () => {
  const { adapter, state } = makeFakeAdapter();
  const session = createBudgetSession(SERVER, adapter);
  await session.withBudget({ syncId: 'A' }, async () => {});

  const result = await session.withBudget(
    { syncId: 'A' },
    async () => {
      state.failNextSync = true; // the sync before already ran; this hits the push after
      return 'written';
    },
    { write: true },
  );
  assert.equal(result, 'written');
});
