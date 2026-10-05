import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import path from 'path';

// PARSER_MODE is read once at module load in index.ts, so it must be set
// before the dynamic import below evaluates that module.
process.env.PARSER_MODE = 'regex';

test('processStatement maps an encrypted PDF to distinct password error codes', async () => {
  const { processStatement } = await import('../index');
  const { PdfPasswordRequiredError, PdfPasswordIncorrectError, UnrecognizedBankError } = await import(
    '../errors'
  );

  const encrypted = fs.readFileSync(
    path.join(process.cwd(), 'src/__fixtures__/encrypted-statement.pdf'),
  );

  await assert.rejects(() => processStatement(encrypted), PdfPasswordRequiredError);
  await assert.rejects(() => processStatement(encrypted, 'wrong-password'), PdfPasswordIncorrectError);

  // Correct password: the password check must pass and text extraction
  // must succeed — proven by getting past both and failing only at bank
  // identification (this fixture's text doesn't match any real bank).
  await assert.rejects(() => processStatement(encrypted, '1234'), UnrecognizedBankError);
});

test('processStatement maps a file that is not a PDF to PDF_UNREADABLE', async () => {
  // A user mistake, not a server fault. It used to surface as INTERNAL_ERROR
  // with a pdf.js stack trace in the log, which matters more now that one
  // stray file can ride along in a POST /parse/batch request.
  const { processStatement } = await import('../index');
  const { PdfUnreadableError } = await import('../errors');

  await assert.rejects(() => processStatement(Buffer.from('not a pdf at all')), PdfUnreadableError);
});
