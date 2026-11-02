import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tradeRepublicParser } from '../parsers/traderepublic';
import { fixtureText } from './fixtures';

// The statements themselves are shared fixtures (fixtures/parsers/traderepublic-*),
// checked movement by movement in parser-fixtures.test.ts:
// - traderepublic-basic: a date split over two lines, a wrapped type, no
//   sign anywhere (ENTRADA/SAÍDA are columns the text dump flattens), the
//   amount glued to the end of the description ("LOJA TESTE 410,00" is the
//   payee "LOJA TESTE 4" and 10,00), NBSP gaps, and a page footer mid-table.
//   Balances: 1000.00 +5.00 -10.00 +1145.00 -65.50 = 2074.50
// - traderepublic-no-opening: without SALDO INICIAL only the first movement
//   is lost; every later one follows from the balance it prints.
const STATEMENT = fixtureText('traderepublic-basic');

test('canParse recognises a Trade Republic statement', () => {
  assert.equal(tradeRepublicParser.canParse(STATEMENT), true);
  assert.equal(tradeRepublicParser.canParse('Banco ActivoBank, S.A.'), false);
});

test('canParse ignores another bank listing Trade Republic as a payee', () => {
  // A moey statement truncates the payee column, so it contains
  // "TRANSF SEPA -Trade Republic Ba". The old /trade\s*republic/i sniff
  // matched that and claimed the whole moey statement; it only routed
  // correctly because moey happens to come first in REGEX_PARSERS.
  assert.equal(
    tradeRepublicParser.canParse('07-07-2026 TRANSF SEPA -Trade Republic Ba 100,00 +102,90'),
    false,
  );
});

test('the movement total matches the summary block', async () => {
  // Direction is derived, never read, so the statement's own totals are the
  // only meaningful check: SALDO INICIAL + sum == SALDO FINAL, and the
  // in/out split matches ENTRADA/SAÍDA DE DINHEIRO.
  const txs = await tradeRepublicParser.parse(STATEMENT);
  const sum = txs.reduce((total, tx) => total + tx.amountCents, 0);
  const inflow = txs.filter((t) => t.amountCents > 0).reduce((a, t) => a + t.amountCents, 0);
  const outflow = txs.filter((t) => t.amountCents < 0).reduce((a, t) => a + t.amountCents, 0);

  assert.equal(100000 + sum, 207450);
  assert.equal(inflow, 115000);
  assert.equal(outflow, -7550);
});

test('the page footer does not swallow the movements after it', async () => {
  const txs = await tradeRepublicParser.parse(STATEMENT);
  assert.equal(txs.some((t) => t.date === '2026-08-10'), true);
  assert.equal(txs.some((t) => /berlin|traderepublic|gerado/i.test(t.payee)), false);
});
