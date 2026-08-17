import { GoogleGenerativeAI, Part, SchemaType } from '@google/generative-ai';
import { AiProvider, AiTransaction } from './types';
import { EXTRACTION_SYSTEM_PROMPT } from './prompt';

const MODEL = process.env.GEMINI_MODEL ?? 'gemini-1.5-flash';

// Gemini's structured-output mode (responseSchema + responseMimeType:
// "application/json") plays the same role here that the tool-use schema
// plays for Anthropic — it's what forces a parseable shape back instead of
// free-form prose.
const RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    transactions: {
      type: SchemaType.ARRAY,
      items: {
        type: SchemaType.OBJECT,
        properties: {
          date: { type: SchemaType.STRING, description: 'Transaction date, normalized to YYYY-MM-DD.' },
          payee: { type: SchemaType.STRING, description: 'Cleaned merchant/payee name, noise prefixes stripped.' },
          amount: { type: SchemaType.NUMBER, description: 'Amount in euros, plain decimal. Negative = money out.' },
          rawLine: { type: SchemaType.STRING, description: 'The original line(s) this was extracted from, for auditing.' },
        },
        required: ['date', 'payee', 'amount', 'rawLine'],
      },
    },
  },
  required: ['transactions'],
};

const USER_INSTRUCTION = 'Extract every transaction from this bank statement.';

export class GeminiProvider implements AiProvider {
  readonly name = 'gemini';
  private client: GoogleGenerativeAI | null | undefined;

  private getClient(): GoogleGenerativeAI | null {
    if (this.client !== undefined) return this.client;
    const apiKey = process.env.GEMINI_API_KEY;
    this.client = apiKey ? new GoogleGenerativeAI(apiKey) : null;
    return this.client;
  }

  isConfigured(): boolean {
    return this.getClient() !== null;
  }

  extractTransactionsFromText(text: string): Promise<AiTransaction[]> {
    return this.runExtraction([{ text }]);
  }

  extractTransactionsFromPdf(pdfBuffer: Buffer): Promise<AiTransaction[]> {
    // Gemini accepts a PDF directly as inline base64 data and reasons over
    // the real layout (tables, columns, multi-page statements) instead of
    // a flattened text dump.
    return this.runExtraction([
      { inlineData: { mimeType: 'application/pdf', data: pdfBuffer.toString('base64') } },
      { text: USER_INSTRUCTION },
    ]);
  }

  private async runExtraction(parts: Part[]): Promise<AiTransaction[]> {
    const client = this.getClient();
    if (!client) {
      throw new Error('GeminiProvider used without GEMINI_API_KEY configured.');
    }

    const model = client.getGenerativeModel({
      model: MODEL,
      systemInstruction: EXTRACTION_SYSTEM_PROMPT,
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: RESPONSE_SCHEMA as never,
      },
    });

    const result = await model.generateContent(parts);
    const raw = result.response.text();

    let parsed: { transactions: AiTransaction[] };
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      throw new Error(`Gemini provider: could not parse model response as JSON: ${(err as Error).message}`);
    }

    return parsed.transactions ?? [];
  }
}
