import { test } from 'node:test';
import assert from 'node:assert/strict';
import { activoBankParser } from '../parsers/activobank';
import { fixtureText } from './fixtures';

// The statements themselves are shared fixtures (fixtures/parsers/activobank-*),
// checked movement by movement in parser-fixtures.test.ts:
// - activobank-basic: three-line movements, a date with no year, "."
//   decimals with SPACE thousands, amount glued to the running balance with
//   no sign. Balances: 500.00 -25.50 -10.00 -64.50 +1200.00 -100.00 -500.00 = 1000.00
// - activobank-year-rollover: dates are MONTH.DAY; a month before the
//   period's first month belongs to the next year.
// - activobank-unresolvable: "5.0090.00" splits into two amounts but neither
//   direction reconciles against 100.00. The row is dropped and the balance
//   resyncs, so later rows survive.
// - activobank-no-period: no period header yields nothing rather than a
//   guessed year.
const STATEMENT = fixtureText('activobank-basic');

test('canParse recognises an ActivoBank statement', () => {
  assert.equal(activoBankParser.canParse(STATEMENT), true);
  assert.equal(activoBankParser.canParse('moey é uma marca do Grupo Crédito Agrícola'), false);
});

test('canParse ignores a statement that merely mentions ActivoBank', () => {
  // Another bank's statement listing an ActivoBank transfer as the payee.
  // The old substring sniff claimed it, and because activobank is first in
  // REGEX_PARSERS that hijacked the statement from its real parser.
  assert.equal(
    activoBankParser.canParse('01-07-2026 Trf imediata ACTIVOBANK 10,00 -10,00'),
    false,
  );
});

test('the movement total matches SALDO FINAL minus SALDO INICIAL', async () => {
  // The statement's own arithmetic is the only real check on a layout where
  // direction is recovered rather than read.
  const txs = await activoBankParser.parse(STATEMENT);
  const sum = txs.reduce((total, tx) => total + tx.amountCents, 0);
  assert.equal(50000 + sum, 100000);
});
