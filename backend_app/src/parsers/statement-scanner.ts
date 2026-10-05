/**
 * Shared line scanner for the bank statement parsers.
 *
 * Every statement pdf-parse hands us has the same coarse shape: a movement
 * starts at a date line and owns every line after it until the next date
 * line, because long descriptions wrap and the amount can land on a line of
 * its own. Each bank also repeats a page header or footer that can fall in
 * the middle of a movement.
 *
 * That walk, and in particular the guard that stops a mis-detected
 * header/footer from swallowing the rest of the statement, is identical for
 * every bank — it lives here once rather than in each parser.
 *
 * What is *not* shared is reading a block: the number formats, where the
 * year comes from and how the direction of a movement is recovered differ
 * fundamentally per bank. Parsers keep that themselves.
 */

export interface MovementBlock {
  /** The date line verbatim, for composing `RawTransaction.rawLine`. */
  dateLine: string;
  /** The date line's match, so a parser can read its own capture groups. */
  date: RegExpMatchArray;
  /** Trimmed, non-empty lines belonging to this movement. */
  lines: string[];
}

export interface ScanConfig {
  /** Starts a new movement. Its capture groups are handed back untouched. */
  dateLine: RegExp;
  /** Ignore everything before this line matches. Omit to scan from the top. */
  startAt?: RegExp;
  /** Stop at the first line that matches. Omit to scan to the end. */
  endAt?: RegExp;
  /** A repeated page header/footer to skip, as [entering, leaving]. */
  skipRegion?: readonly [RegExp, RegExp];
}

export function scanMovementBlocks(fullText: string, config: ScanConfig): MovementBlock[] {
  const { dateLine, startAt, endAt, skipRegion } = config;
  const blocks: MovementBlock[] = [];
  let current: MovementBlock | undefined;
  /** The marker still being waited for; cleared once scanning has begun. */
  let awaiting = startAt;
  let inRegion = false;

  for (const rawLine of fullText.split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;

    if (awaiting) {
      if (awaiting.test(line)) awaiting = undefined;
      continue;
    }
    if (endAt?.test(line)) break;

    const date = line.match(dateLine);

    if (skipRegion) {
      if (inRegion) {
        if (skipRegion[1].test(line)) {
          inRegion = false;
          continue;
        }
        // Both banks' region markers are heuristics that a wrapped
        // description can trip (moey's page code looks exactly like the
        // payee "IFTHEN25"). A date line is unambiguous proof the region
        // has ended, so let it win: a missed exit marker then costs one
        // movement, never the rest of the statement.
        if (!date) continue;
        inRegion = false;
      }
      if (skipRegion[0].test(line)) {
        inRegion = true;
        continue;
      }
    }

    if (date) {
      current = { dateLine: line, date, lines: [] };
      blocks.push(current);
    } else if (current) {
      current.lines.push(line);
    }
  }

  return blocks;
}
