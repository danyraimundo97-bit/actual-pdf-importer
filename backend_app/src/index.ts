import pdfParse from 'pdf-parse';
import { BankParser, RawTransaction } from './types';
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
 *     instead of a pdf-parse text dump.
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
      // Not used for text: PARSER_MODE=ai goes through the direct-PDF path
      // in processStatement() instead of this text-based parser chain.
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
    ? `[parsers] PARSER_MODE=ai — PDFs go straight to AI provider "${getAiProvider().name}", no local text extraction.`
    : `[parsers] PARSER_MODE=${PARSER_MODE} — active parsers: ${TEXT_PARSERS.map((p) => p.bankId).join(', ')}`,
);

export class UnrecognizedBankError extends Error {
  constructor() {
    super('Could not identify which bank this statement is from.');
    this.name = 'UnrecognizedBankError';
  }
}

/**
 * Picks a parser by content sniffing rather than trusting a filename or
 * user-supplied hint, since PDFs get renamed/forwarded and a wrong guess
 * here silently corrupts every transaction downstream. Only used for the
 * text-based paths ("regex" and "both").
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
 * Single entry point server.ts calls with the uploaded PDF's raw bytes.
 * Decides, based on PARSER_MODE, whether to extract text locally first
 * (regex/both) or send the PDF straight to the AI provider (ai).
 */
export async function processStatement(
  pdfBuffer: Buffer,
): Promise<{ bankId: BankParser['bankId']; transactions: RawTransaction[] }> {
  if (PARSER_MODE === 'ai') {
    const transactions = await parseAiFromPdf(pdfBuffer);
    return { bankId: 'ai', transactions };
  }

  // regex or both: extract text locally first — nothing leaves the machine
  // for this step — then run it through the parser chain.
  const { text } = await pdfParse(pdfBuffer);
  return identifyAndParse(text);
}

export * from './types';
