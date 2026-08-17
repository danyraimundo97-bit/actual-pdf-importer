import { BankParser, RawTransaction } from '../types';
import { AiTransaction, getAiProvider } from './ai-providers';

const MAX_CHARS = 60_000;

function toRawTransaction(t: AiTransaction): RawTransaction {
  return {
    date: t.date,
    payee: t.payee.trim(),
    amountCents: Math.round(t.amount * 100),
    rawLine: t.rawLine,
  };
}

export const aiParser: BankParser = {
  bankId: 'ai',

  // Deliberately the most permissive matcher of the group — this parser is
  // a last-resort fallback, and MUST stay last in src/index.ts's PARSERS
  // list so bank-specific regex parsers get first refusal.
  canParse(_fullText: string): boolean {
    return getAiProvider().isConfigured();
  },

  async parse(fullText: string): Promise<RawTransaction[]> {
    const provider = getAiProvider();
    if (!provider.isConfigured()) {
      throw new Error(`AI parser invoked but provider "${provider.name}" is not configured.`);
    }

    const text = fullText.length > MAX_CHARS ? fullText.slice(0, MAX_CHARS) : fullText;
    const transactions = await provider.extractTransactionsFromText(text);
    return transactions.map(toRawTransaction);
  },
};

/**
 * PARSER_MODE=ai's direct path: send the PDF's raw bytes straight to
 * whichever AI provider is configured, no local text extraction step at
 * all.
 */
export async function parseAiFromPdf(pdfBuffer: Buffer): Promise<RawTransaction[]> {
  const provider = getAiProvider();
  if (!provider.isConfigured()) {
    throw new Error(`PARSER_MODE=ai but provider "${provider.name}" is not configured.`);
  }

  const transactions = await provider.extractTransactionsFromPdf(pdfBuffer);
  return transactions.map(toRawTransaction);
}
