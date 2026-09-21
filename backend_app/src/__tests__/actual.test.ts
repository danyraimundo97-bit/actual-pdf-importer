import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createBudgetSession } from '../budget-session';
import { assignImportedIds, importToActual, listAccounts, listBudgets, listCategoryGroups } from '../actual';
import { makeFakeAdapter, SERVER } from './fake-actual';

// These tests deliberately give every transaction an explicit categoryId:
// importToActual then never consults the SQLite category memory
// (categorydb.ts, covered by its own tests), so nothing here touches disk.

const tx = {
  date: '2026-03-01',
  payee: 'CONTINENTE',
  amountCents: -1234,
  rawLine: '01/03/2026 CONTINENTE -12,34',
};

test('importToActual imports into the requested budget and maps the payload', async () => {
  const calls: Array<{ accountId: string; payload: unknown[]; loaded: string | null }> = [];
  const fake = makeFakeAdapter({
    importTransactions: (async (accountId: string, payload: unknown[]) => {
      calls.push({ accountId, payload, loaded: fake.state.loaded });
      return { added: ['x'], updated: [] };
    }),
  });
  const session = createBudgetSession(SERVER, fake.adapter);

  const result = await importToActual(session, { syncId: 'budget-A' }, 'acc-1', [
    { ...tx, categoryId: 'cat-1', importedId: 'pdfimport-original' },
    { ...tx, payee: 'OTHER', categoryId: 'cat-2' }, // no importedId: derived
  ]);

  assert.deepEqual(result, { added: 1, updated: 0, categorized: 2 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].accountId, 'acc-1');
  assert.equal(calls[0].loaded, 'budget-A'); // ran with the right budget loaded
  assert.deepEqual(calls[0].payload, [
    {
      date: '2026-03-01',
      amount: -1234,
      payee_name: 'CONTINENTE',
      category: 'cat-1',
      imported_id: 'pdfimport-original', // a round-tripped id is never re-derived
      notes: tx.rawLine,
    },
    {
      date: '2026-03-01',
      amount: -1234,
      payee_name: 'OTHER',
      category: 'cat-2',
      imported_id: 'pdfimport--1836610009', // golden: 2026-03-01|-1234|OTHER
      notes: tx.rawLine,
    },
  ]);
});

test('listCategoryGroups drops hidden groups and hidden categories', async () => {
  const { adapter } = makeFakeAdapter({
    getCategoryGroups: (async () => [
      { id: 'g1', name: 'Bills', hidden: false, categories: [{ id: 'c1', hidden: false }, { id: 'c2', hidden: true }] },
      { id: 'g2', name: 'Old', hidden: true, categories: [{ id: 'c3', hidden: false }] },
    ]),
  });
  const session = createBudgetSession(SERVER, adapter);

  const groups = await listCategoryGroups(session, { syncId: 'budget-A' });

  assert.deepEqual(
    groups.map((g) => [g.id, g.categories.map((c) => c.id)]),
    [['g1', ['c1']]],
  );
});

test('listAccounts runs with the requested budget loaded', async () => {
  const fake = makeFakeAdapter({
    getAccounts: (async () => [{ id: 'acc-1', loaded: fake.state.loaded }]),
  });
  const session = createBudgetSession(SERVER, fake.adapter);

  const accounts = await listAccounts(session, { syncId: 'budget-B' });

  assert.deepEqual(accounts, [{ id: 'acc-1', loaded: 'budget-B' }]);
});

test('listBudgets maps the SDK shape and downloads no budget', async () => {
  const { adapter, state } = makeFakeAdapter({
    getBudgets: (async () => [{ cloudFileId: 'sync-1', name: 'Home', hasKey: true }]),
  });
  const session = createBudgetSession(SERVER, adapter);

  assert.deepEqual(await listBudgets(session), [{ syncId: 'sync-1', name: 'Home', encrypted: true }]);
  assert.deepEqual(state.downloads, []);
});

// A real moey! statement had three identical "+10,00 from <truncated payee>"
// movements on one day: banks truncate the payee column, so distinct
// references collapse onto the same date+amount+payee basis. Every one of
// them is a separate movement that must reach Actual.
const REPEATED = [
  { date: '2026-07-13', payee: 'JOANA EXEMPL', amountCents: 1000, rawLine: 'ref-1 10,00' },
  { date: '2026-07-13', payee: 'JOANA EXEMPL', amountCents: 1000, rawLine: 'ref-2 10,00' },
  { date: '2026-07-13', payee: 'JOANA EXEMPL', amountCents: 1000, rawLine: 'ref-3 10,00' },
];

test('assignImportedIds gives repeats of one basis distinct ids', () => {
  const ids = assignImportedIds(REPEATED).map((t) => t.importedId);

  assert.equal(new Set(ids).size, 3, 'each repeat needs its own id or Actual swallows it');
});

// These are the ids the pre-occurrence implementation produced, captured
// from it directly. They are the backward-compatibility contract: if a
// change to basisOf() or the hash moves them, every statement already
// imported stops deduping and lands again as duplicates. Pinning literals
// (not a call back into the module) is the whole point — recomputing would
// move with the implementation and assert nothing.
const GOLDEN_FIRST = 'pdfimport-747927590'; //         2026-07-13|1000|JOANA EXEMPL
const GOLDEN_SECOND = 'pdfimport--779377660'; //       2026-07-13|1000|JOANA EXEMPL|#1

test('the first id of a basis is unchanged from before occurrence numbering', () => {
  const ids = assignImportedIds(REPEATED).map((t) => t.importedId);

  assert.equal(ids[0], GOLDEN_FIRST);
  assert.equal(ids[1], GOLDEN_SECOND);
});

test('assignImportedIds is stable across re-parses and independent of unrelated rows', () => {
  const first = assignImportedIds(REPEATED).map((t) => t.importedId);

  assert.deepEqual(assignImportedIds(REPEATED).map((t) => t.importedId), first);
  // Interleaving other movements must not renumber the repeats: the counter
  // is per-basis, not a position in the list.
  const interleaved = assignImportedIds([
    { ...tx },
    REPEATED[0],
    { ...tx, payee: 'OTHER' },
    REPEATED[1],
    REPEATED[2],
  ]);
  assert.deepEqual(interleaved.filter((t) => t.payee === 'JOANA EXEMPL').map((t) => t.importedId), first);
});

test('assignImportedIds keeps a round-tripped id but still counts it as a repeat', () => {
  const stamped = assignImportedIds([
    { ...REPEATED[0], importedId: 'pdfimport-from-parse' },
    REPEATED[1],
  ]);

  assert.equal(stamped[0].importedId, 'pdfimport-from-parse');
  // Second row still numbered as occurrence 1 — the id /parse would issue.
  assert.equal(stamped[1].importedId, GOLDEN_SECOND);
});

test('importToActual sends a distinct imported_id per repeated movement', async () => {
  const calls: Array<{ payload: Array<{ imported_id: string }> }> = [];
  const { adapter } = makeFakeAdapter({
    importTransactions: async (_accountId: string, payload: Array<{ imported_id: string }>) => {
      calls.push({ payload });
      return { added: payload.map((_, i) => String(i)), updated: [] };
    },
  });
  const session = createBudgetSession(SERVER, adapter);

  await importToActual(
    session,
    { syncId: 'budget-A' },
    'acc-1',
    REPEATED.map((t) => ({ ...t, categoryId: 'cat-1' })),
  );

  assert.deepEqual(calls[0].payload.map((p) => p.imported_id), [GOLDEN_FIRST, GOLDEN_SECOND, 'pdfimport--779377659']);
});
