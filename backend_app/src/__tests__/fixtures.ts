import fs from 'fs';
import path from 'path';

/**
 * The repo's shared parser fixtures (`fixtures/` at the repo root), read by
 * these tests and by the app's Dart parser package
 * (`mobile_app/packages/statement_parser`). Same path from `src/__tests__`
 * and from the compiled `dist/__tests__`.
 *
 * Per case: `<name>.pdfjs.txt` (the text pdf-parse extracts, which is what
 * these parsers read), optionally `<name>.pdfium.txt` (the app's extractor;
 * Dart only), and `<name>.expected.json`. All synthetic: never put a real
 * statement in a fixture.
 */
export const FIXTURES_DIR = path.resolve(__dirname, '../../../fixtures');

export interface ExpectedParse {
  bankId: string;
  transactions: Array<{ date: string; payee: string; amountCents: number }>;
}

export function parserFixtureNames(): string[] {
  return fs
    .readdirSync(path.join(FIXTURES_DIR, 'parsers'))
    .filter((f) => f.endsWith('.expected.json'))
    .map((f) => f.replace(/\.expected\.json$/, ''))
    .sort();
}

/** The pdf.js-shaped text of a fixture, e.g. `fixtureText('moey-basic')`. */
export function fixtureText(name: string): string {
  return fs.readFileSync(path.join(FIXTURES_DIR, 'parsers', `${name}.pdfjs.txt`), 'utf8');
}

export function fixtureExpected(name: string): ExpectedParse {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, 'parsers', `${name}.expected.json`), 'utf8'));
}

export interface GoldenIdCase {
  name: string;
  transactions: Array<{ date: string; payee: string; amountCents: number }>;
  importedIds: string[];
}

export function goldenImportedIds(): GoldenIdCase[] {
  return JSON.parse(fs.readFileSync(path.join(FIXTURES_DIR, 'imported-ids.json'), 'utf8')).cases;
}
