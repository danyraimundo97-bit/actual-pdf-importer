export interface RawTransaction {
  date: string;        // YYYY-MM-DD, normalized
  payee: string;        // cleaned merchant/description
  amountCents: number;  // integer cents, negative = outflow
  rawLine: string;      // original line, kept for debugging/audit
}

export interface BankParser {
  bankId: 'ai';
  /** Cheap heuristic check: does this PDF text look like it came from this bank? */
  canParse(fullText: string): boolean;
  /** Extract transactions from the full extracted PDF text. */
  parse(fullText: string): Promise<RawTransaction[]>;
}
