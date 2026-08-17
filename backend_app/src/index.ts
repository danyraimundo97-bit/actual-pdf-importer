import { BankParser, RawTransaction } from './types';
import { activoBankParser } from './parsers/activobank';
import { moeyParser } from './parsers/moey';
import { tradeRepublicParser } from './parsers/traderepublic';
import { aiParser } from './parsers/aiparser';

export type ParserMode = 'regex' | 'ai' | 'both';

/**
 * PARSER_MODE is the switch: pick which parsing strategy is active without
 * touching code.
 *   - "regex" (default): only the local ActivoBank/moey!/Trade Republic
 *     parsers run. Fully offline — nothing is ever sent anywhere, even if
 *     ANTHROPIC_API_KEY happens to be set.
 *   - "ai": only the AI parser runs, for every bank. Useful once you trust
 *     it, or for a bank you haven't written a regex parser for yet.
 *   - "both": regex parsers run first (cheap, local); the AI parser is a
 *     fallback only for statements none of them recognized.
 */
function resolveParserMode(): ParserMode {
  const raw = (process.env.PARSER_MODE ?? 'regex').trim().toLowerCase();
  if (raw === 'regex' || raw === 'ai' || raw === 'both') return raw;
  console.warn(`[parsers] Unknown PARSER_MODE "${raw}" — falling back to "regex".`);
  return 'regex';
}

const REGEX_PARSERS: BankParser[] = [activoBankParser, moeyParser, tradeRepublicParser];

function buildParserList(mode: ParserMode): BankParser[] {
  switch (mode) {
    case 'regex':
      return REGEX_PARSERS;
    case 'ai':
      return [aiParser];
    case 'both':
      return [...REGEX_PARSERS, aiParser];
  }
}

export const PARSER_MODE = resolveParserMode();
const PARSERS: BankParser[] = buildParserList(PARSER_MODE);

// Fail loudly at startup rather than on the first upload: a misconfigured
// PARSER_MODE should never surface as a mysterious "unrecognized bank" 422
// on every request.
if ((PARSER_MODE === 'ai' || PARSER_MODE === 'both') && !process.env.ANTHROPIC_API_KEY) {
  if (PARSER_MODE === 'ai') {
    throw new Error('PARSER_MODE=ai requires ANTHROPIC_API_KEY to be set in .env.');
  }
  console.warn('[parsers] PARSER_MODE=both but ANTHROPIC_API_KEY is not set — the AI fallback will never trigger.');
}

console.log(`[parsers] PARSER_MODE=${PARSER_MODE} — active parsers: ${PARSERS.map((p) => p.bankId).join(', ')}`);

export class UnrecognizedBankError extends Error {
  constructor() {
    super('Could not identify which bank this statement is from.');
    this.name = 'UnrecognizedBankError';
  }
}

/**
 * Picks a parser by content sniffing rather than trusting a filename or
 * user-supplied hint, since PDFs get renamed/forwarded and a wrong guess
 * here silently corrupts every transaction downstream.
 */
export async function identifyAndParse(
  fullText: string,
): Promise<{ bankId: BankParser['bankId']; transactions: RawTransaction[] }> {
  for (const parser of PARSERS) {
    if (parser.canParse(fullText)) {
      return { bankId: parser.bankId, transactions: await parser.parse(fullText) };
    }
  }
  throw new UnrecognizedBankError();
}

export * from './types';
