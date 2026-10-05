import { BankParser, RawTransaction } from '../types';
import { MovementBlock, scanMovementBlocks } from './statement-scanner';

// ActivoBank prints the merchant name behind a transaction-type prefix.
// Longer, more specific prefixes must come first: only the first matching
// prefix is stripped, so "COMPRA 2902 X" has to be tried before "COMPRA X"
// or the card-terminal number stays glued to the payee.
const NOISE_PREFIXES = [
  /^COMPRA\s+ONLINE\s*/i,
  /^COMPRA\s+CARTAO\s*/i,
  /^COMPRA\s+\d{3,4}\s+/i, // "COMPRA 2902 STEAM ..." — 4-digit card terminal
  /^COMPRA\s*/i,
  /^TRF\s+MB\s*WAY\s+P\/\s*/i,
  /^TRF\s+P\/\s*/i,
  /^TRF\s*/i,
  /^MB\s*WAY\s+PAGAMENTO\s*/i,
  /^MB\s*WAY\s+LEVANTAMENTO\s*/i,
  /^MB\s*WAY\s*/i,
  /^LEVANTAMENTO\s+ATM\s*/i,
  /^LEVANTAMENTO\s*/i,
  /^TRANSFERENCIA\s+MB\s*/i,
  /^TRANSFERENCIA\s*-\s*/i,
  /^TRANSFERENCIA\s*/i,
  /^PAGAMENTO\s+SERVICOS?\s*/i,
  /^PAG\.\s*/i,
  /^DEBITO\s+DIRETO\s*/i,
  /^DD\s+/i, // direct debit: "DD CETELEM 31543417061 PT41100946"
];

// A movement spans three lines:
//
//   7.01  7.01                            <- posting date / value date, MONTH.DAY
//   COMPRA 2902 STEAM PURCHASE SEATTLE    <- description (may wrap)
//   34.99265.16                           <- amount AND balance, glued together
//
// Three things make this harder than it looks:
// - The date line carries no year. The only place the year appears is the
//   "EXTRATO DE 2026/07/01 A 2026/07/31" period header.
// - Amounts use "." as the decimal separator and a *space* for thousands
//   ("1 386.35"), not the Portuguese convention the other parsers use — so
//   types.ts's parsePtAmountToCents would read "34.99" as 3499 euros.
// - There is no sign, and no separator between the amount and the running
//   balance. DEBITO and CREDITO are separate columns in the PDF, and which
//   one a number sat in is exactly what text extraction destroys. The only
//   way to recover both the split and the direction is arithmetic — see
//   resolveAgainstBalance.
const AMOUNT = String.raw`\d{1,3}(?:[  ]\d{3})*\.\d{2}`;
const AMOUNT_ONLY = new RegExp(`^${AMOUNT}$`);
const DATE_LINE_RE = /^(\d{1,2})\.(\d{2})\s+(\d{1,2})\.(\d{2})$/;
const PERIOD_RE = /EXTRATO DE\s*\n?\s*(\d{4})\/(\d{2})\/\d{2}\s+A\s+\d{4}\/(\d{2})\/\d{2}/;
// The label and its amount may be glued or sit on separate lines; `\s*?`
// spans the newline in the second case without crossing any other text.
const OPENING_BALANCE_RE = new RegExp(String.raw`SALDO INICIAL\s*?(${AMOUNT})`);
const TABLE_START_RE = /^SALDO INICIAL/;
const TABLE_END_RE = /^SALDO FINAL/;

/** "34.99" / "1 386.35" -> integer cents. Dot is the *decimal* separator. */
function parseDotDecimalToCents(raw: string): number {
  const value = Number(raw.replace(/[  ]/g, ''));
  if (Number.isNaN(value)) throw new Error(`Could not parse amount: "${raw}"`);
  return Math.round(value * 100);
}

function cleanPayee(rawPayee: string): string {
  // Trailing bank references ("31543417061 PT41100946") differ per
  // transaction; leaving them in would defeat the payee->category memory.
  let payee = rawPayee.replace(/\s+\d{6,}(?:\s+[A-Z0-9]+)*$/, '').trim();
  for (const prefix of NOISE_PREFIXES) {
    const stripped = payee.replace(prefix, '');
    if (stripped !== payee) {
      payee = stripped.trim();
      break;
    }
  }
  return payee.replace(/\s{2,}/g, ' ').trim();
}

/**
 * Every way to cut `glued` into two well-formed amounts. Usually there is
 * exactly one — "34.99265.16" can only be 34.99 + 265.16, because "34.992"
 * has three decimals — but structure alone can never tell debit from
 * credit, so this is only the candidate list.
 */
