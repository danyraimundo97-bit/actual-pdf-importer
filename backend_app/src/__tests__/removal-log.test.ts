import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';

// removal-log.ts reads its path once at module load, so set it before the
// dynamic import (same reason as categorydb.test.ts).
test('the removal log keeps the first, real original of each transaction', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'removal-log-test-'));
  process.env.REMOVAL_LOG_PATH = path.join(dir, 'removed.db');

  const log = await import('../removal-log');
  const base = {
    budgetSyncId: 'budget-A',
    accountId: 'acc-1',
    importedId: 'pdfimport-1',
    date: '2026-03-01',
  };

  log.recordRemovals([
    { ...base, transactionId: 't1', payee: 'CONTINENTE', originalAmountCents: -1234, originalNotes: 'raw', removedAt: '2026-10-31T10:00:00Z' },
  ]);
  // A second record of t1 would only know the zeroed amount: it must not win.
  log.recordRemovals([{ ...base, transactionId: 't1', originalAmountCents: 0, removedAt: '2026-10-31T11:00:00Z' }]);
  log.recordRemovals([{ ...base, transactionId: 't2', budgetSyncId: 'budget-B', originalAmountCents: -1, removedAt: '2026-10-31T12:00:00Z' }]);

  assert.deepEqual(log.listRemovals('budget-A'), [
    { ...base, transactionId: 't1', payee: 'CONTINENTE', originalAmountCents: -1234, originalNotes: 'raw', removedAt: '2026-10-31T10:00:00Z' },
  ]);
  assert.equal(log.listRemovals('budget-B').length, 1);

  log.closeRemovalLog();
  fs.rmSync(dir, { recursive: true, force: true });
});
