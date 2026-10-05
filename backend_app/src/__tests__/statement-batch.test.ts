import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseStatements, summarize, UploadedStatement } from '../statement-batch';
import { PdfPasswordRequiredError, UnrecognizedBankError } from '../errors';
import { assignImportedIds } from '../actual';

const file = (name: string): UploadedStatement => ({
  originalname: name,
  buffer: Buffer.from(name),
});

/** A parseOne stub keyed on the file's name, standing in for processStatement. */
function fakeParser(
  behaviour: Record<string, 'ok' | 'empty' | Error>,
): (buffer: Buffer) => Promise<{ bankId: string; transactions: Array<{ payee: string }> }> {
  return async (buffer) => {
    const name = buffer.toString();
    const outcome = behaviour[name];
    if (outcome instanceof Error) throw outcome;
    return {
      bankId: 'moey',
      transactions: outcome === 'empty' ? [] : [{ payee: `PAYEE ${name}` }],
    };
  };
}

test('every file gets its own result and one failure does not lose the others', async () => {
  const results = await parseStatements(
    [file('a.pdf'), file('locked.pdf'), file('c.pdf')],
    fakeParser({
      'a.pdf': 'ok',
      'locked.pdf': new PdfPasswordRequiredError(),
      'c.pdf': 'ok',
    }),
  );

  assert.deepEqual(
    results.map((r) => [r.filename, r.status, r.status === 'failed' ? r.code : undefined]),
    [
      ['a.pdf', 'parsed', undefined],
      ['locked.pdf', 'failed', 'PDF_PASSWORD_REQUIRED'],
      ['c.pdf', 'parsed', undefined],
    ],
  );
});

test('a recognised statement with zero transactions fails as NO_TRANSACTIONS, keeping its bankId', async () => {
  const [result] = await parseStatements([file('empty.pdf')], fakeParser({ 'empty.pdf': 'empty' }));
  assert.equal(result.status, 'failed');
  if (result.status !== 'failed') return;
  assert.equal(result.code, 'NO_TRANSACTIONS');
  assert.equal(result.bankId, 'moey');
});

test('an unexpected error is reported without leaking its message', async () => {
  const results = await parseStatements(
    [file('boom.pdf')],
    fakeParser({ 'boom.pdf': new Error('ENOENT /secret/path/token.db') }),
  );
  const [result] = results;
  assert.equal(result.status, 'failed');
  if (result.status !== 'failed') return;
  assert.equal(result.code, 'INTERNAL_ERROR');
  assert.equal(result.error, 'Internal error while parsing the statement.');
  assert.equal(/secret/.test(result.error), false);
});

test('a typed ImporterError keeps its own code and message', async () => {
  const [result] = await parseStatements([file('x.pdf')], fakeParser({ 'x.pdf': new UnrecognizedBankError() }));
  assert.equal(result.status, 'failed');
  if (result.status !== 'failed') return;
  assert.equal(result.code, 'BANK_UNRECOGNIZED');
  assert.equal(result.error, 'Could not identify which bank this statement is from.');
});

test('files are parsed in order, one at a time', async () => {
  // Sequential on purpose: in PARSER_MODE=ai each file is a provider call.
  const started: string[] = [];
  let inFlight = 0;
  const results = await parseStatements([file('1'), file('2'), file('3')], async (buffer) => {
    inFlight++;
    assert.equal(inFlight, 1, 'two files were parsed concurrently');
    started.push(buffer.toString());
    await new Promise((resolve) => setTimeout(resolve, 1));
    inFlight--;
    return { bankId: 'moey', transactions: [{ payee: 'X' }] };
  });

  assert.deepEqual(started, ['1', '2', '3']);
  assert.deepEqual(results.map((r) => r.filename), ['1', '2', '3']);
});

test('summarize counts files and transactions', async () => {
  const results = await parseStatements(
    [file('a.pdf'), file('b.pdf'), file('bad.pdf')],
    fakeParser({ 'a.pdf': 'ok', 'b.pdf': 'ok', 'bad.pdf': new UnrecognizedBankError() }),
  );
  assert.deepEqual(summarize(results), { parsed: 2, failed: 1, transactions: 2 });
});

test('dedupe ids must be stamped per statement, not across the batch', async () => {
  // The trap this whole design exists to avoid. Two overlapping exports (a
  // June and a July statement both listing the 01-07 movement, which banks
  // do at month boundaries) must give that movement the SAME id, so Actual
  // dedupes it. Numbering occurrences across the batch instead makes the
  // second copy occurrence 1 — a different id, and a silent duplicate.
  const june = [
    { date: '2026-06-30', amountCents: -100, payee: 'LOJA' },
    { date: '2026-07-01', amountCents: -250, payee: 'MERCADO' },
  ];
  const july = [
    { date: '2026-07-01', amountCents: -250, payee: 'MERCADO' },
    { date: '2026-07-02', amountCents: -900, payee: 'CAFE' },
  ];

  const results = await parseStatements([file('june'), file('july')], async (buffer) => ({
    bankId: 'moey',
    // Exactly what parseAndEnrich does: stamp this statement on its own.
    transactions: assignImportedIds(buffer.toString() === 'june' ? june : july),
  }));

  const ids = results.flatMap((r) => (r.status === 'parsed' ? r.transactions.map((t) => t.importedId) : []));
  assert.equal(ids[1], ids[2], 'the shared movement must carry one id across both statements');
  assert.notEqual(ids[1], assignImportedIds([...june, ...july])[2].importedId);
});