function splitCandidates(glued: string): Array<{ amount: number; balance: number }> {
  const candidates: Array<{ amount: number; balance: number }> = [];
  for (let i = 1; i < glued.length; i++) {
    const amount = glued.slice(0, i);
    const balance = glued.slice(i);
    if (AMOUNT_ONLY.test(amount) && AMOUNT_ONLY.test(balance)) {
      candidates.push({ amount: parseDotDecimalToCents(amount), balance: parseDotDecimalToCents(balance) });
    }
  }
  return candidates;
}

/** The splits of `glued` that reconcile against the previous balance. */
function resolveAgainstBalance(
  glued: string,
  previous: number,
): Array<{ amountCents: number; balance: number }> {
  const resolved: Array<{ amountCents: number; balance: number }> = [];
  for (const { amount, balance } of splitCandidates(glued)) {
    if (previous - amount === balance) resolved.push({ amountCents: -amount, balance });
    else if (previous + amount === balance) resolved.push({ amountCents: amount, balance });
  }
  return resolved;
}

export const activoBankParser: BankParser = {
  bankId: 'activobank',

  canParse(fullText: string): boolean {
    if (!/activo\s*bank/i.test(fullText)) return false;
    // A statement that merely *mentions* ActivoBank — a transfer payee on
    // another bank's statement — is not an ActivoBank statement. Require a
    // marker from its own movement table or its issuer line.
    return (
      /banco\s*activobank/i.test(fullText) ||
      /DESCRITIVO\s*DEBITO\s*CREDITO\s*SALDO/i.test(fullText)
    );
  },

  parse(fullText: string): RawTransaction[] {
    const period = fullText.match(PERIOD_RE);
    if (!period) {
      // Without the period header there is no year anywhere in the table,
      // so nothing can be dated. Loud failure beats inventing a year.
      console.warn('[activobank] no "EXTRATO DE yyyy/mm/dd A yyyy/mm/dd" period header — cannot date movements');
      return [];
    }
    const startYear = Number(period[1]);
    const startMonth = Number(period[2]);

    const opening = fullText.match(OPENING_BALANCE_RE);
    if (!opening) {
      console.warn('[activobank] no readable SALDO INICIAL — movement direction cannot be resolved');
      return [];
    }
    if ((fullText.match(/^SALDO INICIAL/gm) ?? []).length > 1) {
      // "EXTRATO COMBINADO" can carry several accounts. We only read the
      // first table; say so rather than importing a silent subset.
      console.warn('[activobank] statement contains more than one account table — only the first was parsed');
    }

    const blocks = scanMovementBlocks(fullText, {
      dateLine: DATE_LINE_RE,
      startAt: TABLE_START_RE,
      endAt: TABLE_END_RE,
    });

    const transactions: RawTransaction[] = [];
    let balance = parseDotDecimalToCents(opening[1]);

    for (const block of blocks) {
      const result = readMovement(block, balance);
      if (!result) continue;
      balance = result.balance;
      if (!result.movement) continue;

      const month = Number(block.date[1]);
      const day = Number(block.date[2]);
      // Statements may span a year boundary (December -> January): a month
      // before the period's first month belongs to the following year.
      const year = month < startMonth ? startYear + 1 : startYear;
      transactions.push({
        date: `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
        payee: cleanPayee(result.movement.description),
        amountCents: result.movement.amountCents,
        rawLine: [block.dateLine, ...block.lines].join(' ').replace(/\s+/g, ' '),
      });
    }

    return transactions;
  },
};

/**
 * Reads one block against the running balance. Always reports the balance to
 * carry forward, so a single unreadable row re-syncs the chain instead of
 * breaking every later one; `movement` is absent when the row itself could
 * not be recovered, and `undefined` when not even the balance could be.
 */
function readMovement(
  block: MovementBlock,
  balance: number,
): { balance: number; movement?: { description: string; amountCents: number } } | undefined {
  if (block.lines.length === 0) {
    console.warn(`[activobank] date line with no movement body: "${block.dateLine}"`);
    return undefined;
  }
  const glued = block.lines[block.lines.length - 1];
  const description = block.lines.slice(0, -1).join(' ').replace(/\s+/g, ' ').trim();

  const resolved = resolveAgainstBalance(glued, balance);
  if (resolved.length === 1) {
    return {
      balance: resolved[0].balance,
      movement: { description, amountCents: resolved[0].amountCents },
    };
  }

  console.warn(
    `[activobank] could not resolve amount/balance in "${glued}" against balance ${balance} ` +
      `(${resolved.length} arithmetic candidates) — skipping "${description}"`,
  );
  const candidates = splitCandidates(glued);
  return candidates.length === 1 ? { balance: candidates[0].balance } : undefined;
}
