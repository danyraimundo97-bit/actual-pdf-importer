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
  | 'MISSING_FIELD'
  | 'NO_BUDGET_SELECTED'
  | 'UNAUTHORIZED'
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
