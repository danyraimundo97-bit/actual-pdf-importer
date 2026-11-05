import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { createBudgetSession } from '../budget-session';
import { LedgerClientIds, pushLedger } from '../ledger-push';
import type { RawLedgerTransaction } from '../ledger';
import { makeFakeAdapter, SERVER } from './fake-actual';

// docs/plans/local-ledger.md, Phase 5b: POST /ledger/push.

const BUDGET = { syncId: 'budget-1' };

function clientIds() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ledger-client-ids-'));
  return new LedgerClientIds(path.join(dir, 'ids.json'));
}

interface Row {
  id: string;
  account: string;
  date: string;
  amount: number;
  imported_id?: string | null;
  notes?: string | null;
  transfer_id?: string | null;
  is_parent?: boolean;
  tombstone?: boolean;
}

/** A tiny budget: enough of Actual for the push to run against. */
function fakeBudget(start: { rows?: Row[] } = {}) {
  const rows: Row[] = [...(start.rows ?? [])];
  const accounts = [{ id: 'chk', name: 'Checking', offbudget: false, closed: false }];
  const payees = [{ id: 'p-bakery', name: 'Bakery', transfer_acct: null as string | null }];
  const calls = {
    imports: [] as Array<{ account: string; lines: Array<Record<string, unknown>> }>,
    adds: [] as Array<Record<string, unknown>>,
    updates: [] as Array<{ id: string; fields: Record<string, unknown> }>,
    budgets: [] as Array<[string, string, number]>,
    created: [] as string[],
  };
  let next = 1;
  const fake = makeFakeAdapter({
    getAccounts: async () => accounts,
    getPayees: async () => payees,
    getTransactions: async (account: string) => rows.filter((r) => r.account === account),
    importTransactions: async (account: string, lines: Array<Record<string, unknown>>) => {
      calls.imports.push({ account, lines });
      for (const line of lines) {
        if (rows.some((r) => r.imported_id === line.imported_id)) continue;
        rows.push({
          id: `actual-${next++}`,
          account,
          date: line.date as string,
          amount: line.amount as number,
          imported_id: line.imported_id as string,
        });
      }
      return { added: [], updated: [], errors: [] };
    },
    addTransactions: async (account: string, lines: Array<Record<string, unknown>>) => {
      calls.adds.push(...lines);
      for (const line of lines) {
        rows.push({
          id: `actual-${next++}`,
          account,
          date: line.date as string,
          amount: line.amount as number,
          imported_id: line.imported_id as string,
        });
      }
      return 'ok';
    },
    updateTransaction: async (id: string, fields: Record<string, unknown>) => {
      calls.updates.push({ id, fields });
      const row = rows.find((r) => r.id === id);
      if (row && typeof fields.notes === 'string') row.notes = fields.notes;
      return [];
    },
    createAccount: async (account: { name: string; offbudget: boolean }) => {
      const id = `acct-${next++}`;
      calls.created.push(account.name);
      accounts.push({ id, name: account.name, offbudget: account.offbudget, closed: false });
      return id;
    },
    updateAccount: async () => undefined,
    closeAccount: async () => {
      throw new Error('balance is non-zero');
    },
    createPayee: async (payee: { name: string }) => {
      const id = `payee-${next++}`;
      calls.created.push(payee.name);
      payees.push({ id, name: payee.name, transfer_acct: null });
      return id;
    },
    setBudgetAmount: async (month: string, category: string, cents: number) => {
      calls.budgets.push([month, category, cents]);
    },
    ledger: {
      readTransactions: async (ids?: string[]) =>
        rows.filter((r) => ids?.includes(r.id)) as unknown as RawLedgerTransaction[],
    },
  });
  const session = createBudgetSession(SERVER, fake.adapter);
  return { session, rows, calls, fake };
}

const statementRow = (seq: number, importedId: string, fields = {}) => ({
  seq,
  kind: 'transaction',
  op: 'put',
  id: `tx:${seq}`,
  accountId: 'chk',
  date: '2026-10-03',
  amountCents: -500,
  payeeName: 'Bakery',
  importedId,
  ...fields,
});

test('a statement goes in one import, keeps its importedIds, and answers with Actual ids', async () => {
  const { session, calls } = fakeBudget();
  const push = await pushLedger(
    session,
    BUDGET,
    [statementRow(1, 'pdfimport-a'), statementRow(2, 'pdfimport-b')],
    clientIds(),
  );
  assert.equal(calls.imports.length, 1);
  assert.deepEqual(
    calls.imports[0].lines.map((l) => l.imported_id),
    ['pdfimport-a', 'pdfimport-b'],
  );
  assert.deepEqual(push.results, [
    { seq: 1, ok: true, id: 'actual-1' },
    { seq: 2, ok: true, id: 'actual-2' },
  ]);
});

test('a quick add sent twice is added once', async () => {
  const { session, calls } = fakeBudget();
  const entry = {
    seq: 1,
    kind: 'transaction',
    op: 'put',
    id: 'tx:abc',
    accountId: 'chk',
    date: '2026-10-03',
    amountCents: -450,
    payeeName: 'Bakery',
    categoryId: 'groceries',
    importedId: 'app-client-1',
  };
  const first = await pushLedger(session, BUDGET, [entry], clientIds());
  const second = await pushLedger(session, BUDGET, [entry], clientIds());
  assert.equal(calls.adds.length, 1);
  assert.deepEqual(first.results, second.results);
  assert.deepEqual(first.learned, [{ payee: 'Bakery', categoryId: 'groceries' }]);
  assert.deepEqual(second.learned, []);
});

