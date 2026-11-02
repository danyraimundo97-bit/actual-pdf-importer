import { test } from 'node:test';
import assert from 'node:assert/strict';
import { activoBankParser } from '../parsers/activobank';
import { moeyParser } from '../parsers/moey';
import { tradeRepublicParser } from '../parsers/traderepublic';
import { assignImportedIds } from '../actual';
import type { BankParser } from '../types';
import { fixtureExpected, fixtureText, goldenImportedIds, parserFixtureNames } from './fixtures';

// The cases shared with the app's Dart parsers (fixtures/ at the repo root).
// Both suites must agree on every one, so a statement reads the same on the
// phone and here.

const PARSERS: BankParser[] = [activoBankParser, moeyParser, tradeRepublicParser];

test('there are shared parser fixtures', () => {
  assert.ok(parserFixtureNames().length > 0);
});

for (const name of parserFixtureNames()) {
  test(`fixture ${name}`, async () => {
    const text = fixtureText(name);
    const expected = fixtureExpected(name);

    // Detection, the same first-match order as index.ts's REGEX_PARSERS.
    const parser = PARSERS.find((p) => p.canParse(text));
    assert.equal(parser?.bankId, expected.bankId);

    const txs = await parser!.parse(text);
    assert.deepEqual(
      txs.map(({ date, payee, amountCents }) => ({ date, payee, amountCents })),
      expected.transactions,
    );
  });
}

// actual.test.ts keeps these as literals as well; the shared copy is what
// pins the Dart port to the same ids.
for (const golden of goldenImportedIds()) {
  test(`golden importedIds: ${golden.name}`, () => {
    const stamped = assignImportedIds(golden.transactions.map((t) => ({ ...t, rawLine: '' })));
    assert.deepEqual(stamped.map((t) => t.importedId), golden.importedIds);
  });
}
