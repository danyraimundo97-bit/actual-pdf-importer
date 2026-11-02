/**
 * Typed, machine-readable errors for the HTTP layer. Every route handler
 * that can fail in an expected way (bad bank, no transactions, wrong PDF
 * password, ...) should throw one of these rather than a plain Error, and
 * server.ts maps `code` straight into the JSON response so the front end
 * can branch on `code`, never on the English `error` text.
 */

export type ErrorCode =
  | 'BANK_UNRECOGNIZED'
  | 'NO_TRANSACTIONS'
  | 'PDF_PASSWORD_REQUIRED'
  | 'PDF_PASSWORD_INCORRECT'
  | 'PDF_UNREADABLE'
  | 'MISSING_FIELD'
  | 'NO_BUDGET_SELECTED'
  | 'BUDGET_NOT_FOUND'
  | 'UNAUTHORIZED'
  | 'AUTH_REQUIRED'
  | 'TOO_MANY_FILES'
  | 'FILE_TOO_LARGE'
  | 'BATCH_TOO_LARGE'
  | 'INTERNAL_ERROR';

export class ImporterError extends Error {
  readonly code: ErrorCode;
  readonly status: number;

  constructor(code: ErrorCode, message: string, status = 422) {
    super(message);
    this.name = 'ImporterError';
    this.code = code;
    this.status = status;
  }
}

export class UnrecognizedBankError extends ImporterError {
  constructor() {
    super('BANK_UNRECOGNIZED', 'Could not identify which bank this statement is from.', 422);
  }
}

/**
 * A route that hands out or changes something sensitive (e.g. GET /logs)
 * while the backend runs with no IMPORT_TOKEN: refused outright, since
 * anyone on the network could otherwise call it.
 */
export class AuthRequiredError extends ImporterError {
  constructor() {
    super('AUTH_REQUIRED', 'This needs IMPORT_TOKEN to be set on the backend.', 403);
  }
}

/** pdf.js's PasswordException code 1 — the file is encrypted and no password was supplied. */
export class PdfPasswordRequiredError extends ImporterError {
  constructor() {
    super('PDF_PASSWORD_REQUIRED', 'This statement is password-protected.', 422);
  }
}

/** pdf.js's PasswordException code 2 — a password was supplied but it's wrong. */
export class PdfPasswordIncorrectError extends ImporterError {
  constructor() {
    super('PDF_PASSWORD_INCORRECT', 'Wrong password for this statement.', 422);
  }
}

/**
 * pdf.js's InvalidPDFException — the upload isn't a PDF at all, or is
 * corrupt. A user mistake, not a server fault: without this it surfaced as
 * INTERNAL_ERROR plus a stack trace in the log, which matters more now that
 * one stray file can ride along in a batch.
 */
export class PdfUnreadableError extends ImporterError {
  constructor() {
    super('PDF_UNREADABLE', 'This file is not a readable PDF.', 422);
  }
}

/**
 * No budget to work with: neither the request nor ACTUAL_BUDGET_SYNC_ID in
 * .env named one. Its own code because this is the ordinary first-run state
 * — without it an empty sync id reaches downloadBudget() and the client
 * gets an opaque SDK failure instead of "pick a budget".
 */
export class NoBudgetSelectedError extends ImporterError {
  constructor() {
    super(
      'NO_BUDGET_SELECTED',
      'No budget selected: pass "budgetSyncId" or set ACTUAL_BUDGET_SYNC_ID in the backend .env.',
      400,
    );
  }
}

/**
 * The requested sync id isn't a budget on the Actual server — typically a
 * stale choice saved by the app, or an ACTUAL_BUDGET_SYNC_ID copied from a
 * different server. The client should send the user back to pick a budget.
 */
export class BudgetNotFoundError extends ImporterError {
  constructor(syncId: string) {
    super(
      'BUDGET_NOT_FOUND',
      `Budget "${syncId}" was not found on the Actual server. Pick the budget again in Settings ` +
        '(or fix ACTUAL_BUDGET_SYNC_ID in the backend .env).',
      404,
    );
  }
}

/**
 * The ways a multipart upload can be rejected before any parsing (see
 * upload.ts). They exist so multer's own MulterError — which would otherwise
 * escape as an HTML 500 and break the `code`-based contract — maps onto a
 * typed error like every other expected failure. Each one is a different fix
 * for the client: send fewer files, shrink one file, or split the request.
 */
export class TooManyFilesError extends ImporterError {
  /** `received` is a lower bound when the upload was cut off before the end. */
  constructor(max: number, received: number, receivedIsLowerBound = false, hint = '') {
    const count = receivedIsLowerBound ? `more than ${received}` : `${received}`;
    super(
      'TOO_MANY_FILES',
      `Too many files: received ${count}, the maximum per request is ${max}.${hint ? ` ${hint}` : ''}`,
      400,
    );
  }
}

export class FileTooLargeError extends ImporterError {
  constructor(maxBytes: number) {
    super('FILE_TOO_LARGE', `A file exceeds the ${formatBytes(maxBytes)} per-file limit.`, 413);
  }
}

/** Every file is under the per-file limit, but together they are too much for one request. */
export class BatchTooLargeError extends ImporterError {
  constructor(maxBytes: number, receivedBytes: number) {
    super(
      'BATCH_TOO_LARGE',
      `The upload is ${formatBytes(receivedBytes)} in total, over the ${formatBytes(maxBytes)} per-request limit. ` +
        'Split the statements over several requests.',
      413,
    );
  }
}

export function formatBytes(bytes: number): string {
  const trim = (n: number) => (Number.isInteger(n) ? `${n}` : n.toFixed(1));
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${trim(bytes / 1024)}KB`;
  return `${trim(bytes / (1024 * 1024))}MB`;
}