test('a new account and its rows arrive in one push; a resend finds the same account', async () => {
  const { session, calls } = fakeBudget();
  const ids = clientIds();
  const entries = [
    { seq: 1, kind: 'account', op: 'put', id: 'acct:1', name: 'Cash', offBudget: false },
    {
      seq: 2,
      kind: 'transaction',
      op: 'put',
      id: 'tx:9',
      accountId: 'acct:1',
      date: '2026-10-01',
      amountCents: 10000,
      importedId: 'app-9',
      startingBalance: true,
      cleared: true,
    },
  ];
  const first = await pushLedger(session, BUDGET, entries, ids);
  assert.equal(first.results.length, 2);
  assert.ok(first.results.every((r) => r.ok));
  assert.equal(calls.adds[0].starting_balance_flag, true);

  const second = await pushLedger(session, BUDGET, entries, ids);
  assert.deepEqual(calls.created, ['Cash']);
  assert.deepEqual(first.results, second.results);
});

test('a new payee reuses the one the budget already has, whatever its case', async () => {
  const { session, calls } = fakeBudget();
  const push = await pushLedger(
    session,
    BUDGET,
    [
      { seq: 1, kind: 'payee', op: 'put', id: 'payee:1', name: ' bakery ' },
      { seq: 2, kind: 'payee', op: 'put', id: 'payee:2', name: 'Butcher' },
    ],
    clientIds(),
  );
  assert.deepEqual(push.results[0], { seq: 1, ok: true, id: 'p-bakery' });
  assert.deepEqual(calls.created, ['Butcher']);
});

test('one bad row does not stop the rest, and answers with a code', async () => {
  const { session, calls } = fakeBudget();
  const push = await pushLedger(
    session,
    BUDGET,
    [
      { seq: 1, kind: 'budget', op: 'put', categoryId: 'food', month: 'soon', budgetedCents: 100 },
      { seq: 2, kind: 'budget', op: 'put', categoryId: 'preset:food', month: '2026-10', budgetedCents: 100 },
      { seq: 3, kind: 'account', op: 'put', id: 'chk', name: 'Checking', closed: true },
      statementRow(4, 'pdfimport-a', { accountId: 'acct:unsent' }),
      { seq: 5, kind: 'budget', op: 'put', categoryId: 'food', month: '2026-10', budgetedCents: 30000 },
    ],
    clientIds(),
  );
  const codes = Object.fromEntries(push.results.map((r) => [r.seq, r.ok ? 'ok' : r.code]));
  assert.deepEqual(codes, {
    1: 'INVALID_FIELD',
    2: 'LOCAL_CATEGORY',
    3: 'ACTUAL_REJECTED',
    4: 'WAITING_FOR_ACCOUNT',
    5: 'ok',
  });
  assert.deepEqual(calls.budgets, [['2026-10', 'food', 30000]]);
});

test('an edit keeps the importedId; a row gone from Actual answers gone', async () => {
  const { session, calls } = fakeBudget({
    rows: [{ id: 'real', account: 'chk', date: '2026-10-01', amount: -100, imported_id: 'pdfimport-x' }],
  });
  const edit = (id: string, seq: number) => ({
    seq,
    kind: 'transaction',
    op: 'put',
    id,
    accountId: 'chk',
    date: '2026-10-02',
    amountCents: -200,
    payeeId: 'p-bakery',
    categoryId: 'food',
    notes: 'n',
    cleared: true,
    importedId: 'pdfimport-x',
  });
  const push = await pushLedger(session, BUDGET, [edit('real', 1), edit('missing', 2)], clientIds());
  assert.deepEqual(push.results, [
    { seq: 1, ok: true },
    { seq: 2, ok: true, gone: true },
  ]);
  assert.equal(calls.updates.length, 1);
  assert.equal('imported_id' in calls.updates[0].fields, false);
  assert.equal(calls.updates[0].fields.amount, -200);
});

test('a removal is a soft delete, once; transfers and splits stay as they are', async () => {
  const { session, calls } = fakeBudget({
    rows: [
      { id: 'real', account: 'chk', date: '2026-10-01', amount: -1250, notes: 'mine' },
      { id: 'moved', account: 'chk', date: '2026-10-01', amount: -100, transfer_id: 'other' },
      { id: 'split', account: 'chk', date: '2026-10-01', amount: -100, is_parent: true },
    ],
  });
  const remove = (id: string, seq: number) => ({ seq, kind: 'transaction', op: 'delete', id });
  const now = new Date('2026-11-05T10:00:00Z');
  const push = await pushLedger(
    session,
    BUDGET,
    [remove('real', 1), remove('moved', 2), remove('split', 3)],
    clientIds(),
    now,
  );
  assert.deepEqual(push.results, [
    { seq: 1, ok: true },
    { seq: 2, ok: false, code: 'READ_ONLY' },
    { seq: 3, ok: false, code: 'READ_ONLY' },
  ]);
  assert.equal(calls.updates[0].fields.amount, 0);
  assert.match(calls.updates[0].fields.notes as string, /^\[Removed via PDF importer on 2026-11-05, was -12\.50\] mine$/);
  assert.equal(push.softDeleted[0].originalAmountCents, -1250);
  assert.equal(push.softDeleted[0].importedId, '');

  const again = await pushLedger(session, BUDGET, [remove('real', 1)], clientIds(), now);
  assert.deepEqual(again.results, [{ seq: 1, ok: true, gone: true }]);
  assert.equal(again.softDeleted.length, 0);
  assert.equal(calls.updates.length, 1);
});
