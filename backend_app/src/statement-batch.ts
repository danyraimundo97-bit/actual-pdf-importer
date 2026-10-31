import { ErrorCode, ImporterError } from './errors';

/**
 * Parsing several statements in one request.
 *
 * The whole point of a batch is that one bad file must not cost the user the
 * other nine, so there is no all-or-nothing outcome here: every file gets its
 * own result, and a failure is data (`status: 'failed'` with a `code`) rather
 * than an exception. The caller reports HTTP 200 for any well-formed request
 * and the client branches per file — see the route in server.ts.
 */

/** Just the multer fields used, so this module needs no multer types. */
export interface UploadedStatement {
  originalname: string;
  buffer: Buffer;
}

export interface ParsedStatement<T> {
  bankId: string;
  transactions: T[];
}

export type StatementResult<T> =
  | { filename: string; status: 'parsed'; bankId: string; transactions: T[] }
  /** `bankId` is present when the bank was identified but the parse still failed. */
  | { filename: string; status: 'failed'; code: ErrorCode; error: string; bankId?: string };

/**
 * Parses each file independently.
 *
 * `parseOne` MUST stamp dedupe ids per statement (see assignImportedIds in
 * actual.ts) — which it does by being the same per-file helper POST /parse
 * uses. Stamping across a whole batch instead would renumber occurrences
 * relative to the batch, so a movement appearing in two overlapping
 * statements would get two different ids and import twice.
 *
 * Deliberately sequential: in PARSER_MODE=ai each file is a provider call,
 * and firing a whole batch concurrently is how you hit a rate limit. Local
 * parsing is CPU-bound in a single-threaded runtime, so concurrency would
 * buy nothing there either.
 */
export async function parseStatements<T>(
  files: readonly UploadedStatement[],
  parseOne: (buffer: Buffer) => Promise<ParsedStatement<T>>,
): Promise<Array<StatementResult<T>>> {
  const results: Array<StatementResult<T>> = [];

  for (const file of files) {
    const filename = file.originalname;
    try {
      const { bankId, transactions } = await parseOne(file.buffer);
      if (transactions.length === 0) {
        results.push({
          filename,
          status: 'failed',
          code: 'NO_TRANSACTIONS',
          error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
          bankId,
        });
        continue;
      }
      results.push({ filename, status: 'parsed', bankId, transactions });
    } catch (err) {
      if (err instanceof ImporterError) {
        results.push({ filename, status: 'failed', code: err.code, error: err.message });
        continue;
      }
      // Unexpected: log the real error, hand the client the same opaque
      // message a single-file parse would get. Never the stack.
      console.error(`[batch] unexpected failure parsing "${filename}"`, err);
      results.push({
        filename,
        status: 'failed',
        code: 'INTERNAL_ERROR',
        error: 'Internal error while parsing the statement.',
      });
    }
  }

  return results;
}

/** Counts for the batch response, so the client doesn't have to derive them. */
export function summarize<T>(results: ReadonlyArray<StatementResult<T>>): {
  parsed: number;
  failed: number;
  transactions: number;
} {
  let parsed = 0;
  let failed = 0;
  let transactions = 0;
  for (const result of results) {
    if (result.status === 'parsed') {
      parsed++;
      transactions += result.transactions.length;
    } else {
      failed++;
    }
  }
  return { parsed, failed, transactions };
}
