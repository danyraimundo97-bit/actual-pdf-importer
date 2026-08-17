import Anthropic from '@anthropic-ai/sdk';
import { BankParser, RawTransaction } from '../types';

/**
 * Fallback parser: when none of the regex-based bank parsers recognize a
 * statement — a bank we haven't special-cased yet, or a layout tweak that
 * broke an existing regex — hand the already-locally-extracted PDF text to
 * an LLM and ask it to return structured transactions, instead of failing
 * the import outright.
 *
 * This still respects the project's privacy constraints: pdf-parse has
 * already done text extraction locally, and only that plain text (never
 * the PDF file itself, and never sent to a bank aggregator) goes to the
 * API. If ANTHROPIC_API_KEY isn't set, canParse() always returns false, so
 * a stock install with no key configured behaves exactly as it did before
 * this parser existed — nothing is ever sent anywhere by default.
 */

const MODEL = process.env.AI_PARSER_MODEL ?? 'claude-3-5-haiku-latest';

// Statements can be long; cap what we send so a huge PDF doesn't blow the
// context window or run up cost on a single import.
const MAX_CHARS = 60_000;

let client: Anthropic | null | undefined;

function getClient(): Anthropic | null {
  if (client !== undefined) return client;
  const apiKey = process.env.ANTHROPIC_API_KEY;
  client = apiKey ? new Anthropic({ apiKey }) : null;
  return client;
}

const EXTRACTION_TOOL = {
  name: 'record_transactions',
  description: 'Records the bank transactions extracted from a statement.',
  input_schema: {
    type: 'object' as const,
    properties: {
      transactions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            date: {
              type: 'string',
              description: 'Transaction date, normalized to YYYY-MM-DD.',
            },
            payee: {
              type: 'string',
              description:
                'Cleaned merchant/payee name, with bank-added noise prefixes (e.g. "COMPRA", "COMPRA ONLINE", "MB WAY PAGAMENTO", "LEVANTAMENTO") stripped.',
            },
            amount: {
              type: 'number',
              description: 'Amount in euros as a plain decimal (not cents). Negative for money out, positive for money in.',
            },
            rawLine: {
              type: 'string',
              description: 'The original line(s) from the statement this was extracted from, kept for auditing.',
            },
          },
          required: ['date', 'payee', 'amount', 'rawLine'],
        },
      },
    },
    required: ['transactions'],
  },
};

const SYSTEM_PROMPT = `You extract bank transactions from raw text pulled out of a PDF bank statement.

Rules:
- Only include actual movements of money (card purchases, transfers, direct debits, withdrawals, deposits). Skip headers, page numbers, opening/closing balances, and running-balance lines.
- If this looks like a Trade Republic statement specifically: exclude interest, tax withholdings, and securities/stock settlements — keep only card transactions.
- Normalize every date to YYYY-MM-DD.
- Clean payee names: strip generic bank-added prefixes (COMPRA, COMPRA ONLINE, MB WAY PAGAMENTO, LEVANTAMENTO, TRANSFERENCIA, etc.) and keep the merchant/counterparty name.
- Amount is negative for money leaving the account, positive for money coming in.
- Call the record_transactions tool exactly once with everything you found. If you find nothing, call it with an empty array.`;

export const aiParser: BankParser = {
  bankId: 'ai',

  // Deliberately the most permissive matcher of the group — this parser is
  // a last-resort fallback, and MUST stay last in src/index.ts's PARSERS
  // list so bank-specific regex parsers get first refusal. It only
  // "matches" at all if an API key is configured.
  canParse(_fullText: string): boolean {
    return getClient() !== null;
  },

  async parse(fullText: string): Promise<RawTransaction[]> {
    const anthropic = getClient();
    if (!anthropic) {
      throw new Error('AI parser invoked without ANTHROPIC_API_KEY configured.');
    }

    const text = fullText.length > MAX_CHARS ? fullText.slice(0, MAX_CHARS) : fullText;

    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      tools: [EXTRACTION_TOOL],
      tool_choice: { type: 'tool', name: 'record_transactions' },
      messages: [{ role: 'user', content: text }],
    });

    const toolUse = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use',
    );
    if (!toolUse) {
      throw new Error('AI parser: model did not return structured transactions.');
    }

    const parsed = toolUse.input as {
      transactions: Array<{ date: string; payee: string; amount: number; rawLine: string }>;
    };

    return parsed.transactions.map((t) => ({
      date: t.date,
      payee: t.payee.trim(),
      amountCents: Math.round(t.amount * 100),
      rawLine: t.rawLine,
    }));
  },
};
