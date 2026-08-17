export interface RawTransaction {
  date: string;        // YYYY-MM-DD, normalized
  payee: string;        // cleaned merchant/description
  amountCents: number;  // integer cents, negative = outflow
  rawLine: string;      // original line, kept for debugging/audit
}

export interface BankParser {
  bankId: 'activobank' | 'moey' | 'traderepublic' | 'ai';
  /** Cheap heuristic check: does this PDF text look like it came from this bank? */
  canParse(fullText: string): boolean;
  /**
   * Extract transactions from the full extracted PDF text. Regex parsers
   * return synchronously; the AI fallback parser returns a Promise because
   * it calls out to an API.
   */
  parse(fullText: string): RawTransaction[] | Promise<RawTransaction[]>;
}

/**
 * Converts a Portuguese-formatted amount string ("1.234,56" or "-12,30")
 * into integer cents. Throws on unparseable input rather than silently
 * returning 0 — a silent 0 is worse than a loud failure in financial data.
 */
export function parsePtAmountToCents(raw: string): number {
  const cleaned = raw.trim().replace(/\s/g, '');
  const negative = cleaned.startsWith('-');
  const digitsOnly = cleaned.replace(/^-/, '').replace(/\./g, '').replace(',', '.');
  const value = Number(digitsOnly);
  if (Number.isNaN(value)) {
    throw new Error(`Could not parse amount: "${raw}"`);
  }
  const cents = Math.round(value * 100);
  return negative ? -cents : cents;
}

/** Converts "DD-MM-YYYY" or "DD/MM/YYYY" to "YYYY-MM-DD". */
export function normalizePtDate(raw: string): string {
  const match = raw.trim().match(/^(\d{2})[-\/](\d{2})[-\/](\d{4})$/);
  if (!match) {
    throw new Error(`Could not parse date: "${raw}"`);
  }
  const [, dd, mm, yyyy] = match;
  return `${yyyy}-${mm}-${dd}`;
}
