import fs from 'fs';
import path from 'path';

/**
 * The repo's shared fixtures (`fixtures/` at the repo root). The parser
 * cases under `fixtures/parsers/` are read by the app's Dart parser package
 * (`mobile_app/packages/statement_parser`); the backend reads only the
 * golden importedIds. Same path from `src/__tests__` and from the compiled
 * `dist/__tests__`. All synthetic: never put a real statement in a fixture.
 */
export const FIXTURES_DIR = path.resolve(__dirname, '../../../fixtures');

export interface GoldenIdCase {
  name: string;
  transactions: Array<{ date: string; payee: string; amountCents: number }>;
  importedIds: string[];
}

export function goldenImportedIds(): GoldenIdCase[] {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, 'imported-ids.json'), 'utf8')).cases;
}
