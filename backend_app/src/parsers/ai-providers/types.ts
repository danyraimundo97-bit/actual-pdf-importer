export interface AiTransaction {
  date: string;    // YYYY-MM-DD
  payee: string;
  amount: number;   // euros, plain decimal — negative = money out
  rawLine: string;
}

/**
 * Strategy interface: aiparser.ts and src/index.ts only ever talk to this
 * shape. Which concrete AI vendor backs it is decided in
 * ai-providers/index.ts by the AI_PROVIDER env var.
 */
export interface AiProvider {
  readonly name: string;
  /** Whether this provider has everything it needs (API key, etc.) to run. */
  isConfigured(): boolean;
  /** Extract transactions from already-locally-extracted plain text. */
  extractTransactionsFromText(text: string): Promise<AiTransaction[]>;
  /**
   * Extract transactions directly from the PDF's raw bytes, skipping local
   * text extraction entirely — the model reasons over the real layout
   * (tables, columns) instead of a pdf-parse dump that can scramble it.
   * Used when PARSER_MODE=ai.
   */
  extractTransactionsFromPdf(pdfBuffer: Buffer): Promise<AiTransaction[]>;
}
