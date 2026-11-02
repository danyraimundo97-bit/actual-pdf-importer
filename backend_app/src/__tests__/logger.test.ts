import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { AddressInfo } from 'net';
import express from 'express';
import { createLogger, readRecentLogLines, redactFields, REDACTED } from '../logger';
import { requestLogger, REQUEST_ID_HEADER } from '../request-log';

/** A logger writing into an array of parsed JSON lines. */
function captured(debug: boolean) {
  const lines: Array<Record<string, unknown>> = [];
  const stream = { write: (s: string) => void lines.push(JSON.parse(s)) };
  const log = createLogger({ debug, streams: [{ level: 'debug', stream }] });
  return { log, lines };
}

test('secrets are replaced at every level, even with debug on', () => {
  const out = redactFields(
    { token: 'abc', 'x-import-token': 'abc', budgetPassword: 'p', ANTHROPIC_API_KEY: 'k', apiKey: 'k', req: 'r1' },
    true,
  );
  assert.deepEqual(out, {
    token: REDACTED,
    'x-import-token': REDACTED,
    budgetPassword: REDACTED,
    ANTHROPIC_API_KEY: REDACTED,
    apiKey: REDACTED,
    req: 'r1',
  });
});

test('amounts, balances and raw statement text are dropped at every level', () => {
  for (const debug of [false, true]) {
    const out = redactFields(
      { amount: -4.5, amountCents: -450, balance: 10, netWorthCents: 5, rawLine: 'x 2,60', block: 'x', importedId: 'pdfimport-1' },
      debug,
    );
    assert.deepEqual(out, { importedId: 'pdfimport-1' }, `debug=${debug}`);
  }
});

test('payees only with debug; ids and dates always; nested objects cleaned', () => {
  const fields = { payee: 'CONTINENTE', payeeKey: 'continente', date: '2026-07-01', categoryId: 'c1' };
  assert.deepEqual(redactFields(fields, false), { date: '2026-07-01', categoryId: 'c1' });
  assert.deepEqual(redactFields(fields, true), fields);
  assert.deepEqual(redactFields({ q: { password: 'p', amountCents: 1, id: 'x' } }, false), {
    q: { password: REDACTED, id: 'x' },
  });
});

test('debug lines are written only with the flag; info/warn/error always', () => {
  const off = captured(false);
  off.log.debug('detail');
  off.log.info('happened');
  off.log.warn('odd');
  off.log.error('bug');
  assert.deepEqual(off.lines.map((l) => l.level), [30, 40, 50]);

  const on = captured(true);
  on.log.debug({ payee: 'LIDL' }, 'detail');
  assert.equal(on.lines.length, 1);
  assert.equal(on.lines[0].payee, 'LIDL');
});

test('a payee and an amount logged at warn are stripped without the debug flag', () => {
  const { log, lines } = captured(false);
  log.child({ area: 'parser' }).warn({ payee: 'LIDL', amountCents: -450, date: '2026-07-01' }, 'skipped');
  assert.equal(lines[0].payee, undefined);
  assert.equal(lines[0].amountCents, undefined);
  assert.equal(lines[0].date, '2026-07-01');
  assert.equal(lines[0].area, 'parser');
});

test('errors keep their message and stack', () => {
  const { log, lines } = captured(false);
  log.error({ err: new Error('boom') }, 'failed');
  const err = lines[0].err as { message: string; stack: string };
  assert.equal(err.message, 'boom');
  assert.match(err.stack, /boom/);
});

test('requestLogger: echoes or creates a request id, logs the route pattern, never the token or query', async () => {
  const { log, lines } = captured(false);
  const app = express();
  app.use(requestLogger(log));
  app.delete('/categories/:payee', (_req, res) => res.json({ ok: true }));
  const server = app.listen(0);
  try {
    const { port } = server.address() as AddressInfo;
    const base = `http://127.0.0.1:${port}`;

    const res = await fetch(`${base}/categories/PINGO%20DOCE?budgetSyncId=b1`, {
      method: 'DELETE',
      headers: { [REQUEST_ID_HEADER]: 'abc123', 'X-Import-Token': 'super-secret' },
    });
    assert.equal(res.headers.get(REQUEST_ID_HEADER), 'abc123');

    const generated = await fetch(`${base}/nope`, { headers: { [REQUEST_ID_HEADER]: 'bad id with spaces' } });
    assert.match(generated.headers.get(REQUEST_ID_HEADER) ?? '', /^[0-9a-f]{16}$/);

    await new Promise((r) => setTimeout(r, 20)); // 'finish' fires after the body is sent
    const text = JSON.stringify(lines);
    assert.equal(lines[0].req, 'abc123');
    assert.equal(lines[0].path, '/categories/:payee');
    assert.equal(lines[0].status, 200);
    assert.equal(lines[1].status, 404);
    assert.ok(!text.includes('PINGO'), 'a payee in the URL must not reach an info line');
    assert.ok(!text.includes('super-secret'));
    assert.ok(!text.includes('budgetSyncId=b1'));
  } finally {
    server.close();
  }
});

test('readRecentLogLines: newest last across rotated files, tail and level filter', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'logs-'));
  try {
    const line = (level: number, msg: string) => JSON.stringify({ level, msg });
    const older = path.join(dir, 'backend.2026-11-01.1.log');
    const newer = path.join(dir, 'backend.2026-11-02.1.log');
    fs.writeFileSync(older, [line(30, 'a'), line(20, 'b')].join('\n') + '\n');
    fs.writeFileSync(newer, [line(40, 'c'), line(30, 'd')].join('\n') + '\n');
    fs.writeFileSync(path.join(dir, 'unrelated.txt'), 'x');
    fs.utimesSync(older, new Date('2026-11-01'), new Date('2026-11-01'));
    fs.utimesSync(newer, new Date('2026-11-02'), new Date('2026-11-02'));

    const msgs = (lines: string[]) => lines.map((l) => JSON.parse(l).msg);
    assert.deepEqual(msgs(readRecentLogLines(dir, 10)), ['a', 'b', 'c', 'd']);
    assert.deepEqual(msgs(readRecentLogLines(dir, 3)), ['b', 'c', 'd']);
    assert.deepEqual(msgs(readRecentLogLines(dir, 10, 'info')), ['a', 'c', 'd']);
    assert.deepEqual(readRecentLogLines(path.join(dir, 'missing'), 10), []);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
