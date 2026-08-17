import { BankParser, RawTransaction, parsePtAmountToCents, normalizePtDate } from '../types';

const NOISE_PREFIXES = [
  /^Compra\s+online\s*/i,
  /^Compra\s*/i,
  /^Pagamento\s+MB\s*WAY\s*/i,
  /^MB\s*WAY\s*/i,
  /^Transferencia\s+enviada\s*/i,
  /^Transferencia\s+recebida\s*/i,
  /^Levantamento\s*/i,
];

// moey! statements tend to render as: 03/02/2024  Descrição do comerciante  -15,20 EUR
// Note the trailing currency code, unlike ActivoBank.
const LINE_RE = /^(\d{2}\/\d{2}\/\d{4})\s+(.+?)\s+(-?\d{1,3}(?:\.\d{3})*,\d{2})\s*(?:EUR)?\s*$/;

function cleanPayee(rawPayee: string): string {
  let payee = rawPayee.trim();
  for (const prefix of NOISE_PREFIXES) {
    const stripped = payee.replace(prefix, '');
    if (stripped !== payee) {
      payee = stripped.trim();
      break;
    }
  }
  return payee.replace(/\s{2,}/g, ' ').trim();
}

export const moeyParser: BankParser = {
  bankId: 'moey',

  canParse(fullText: string): boolean {
    return /moey!?/i.test(fullText);
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
        console.warn(`[moey] skipping unparseable line: "${line}" (${(err as Error).message})`);
      }
    }

    return transactions;
  },
};
