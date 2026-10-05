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
  | 'UNAUTHORIZED'
  | 'TOO_MANY_FILES'
  | 'FILE_TOO_LARGE'
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
 * The two ways a multipart upload can be rejected before any parsing. Both
 * exist so multer's own MulterError — which would otherwise escape as an
 * HTML 500 and break the `code`-based contract — maps onto a typed error
 * like every other expected failure.
 */
export class TooManyFilesError extends ImporterError {
  constructor(max: number) {
    super(
      'TOO_MANY_FILES',
      `Too many files in one request (maximum ${max}), or a file was sent under an unexpected field name.`,
      400,
    );
  }
}

export class FileTooLargeError extends ImporterError {
  constructor(maxBytes: number) {
    super('FILE_TOO_LARGE', `A file exceeds the ${Math.round(maxBytes / (1024 * 1024))}MB per-file limit.`, 413);
  }
}
