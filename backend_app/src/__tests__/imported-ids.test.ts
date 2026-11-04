import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assignImportedIds } from '../actual';
import { goldenImportedIds } from './fixtures';

// The shared golden ids (fixtures/imported-ids.json), which the app's Dart
// parser package checks too: a statement read on the phone must get the
// same importedId as one read here, or a re-import duplicates it.
// actual.test.ts keeps these as literals as well.
for (const golden of goldenImportedIds()) {
  test(`golden importedIds: ${golden.name}`, () => {
    const stamped = assignImportedIds(golden.transactions.map((t) => ({ ...t, rawLine: '' })));
    assert.deepEqual(stamped.map((t) => t.importedId), golden.importedIds);
  });
}
