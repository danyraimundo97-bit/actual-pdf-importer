import { BankParser, RawTransaction, parsePtAmountToCents, normalizePtDate } from '../types';

// Prefixes ActivoBank prepends to the merchant name. Order matters: longer,
// more specific prefixes must come before shorter generic ones so we don't
// leave a trailing fragment (e.g. strip "MB WAY PAGAMENTO" fully instead of
// just "MB WAY" and leaving "PAGAMENTO X").
const NOISE_PREFIXES = [
  /^COMPRA\s+ONLINE\s*/i,
  /^COMPRA\s+CARTAO\s*/i,
  /^COMPRA\s*/i,
  /^MB\s*WAY\s+PAGAMENTO\s*/i,
  /^MB\s*WAY\s+LEVANTAMENTO\s*/i,
  /^MB\s*WAY\s*/i,
  /^LEVANTAMENTO\s+ATM\s*/i,
  /^LEVANTAMENTO\s*/i,
  /^TRANSFERENCIA\s+MB\s*/i,
  /^TRANSFERENCIA\s*/i,
  /^PAGAMENTO\s+SERVICOS?\s*/i,
  /^PAG\.\s*/i,
  /^DEBITO\s+DIRETO\s*/i,
];

// A line looks like: 12-03-2024  ALGUM COMERCIANTE LDA  -23,45
const LINE_RE = /^(\d{2}-\d{2}-\d{4})\s+(.+?)\s+(-?\d{1,3}(?:\.\d{3})*,\d{2})\s*$/;

function cleanPayee(rawPayee: string): string {
  let payee = rawPayee.trim();
  for (const prefix of NOISE_PREFIXES) {
    const stripped = payee.replace(prefix, '');
    if (stripped !== payee) {
      payee = stripped.trim();
      break; // only strip one matching prefix, then stop
    }
  }
  // Collapse repeated whitespace left behind by stripping.
  return payee.replace(/\s{2,}/g, ' ').trim();
}

export const activoBankParser: BankParser = {
  bankId: 'activobank',

  canParse(fullText: string): boolean {
    return /activobank/i.test(fullText) || /activo\s*bank/i.test(fullText);
  },

  parse(fullText: string): RawTransaction[] {
    const transactions: RawTransaction[] = [];
    const lines = fullText.split('\n');

    for (const line of lines) {
      const match = line.match(LINE_RE);
      if (!match) continue;

      const [, dateRaw, payeeRaw, amountRaw] = match;
      try {
        transactions.push({
          date: normalizePtDate(dateRaw),
          payee: cleanPayee(payeeRaw),
          amountCents: parsePtAmountToCents(amountRaw),
          rawLine: line.trim(),
        });
      } catch (err) {
        // Skip lines that superficially match but fail deeper parsing
        // (e.g. a totals/subtotal row) rather than crashing the whole import.
        console.warn(`[activobank] skipping unparseable line: "${line}" (${(err as Error).message})`);
      }
    }

    return transactions;
  },
};
