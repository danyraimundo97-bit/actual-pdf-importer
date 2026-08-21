import pdfParse from 'pdf-parse';
import { BankParser, RawTransaction } from './types';
import { UnrecognizedBankError, PdfPasswordRequiredError, PdfPasswordIncorrectError } from './errors';
import { activoBankParser } from './parsers/activobank';
import { moeyParser } from './parsers/moey';
import { tradeRepublicParser } from './parsers/traderepublic';
import { aiParser, parseAiFromPdf } from './parsers/aiparser';
import { getAiProvider } from './parsers/ai-providers';

export type ParserMode = 'regex' | 'ai' | 'both';

/**
 * PARSER_MODE is the switch: pick which parsing strategy is active without
 * touching code.
 *   - "regex" (default): only the local ActivoBank/moey!/Trade Republic
 *     parsers run. Fully offline — nothing is ever sent anywhere.
 *   - "ai": every statement skips local text extraction entirely and its
 *     raw PDF bytes go straight to the configured AI provider (see
 *     processStatement() below) — the model reasons over the real layout
 *     instead of a pdf-parse text dump. Exception: a password-protected
 *     statement in this mode still has to go through local text
 *     extraction first (see processStatement) since the AI provider has
 *     no way to decrypt it.
 *   - "both": regex parsers run first (cheap, local, on extracted text);
 *     the AI parser is a text-based fallback only for statements none of
 *     them recognized — it reuses the text already extracted for the
 *     regex pass rather than resending the PDF.
 */
function resolveParserMode(): ParserMode {
  const raw = (process.env.PARSER_MODE ?? 'regex').trim().toLowerCase();
  if (raw === 'regex' || raw === 'ai' || raw === 'both') return raw;
  console.warn(`[parsers] Unknown PARSER_MODE "${raw}" — falling back to "regex".`);
  return 'regex';
}

const REGEX_PARSERS: BankParser[] = [activoBankParser, moeyParser, tradeRepublicParser];

function buildTextParserList(mode: ParserMode): BankParser[] {
  switch (mode) {
    case 'regex':
      return REGEX_PARSERS;
    case 'both':
      return [...REGEX_PARSERS, aiParser];
    case 'ai':
      // Not used for the direct-PDF path in processStatement() — only
      // reached when an "ai"-mode statement turns out to be
      // password-protected and has to fall back to text extraction.
      return [aiParser];
  }
}

export const PARSER_MODE = resolveParserMode();
const TEXT_PARSERS: BankParser[] = buildTextParserList(PARSER_MODE);

// Fail loudly at startup rather than on the first upload: a misconfigured
// PARSER_MODE/AI_PROVIDER pairing should never surface as a mysterious
// error on every request. Ask the provider itself whether it's configured,
// rather than hardcoding which env var that implies — that stays correct
// no matter which AI_PROVIDER is selected.
if (PARSER_MODE === 'ai' || PARSER_MODE === 'both') {
  const provider = getAiProvider();
  if (!provider.isConfigured()) {
    const message = `PARSER_MODE=${PARSER_MODE} requires AI provider "${provider.name}" to be configured (check its API key in .env).`;
    if (PARSER_MODE === 'ai') {
      throw new Error(message);
    }
    console.warn(`[parsers] ${message} — the AI fallback will never trigger.`);
  }
}

console.log(
  PARSER_MODE === 'ai'
    ? `[parsers] PARSER_MODE=ai — PDFs go straight to AI provider "${getAiProvider().name}", no local text extraction (unless a statement turns out to be password-protected).`
    : `[parsers] PARSER_MODE=${PARSER_MODE} — active parsers: ${TEXT_PARSERS.map((p) => p.bankId).join(', ')}`,
);

/**
 * Picks a parser by content sniffing rather than trusting a filename or
 * user-supplied hint, since PDFs get renamed/forwarded and a wrong guess
 * here silently corrupts every transaction downstream. Only used for the
 * text-based paths ("regex" and "both", or "ai" degraded to text — see
 * processStatement()).
 */
export async function identifyAndParse(
  fullText: string,
): Promise<{ bankId: BankParser['bankId']; transactions: RawTransaction[] }> {
  for (const parser of TEXT_PARSERS) {
    if (parser.canParse(fullText)) {
      return { bankId: parser.bankId, transactions: await parser.parse(fullText) };
    }
  }
  throw new UnrecognizedBankError();
}

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
async function extractText(pdfBuffer: Buffer, password?: string): Promise<string> {
  try {
    const { text } = await pdfParse({ data: pdfBuffer, password } as unknown as Buffer);
    return text;
  } catch (err) {
    const code = (err as { code?: number }).code;
    if (code === 1) throw new PdfPasswordRequiredError();
    if (code === 2) throw new PdfPasswordIncorrectError();
    throw err;
  }
}

/**
 * Single entry point server.ts calls with the uploaded PDF's raw bytes.
 * Decides, based on PARSER_MODE, whether to extract text locally first
 * (regex/both, or ai-with-a-password) or send the PDF straight to the AI
 * provider (ai, unencrypted).
 */
export async function processStatement(
  pdfBuffer: Buffer,
  password?: string,
): Promise<{ bankId: BankParser['bankId']; transactions: RawTransaction[] }> {
  if (PARSER_MODE === 'ai' && !password) {
    const transactions = await parseAiFromPdf(pdfBuffer);
    return { bankId: 'ai', transactions };
  }

  // regex / both, or an "ai"-mode statement that needs a password: extract
  // text locally — nothing leaves the machine for this step — then run it
  // through the text-based parser chain. In pure "ai" mode with a
  // password that chain is just [aiParser] (see buildTextParserList):
  // lower fidelity than sending the raw PDF, but it reuses code that
  // already exists for PARSER_MODE=both rather than adding a PDF
  // decryption dependency to the backend.
  const text = await extractText(pdfBuffer, password);
  return identifyAndParse(text);
}

export * from './types';
export * from './errors';
