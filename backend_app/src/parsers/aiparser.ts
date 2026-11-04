import { BankParser, RawTransaction } from '../types';
import { AiTransaction, getAiProvider } from './ai-providers';
import { logger } from '../logger';

const log = logger.child({ area: 'ai' });

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

  // Any statement: the provider reads every bank.
  canParse(_fullText: string): boolean {
    return getAiProvider().isConfigured();
  },

  async parse(fullText: string): Promise<RawTransaction[]> {
    const provider = getAiProvider();
    if (!provider.isConfigured()) {
      throw new Error(`AI parser invoked but provider "${provider.name}" is not configured.`);
    }

    const text = fullText.length > MAX_CHARS ? fullText.slice(0, MAX_CHARS) : fullText;
    const started = Date.now();
    const transactions = await provider.extractTransactionsFromText(text);
    // Info, not debug: statement text left this machine for a cloud service.
    log.info(
      { provider: provider.name, input: 'text', chars: text.length, truncated: text.length < fullText.length, transactions: transactions.length, ms: Date.now() - started },
      'Statement parsed by the AI provider',
    );
    return transactions.map(toRawTransaction);
  },
};

/**
 * The direct path: send the PDF's raw bytes straight to whichever AI
 * provider is configured, no local text extraction step at all.
 */
export async function parseAiFromPdf(pdfBuffer: Buffer): Promise<RawTransaction[]> {
  const provider = getAiProvider();
  if (!provider.isConfigured()) {
    throw new Error(`AI parser invoked but provider "${provider.name}" is not configured.`);
  }

  const started = Date.now();
  const transactions = await provider.extractTransactionsFromPdf(pdfBuffer);
  log.info(
    { provider: provider.name, input: 'pdf', sizeKb: Math.round(pdfBuffer.length / 1024), transactions: transactions.length, ms: Date.now() - started },
    'Statement parsed by the AI provider',
  );
  return transactions.map(toRawTransaction);
}
