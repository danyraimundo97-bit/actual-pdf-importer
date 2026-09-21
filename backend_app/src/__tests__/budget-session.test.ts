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
