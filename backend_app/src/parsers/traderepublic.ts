import { BankParser, RawTransaction, parsePtAmountToCents } from '../types';
import { scanMovementBlocks } from './statement-scanner';

// A movement spans several lines:
//
//   03 ago.                                  <- day + abbreviated PT month
//   2026                                     <- year, on its own line
//   Transação com                            <- type (wraps)
//   cartão
//   PETROPRIX MATOSINHOS 420,00 €3 551,98 €  <- description, amount, balance
//
// The last line is where this gets nasty. ENTRADA DE DINHEIRO and SAÍDA DE
// DINHEIRO are separate columns in the PDF, so nothing in the text says
// whether a number was money in or money out — and the description runs
// straight into the amount with no separator. "PETROPRIX MATOSINHOS 420,00"
// is really the payee "PETROPRIX MATOSINHOS 4" (the bank truncates to a
// fixed width) plus an amount of 20,00, which no regex can know on its own.
//
// Both problems have the same answer: the running balance. The delta against
// the previous balance gives the signed amount, and the amount's printed
// form is then what separates description from number.
const AMOUNT = String.raw`\d{1,3}(?: \d{3})*,\d{2}`;
const DATE_LINE_RE = /^(\d{1,2})\s+(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\.?$/i;
const YEAR_LINE_RE = /^(\d{4})$/;
// Only the balance is unambiguous: the last €-terminated number on the line.
const BALANCE_TAIL_RE = new RegExp(`^(.*?)(${AMOUNT})\\s*€$`);
const OPENING_BALANCE_RE = new RegExp(String.raw`SALDO\s*INICIAL[\s\S]*?(${AMOUNT})\s*€`, 'i');
const SECTION_START_RE = /^TRANSA[ÇC][ÕO]ES$/;
const SECTION_END_RE = /^S[IÍ]NTESE DO BALAN[ÇC]O$/;
// Every page repeats an address footer followed by the table's column
// headers. Skipping it as a region avoids denylisting the individual lines,
// which include personal names.
const FOOTER_REGION = [/^TRADE REPUBLIC BANK GMBH/i, /^SALDO$/i] as const;

const MONTHS: Record<string, number> = {
  jan: 1, fev: 2, mar: 3, abr: 4, mai: 5, jun: 6,
  jul: 7, ago: 8, set: 9, out: 10, nov: 11, dez: 12,
};

// Transaction types Trade Republic prefixes the description with.
const TYPE_PREFIXES = [
  /^Transa[çc][ãa]o com cart[ãa]o\s*/i,
  /^Transfer[êe]ncia\s*/i,
  /^Juros\s*/i,
  /^Imposto\s*/i,
  /^Taxa\s*/i,
  /^Dividendo\s*/i,
];

const DESCRIPTION_PREFIXES = [
  /^Incoming transfer from\s*/i,
  /^Outgoing transfer (?:for|to)\s*/i,
];

/**
 * Renders cents the way the statement prints them, so the exact amount text
 * can be stripped off the end of a description. Comparing numerically
 * instead would not work: for "LOJA TESTE 410,00" an end-anchored amount
 * match returns 410,00 and would reject a true amount of 10,00.
 */
function formatCents(cents: number): string {
  const [whole, fraction] = (Math.abs(cents) / 100).toFixed(2).split('.');
  return `${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')},${fraction}`;
}

function cleanPayee(rawPayee: string): string {
  let payee = rawPayee.trim();
  for (const prefix of DESCRIPTION_PREFIXES) {
    const stripped = payee.replace(prefix, '');
    if (stripped !== payee) {
      payee = stripped.trim();
      break;
    }
  }
  // Drop a trailing IBAN in parentheses — it never varies for one payee but
  // makes the payee->category key needlessly long.
  payee = payee.replace(/\s*\(\s*[A-Z]{2}\d{2}[0-9A-Z]{4,}\s*\)\s*$/i, '');
  return payee.replace(/\s{2,}/g, ' ').trim();
}

function stripType(description: string): string {
  for (const prefix of TYPE_PREFIXES) {
    const stripped = description.replace(prefix, '');
    if (stripped !== description) return stripped.trim();
  }
  return description;
}

/** A movement with its balance read, but its amount not yet resolved. */
interface ScannedMovement {
  date: string;
  /** Type + description + the amount text, still glued together. */
  head: string;
  balance: number;
  rawLine: string;
}

export const tradeRepublicParser: BankParser = {
  bankId: 'traderepublic',

  canParse(fullText: string): boolean {
    // Deliberately the full legal entity name, not /trade\s*republic/i: a
    // moey statement lists "TRANSF SEPA -Trade Republic Ba" as a transfer
    // payee, and the looser sniff claims that statement as its own.
    return /trade\s*republic\s*bank\s*gmbh/i.test(fullText);
  },

  parse(fullText: string): RawTransaction[] {
    // pdf-parse returns NBSP for this statement's thousands and currency
    // gaps. Normalizing once here means every pattern below deals in plain
    // spaces, instead of each one having to accept either.
    const text = fullText.replace(/ /g, ' ');

    const scanned = scanMovementBlocks(text, {
      dateLine: DATE_LINE_RE,
      startAt: SECTION_START_RE,
      endAt: SECTION_END_RE,
      skipRegion: FOOTER_REGION,
    }).flatMap((block): ScannedMovement[] => {
      const [yearLine, ...rest] = block.lines;
      if (!yearLine || !YEAR_LINE_RE.test(yearLine)) {
        console.warn(`[traderepublic] no year line after "${block.dateLine}" — skipping`);
        return [];
      }
      const body = rest.join(' ').replace(/\s+/g, ' ').trim();
      const tail = body.match(BALANCE_TAIL_RE);
      if (!tail) {
        console.warn(`[traderepublic] no amount/balance found in "${body}"`);
        return [];
      }
      const day = Number(block.date[1]);
      const month = MONTHS[block.date[2].toLowerCase()];
      return [{
        date: `${yearLine}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
        head: tail[1].replace(/\s*€\s*$/, '').trimEnd(),
        balance: parsePtAmountToCents(tail[2]),
        rawLine: [block.dateLine, ...block.lines].join(' ').replace(/\s+/g, ' '),
      }];
    });

    if (scanned.length === 0) return [];

    // The opening balance is the anchor for the first delta. Without it the
    // first movement's direction *and* magnitude are both unrecoverable,
    // but every later one can still be derived from the balance it prints —
    // so a missing summary block costs one movement, not the statement.
    const anchor = text.match(OPENING_BALANCE_RE);
    if (!anchor) {
      console.warn('[traderepublic] no SALDO INICIAL in the summary block — the first movement will be skipped');
    }
    let balance = anchor ? parsePtAmountToCents(anchor[1]) : scanned[0].balance;
    const resolvable = anchor ? scanned : scanned.slice(1);

    const transactions: RawTransaction[] = [];
    for (const movement of resolvable) {
      const amountCents = movement.balance - balance;
      balance = movement.balance;

      const printed = formatCents(amountCents);
      if (!movement.head.endsWith(printed)) {
        console.warn(
          `[traderepublic] balance moved by ${amountCents} but "${printed}" is not printed at the ` +
            `end of "${movement.head}" — skipping`,
        );
        continue;
      }
      transactions.push({
        date: movement.date,
        payee: cleanPayee(stripType(movement.head.slice(0, -printed.length).trim())),
        amountCents,
        rawLine: movement.rawLine,
      });
    }

    return transactions;
  },
};
