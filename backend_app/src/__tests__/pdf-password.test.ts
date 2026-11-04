import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import path from 'path';

// No AI provider in these tests: processStatement must refuse before
// touching the PDF, and extractText is checked on its own.
delete process.env.ANTHROPIC_API_KEY;
delete process.env.GEMINI_API_KEY;

const encrypted = () => fs.readFileSync(path.join(process.cwd(), 'src/__fixtures__/encrypted-statement.pdf'));

test('extractText maps an encrypted PDF to distinct password error codes', async () => {
  const { extractText } = await import('../index');
  const { PdfPasswordRequiredError, PdfPasswordIncorrectError } = await import('../errors');

  await assert.rejects(() => extractText(encrypted()), PdfPasswordRequiredError);
  await assert.rejects(() => extractText(encrypted(), 'wrong-password'), PdfPasswordIncorrectError);
  assert.equal(typeof (await extractText(encrypted(), '1234')), 'string');
});

test('extractText maps a file that is not a PDF to PDF_UNREADABLE', async () => {
  // A user mistake, not a server fault: it used to surface as INTERNAL_ERROR
  // with a pdf.js stack trace in the log.
  const { extractText } = await import('../index');
  const { PdfUnreadableError } = await import('../errors');

  await assert.rejects(() => extractText(Buffer.from('not a pdf at all')), PdfUnreadableError);
});

test('without an AI provider, processStatement answers AI_NOT_CONFIGURED', async () => {
  const { processStatement } = await import('../index');
  const { AiNotConfiguredError } = await import('../errors');

  await assert.rejects(() => processStatement(encrypted()), AiNotConfiguredError);
  await assert.rejects(() => processStatement(encrypted(), '1234'), AiNotConfiguredError);
});
