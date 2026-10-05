import { BankParser, RawTransaction, parsePtAmountToCents, normalizePtDate } from '../types';
import { scanMovementBlocks } from './statement-scanner';

// Longer prefixes first: only the first matching prefix is stripped.
const NOISE_PREFIXES = [
  /^Compra\s+online\s*/i,
  /^DEV\s+COMPRA\s*/i,
  /^Compra\s*/i,
  /^IPS\/R\d+-\s*/i,
  /^Pagamento\s+MB\s*WAY\s*/i,
  /^MB\s*WAY\s*/i,
  /^TRANSF\s+SEPA\s*-\s*/i,
  /^Trf\s+imediata\s*/i,
  /^Trsf\.?\s*p\/\s*/i,
  /^Transferencia\s+enviada\s*/i,
  /^Transferencia\s+recebida\s*/i,
  /^PAG-\s*/i,
  /^Levant\w*\s*/i,
];

// The moey PDF (Crédito Agrícola) lays each movement out as:
//
//   01-07-2026  /  01-07-2026COMPRA BRISANORTE   9898237/51     <- posting date / value date, description
//     2,60  -53,16                                              <- amount, then "<in/out sign><balance>"
//
// - The amount has no sign of its own: the +/- glued to the front of the
//   balance is the direction of the movement ("+-9,77" = money in, new
//   balance -9,77).
// - Long descriptions wrap onto extra lines, and the amount/balance can land
//   on a line of their own, so a movement is a *block* of lines starting at a
//   date line.
// - Every page repeats a header, which can fall in the middle of a block.
// - The PDF also contains a savings-account section that mirrors transfers
//   already listed in the main account; it starts after the first "SALDO FINAL".
const DATE_LINE_RE = /^(\d{2}-\d{2}-\d{4})\s+\/\s+\d{2}-\d{2}-\d{4}(.*)$/;
const AMOUNT = String.raw`\d{1,3}(?:\.\d{3})*,\d{2}`;
const BLOCK_RE = new RegExp(`^(.*?)\\s+(${AMOUNT})\\s+([+-])(-?${AMOUNT})$`);
// Page code line, then the repeated column header that ends the page break.
const HEADER_REGION = [/^[A-Z]{3,}\d{2,}\w*$/, /^ACCOUNT DATE\s*\/\s*VALUE DATE/] as const;
const SECTION_END_RE = /^SALDO FINAL/;

function cleanPayee(rawPayee: string): string {
  // The trailing "9898237/51" card-operation reference differs on every
  // transaction; leaving it in would defeat the payee->category memory.
  let payee = rawPayee.replace(/\s+\d{5,}\/\d+$/, '').trim();
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
    return /moey/i.test(fullText);
  },

  parse(fullText: string): RawTransaction[] {
    const transactions: RawTransaction[] = [];

    const blocks = scanMovementBlocks(fullText, {
      dateLine: DATE_LINE_RE,
      endAt: SECTION_END_RE,
      skipRegion: HEADER_REGION,
    });

    for (const { date, lines } of blocks) {
      const movementDate = date[1];
      // date[2] is the rest of the date line: the description starts there,
      // glued to the value date, and continues on the lines that follow.
      const block = [date[2], ...lines].join(' ').replace(/\s+/g, ' ').trim();
      const match = block.match(BLOCK_RE);

      if (!match) {
        // Not a movement: a stray line, or a block whose amount/balance got
        // lost. Never silent — a dropped movement must be visible in the log.
        console.warn(`[moey] skipping block with no amount/balance: "${block}"`);
        continue;
      }

      const [, description, amountRaw, sign] = match;
      try {
        const cents = parsePtAmountToCents(amountRaw);
        transactions.push({
          date: normalizePtDate(movementDate),
          payee: cleanPayee(description),
          amountCents: sign === '-' ? -cents : cents,
          rawLine: `${movementDate} ${block}`,
        });
      } catch (err) {
        // parsePtAmountToCents/normalizePtDate rejected a value that matched
        // the shape — skip this movement rather than failing the import.
        console.warn(`[moey] skipping unparseable block: "${block}" (${(err as Error).message})`);
      }
    }

    return transactions;
  },
};
