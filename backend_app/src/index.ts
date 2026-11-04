import pdfParse from 'pdf-parse';
import { RawTransaction } from './types';
import {
  AiNotConfiguredError,
  PdfPasswordRequiredError,
  PdfPasswordIncorrectError,
  PdfUnreadableError,
} from './errors';
import { aiParser, parseAiFromPdf } from './parsers/aiparser';
import { getAiProvider } from './parsers/ai-providers';
import { logger } from './logger';

const log = logger.child({ area: 'parser' });

/**
 * Statements are read on the phone (mobile_app/packages/statement_parser).
 * The backend only reads the ones the phone can't, with the AI provider
 * (AI_PROVIDER + its API key). Without one, POST /parse answers
 * AI_NOT_CONFIGURED and everything else works as usual.
 *
 * The bank-specific regex parsers and PARSER_MODE were removed once the
 * Dart port had proven itself (docs/plans/dart-parser.md, Phase 6).
 */
export function aiReadsStatements(): boolean {
  return getAiProvider().isConfigured();
}

if (process.env.PARSER_MODE) {
  log.warn(
    { parserMode: process.env.PARSER_MODE },
    'PARSER_MODE is no longer used: statements are read on the phone, and here only by the AI provider. Remove it from .env.',
  );
}
log.info(
  { aiProvider: getAiProvider().name, aiConfigured: aiReadsStatements() },
  aiReadsStatements()
    ? `Statements sent here are read by AI provider "${getAiProvider().name}".`
    : 'No AI provider configured: the backend does not read statements (the phone does).',
);

/**
 * Runs pdf-parse's local text extraction, optionally against a
 * password-protected PDF.
 *
 * pdf-parse forwards its first argument verbatim into pdf.js's own
 * `getDocument()`, which accepts either a raw buffer or a params object —
 * `{ data, password }` is how an encrypted statement's password reaches
 * pdf.js, even though pdf-parse's own README never mentions it.
 * @types/pdf-parse only declares the Buffer overload, hence the cast; do
 * not "simplify" this back to passing the buffer directly, or encrypted
 * statements silently stop working.
 */
export async function extractText(pdfBuffer: Buffer, password?: string): Promise<string> {
  try {
    const { text } = await pdfParse({ data: pdfBuffer, password } as unknown as Buffer);
    return text;
  } catch (err) {
    const code = (err as { code?: number }).code;
    if (code === 1) throw new PdfPasswordRequiredError();
    if (code === 2) throw new PdfPasswordIncorrectError();
    // pdf.js signals "this isn't a PDF" by exception name, not a code.
    if ((err as Error).name === 'InvalidPDFException') throw new PdfUnreadableError();
    throw err;
  }
}

/**
 * Single entry point server.ts calls with the uploaded PDF's raw bytes.
 * The PDF goes straight to the AI provider, which reads the real layout.
 * A password-protected one can't (the provider can't decrypt it), so it is
 * decrypted and extracted to text here first — nothing leaves the machine
 * for that step — and the text goes to the provider instead.
 */
export async function processStatement(
  pdfBuffer: Buffer,
  password?: string,
): Promise<{ bankId: 'ai'; transactions: RawTransaction[] }> {
  if (!aiReadsStatements()) throw new AiNotConfiguredError(getAiProvider().name);
  if (!password) {
    return { bankId: 'ai', transactions: await parseAiFromPdf(pdfBuffer) };
  }
  const text = await extractText(pdfBuffer, password);
  return { bankId: 'ai', transactions: await aiParser.parse(text) };
}

export * from './types';
export * from './errors';
