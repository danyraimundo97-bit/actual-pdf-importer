import { test } from 'node:test';
import assert from 'node:assert/strict';
import { moeyParser } from '../parsers/moey';
import { fixtureText } from './fixtures';

// The statements themselves are shared fixtures (fixtures/parsers/moey-*),
// checked movement by movement in parser-fixtures.test.ts:
// - moey-basic: wrapped descriptions, amount/balance on their own lines, a
//   page break in the middle of a movement, the savings section after
//   SALDO FINAL.
// - moey-page-code-payee: a wrapped description shaped like the page-code
//   line ("IFTHEN25") must not swallow the movements after it. The tripped
//   block itself is lost (and logged); the ones after it survive.
const STATEMENT = fixtureText('moey-basic');

test('canParse recognises a moey statement', () => {
  assert.equal(moeyParser.canParse(STATEMENT), true);
  assert.equal(moeyParser.canParse('ActivoBank extracto'), false);
});

test('parse stops at the savings-account section', async () => {
  const txs = await moeyParser.parse(STATEMENT);
  assert.equal(txs.some((t) => /renda/i.test(t.payee)), false);
});
