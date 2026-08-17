import { BankParser, RawTransaction, parsePtAmountToCents } from '../types';

// Trade Republic statements mix several transaction types in one flat list.
// We only want card spending — everything else (interest, tax, securities
// settlement, transfers) is explicitly excluded so it doesn't pollute the
// budget with things Actual should track differently (or not at all).
const CARD_TYPE_MARKERS = [/card transaction/i, /kartentransaktion/i, /cartão/i];

const EXCLUDE_TYPE_MARKERS = [
  /interest/i, /zinszahlung/i, /juro/i,
  /tax/i, /steuer/i, /imposto/i,
  /securities?\s+settlement/i, /wertpapierabrechnung/i, /liquidação/i,
  /dividend/i, /dividendo/i,
  /savings\s*plan/i, /sparplan/i,
  /round[\s-]?up/i,
];

// Trade Republic dates in statements are usually ISO already: 2024-03-12
const DATE_RE = /^(\d{4}-\d{2}-\d{2})/;
// Amount at the end of the line, with optional € sign and thin/regular spaces.
const AMOUNT_RE = /(-?\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*€?\s*$/;

function isExcluded(blockText: string): boolean {
  return EXCLUDE_TYPE_MARKERS.some((re) => re.test(blockText));
}

function isCardTransaction(blockText: string): boolean {
  return CARD_TYPE_MARKERS.some((re) => re.test(blockText));
}

/**
 * Trade Republic amounts in raw extraction are usually already
 * period-decimal (e.g. "-12.30") rather than comma-decimal, but statements
 * generated for PT accounts sometimes use comma-decimal. Handle both.
 */
function parseFlexibleAmountToCents(raw: string): number {
  const cleaned = raw.trim();
  const negative = cleaned.startsWith('-');
  const bare = cleaned.replace(/^-/, '');
  // If it has a comma, treat comma as decimal separator (PT/EU style).
  // Otherwise treat the final period as the decimal separator (US/ISO style).
  let normalized: string;
  if (bare.includes(',')) {
    normalized = bare.replace(/\./g, '').replace(',', '.');
  } else {
    normalized = bare;
  }
  const value = Number(normalized);
  if (Number.isNaN(value)) throw new Error(`Could not parse amount: "${raw}"`);
  const cents = Math.round(value * 100);
  return negative ? -cents : cents;
}

export const tradeRepublicParser: BankParser = {
  bankId: 'traderepublic',

  canParse(fullText: string): boolean {
    return /trade\s*republic/i.test(fullText);
  },

  parse(fullText: string): RawTransaction[] {
    const lines = fullText.split('\n').map((l) => l.trim()).filter(Boolean);
    const transactions: RawTransaction[] = [];

    // Group lines into blocks: each block starts at a line beginning with a
    // date and runs until (but not including) the next date-starting line.
    // This handles Trade Republic's tendency to wrap description text onto
    // a second line when the merchant name is long.
    const blocks: string[][] = [];
    let current: string[] | null = null;

    for (const line of lines) {
      if (DATE_RE.test(line)) {
        if (current) blocks.push(current);
        current = [line];
      } else if (current) {
        current.push(line);
      }
    }
    if (current) blocks.push(current);

    for (const block of blocks) {
      const blockText = block.join(' ');

      if (isExcluded(blockText)) continue;
      if (!isCardTransaction(blockText)) continue; // conservative: only keep confirmed card lines

      const dateMatch = blockText.match(DATE_RE);
      const amountMatch = blockText.match(AMOUNT_RE);
      if (!dateMatch || !amountMatch) {
        console.warn(`[traderepublic] card-like block missing date/amount, skipping: "${blockText}"`);
        continue;
      }

      // Payee: strip the leading date, the trailing amount, and the type
      // marker itself, leaving whatever's in between as the merchant text.
      let payee = blockText
        .replace(DATE_RE, '')
        .replace(AMOUNT_RE, '')
        .trim();
      for (const marker of CARD_TYPE_MARKERS) {
        payee = payee.replace(marker, '').trim();
      }
      payee = payee.replace(/\s{2,}/g, ' ').trim();

      try {
        transactions.push({
          date: dateMatch[1],
          payee: payee || 'Trade Republic card transaction',
          amountCents: parseFlexibleAmountToCents(amountMatch[1]),
          rawLine: blockText,
        });
      } catch (err) {
        console.warn(`[traderepublic] skipping block: "${blockText}" (${(err as Error).message})`);
      }
    }

    return transactions;
  },
};
