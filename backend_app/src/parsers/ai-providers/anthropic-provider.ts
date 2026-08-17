import Anthropic from '@anthropic-ai/sdk';
import { AiProvider, AiTransaction } from './types';
import { EXTRACTION_SYSTEM_PROMPT } from './prompt';

const MODEL = process.env.ANTHROPIC_MODEL ?? 'claude-3-5-haiku-latest';
const MAX_TOKENS = 4096;

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
            date: { type: 'string', description: 'Transaction date, normalized to YYYY-MM-DD.' },
            payee: { type: 'string', description: 'Cleaned merchant/payee name, noise prefixes stripped.' },
            amount: { type: 'number', description: 'Amount in euros, plain decimal. Negative = money out.' },
            rawLine: { type: 'string', description: 'The original line(s) this was extracted from, for auditing.' },
          },
          required: ['date', 'payee', 'amount', 'rawLine'],
        },
      },
    },
    required: ['transactions'],
  },
};

const USER_INSTRUCTION = 'Extract every transaction from this bank statement.';

export class AnthropicProvider implements AiProvider {
  readonly name = 'anthropic';
  private client: Anthropic | null | undefined;

  private getClient(): Anthropic | null {
    if (this.client !== undefined) return this.client;
    const apiKey = process.env.ANTHROPIC_API_KEY;
    this.client = apiKey ? new Anthropic({ apiKey }) : null;
    return this.client;
  }

  isConfigured(): boolean {
    return this.getClient() !== null;
  }

  extractTransactionsFromText(text: string): Promise<AiTransaction[]> {
    return this.runExtraction(text);
  }

  extractTransactionsFromPdf(pdfBuffer: Buffer): Promise<AiTransaction[]> {
    // Claude's Messages API accepts a PDF directly as a "document" content
    // block (base64-encoded) and reasons over its actual layout — tables,
    // columns, multi-page statements — rather than a flattened text dump.
    return this.runExtraction({
      type: 'document' as const,
      source: {
        type: 'base64' as const,
        media_type: 'application/pdf' as const,
        data: pdfBuffer.toString('base64'),
      },
    });
  }

  private async runExtraction(
    content: string | { type: 'document'; source: { type: 'base64'; media_type: 'application/pdf'; data: string } },
  ): Promise<AiTransaction[]> {
    const client = this.getClient();
    if (!client) {
      throw new Error('AnthropicProvider used without ANTHROPIC_API_KEY configured.');
    }

    const userContent =
      typeof content === 'string'
        ? content
        : [content, { type: 'text' as const, text: USER_INSTRUCTION }];

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: EXTRACTION_SYSTEM_PROMPT,
      tools: [EXTRACTION_TOOL],
      tool_choice: { type: 'tool', name: 'record_transactions' },
      messages: [{ role: 'user', content: userContent as never }],
    });

    const toolUse = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use',
    );
    if (!toolUse) {
      throw new Error('Anthropic provider: model did not return structured transactions.');
    }

    const parsed = toolUse.input as { transactions: AiTransaction[] };
    return parsed.transactions;
  }
}
