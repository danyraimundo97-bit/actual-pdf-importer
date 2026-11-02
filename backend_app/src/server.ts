import 'dotenv/config';
import crypto from 'crypto';
import express, { NextFunction, Request, Response } from 'express';
import { processStatement, PARSER_MODE } from './index';
import {
  AuthRequiredError,
  ConnectionLockedError,
  ImporterError,
  InvalidFieldError,
  NoBudgetSelectedError,
} from './errors';
import {
  defaultConnectionFile,
  fileConnectionStore,
  normalizeServerUrl,
  probeActualServer,
  resolveConnection,
} from './actual-connection';
import { debugFromEnv, initLogFile, logDir, logger, readRecentLogLines } from './logger';
import { requestLog, requestLogger } from './request-log';
import { receiveFiles } from './upload';
import { recordRemovals } from './removal-log';
import { parseStatements, summarize } from './statement-batch';
import { getAiProvider } from './parsers/ai-providers';
import {
  assignImportedIds,
  ensureCategory,
  importToActual,
  undoImport,
  learnCategoriesFromActual,
  listAccounts,
  listBudgets,
  listCategoryGroups,
} from './actual';
import { actualSdkAdapter, isHandledSdkError } from './actual-adapter';
import { getDashboard } from './dashboard';
import { addManualTransaction, getQuickAddOptions, parseManualTransaction } from './transactions';
import { getAccountPage, parseLimit } from './account-page';
import { getBudgetMonth, parseMonth } from './budget-month';
import { BudgetRef, createBudgetSession } from './budget-session';
import {
  clearCategoryMappings,
  deleteCategoryMapping,
  listCategoryMappings,
  lookupCategory,
  rememberCategory,
} from './categorydb';

const log = logger.child({ area: 'app' });

const app = express();
// First, so every request (rejected ones included) gets an id and a log line.
app.use(requestLogger());
app.use(express.json());

// The Actual server is optional (actual-connection.ts): from .env (locked),
// from what the app saved, or none. Server credentials don't vary per
// request; they change only through PUT/DELETE /actual/connection, which
// reconfigure the session. Only the budget choice is per-request.
const connectionStore = fileConnectionStore(defaultConnectionFile());
const initialConnection = resolveConnection(process.env, connectionStore);
const CONNECTION_LOCKED = initialConnection.locked;
const ACTUAL_DATA_DIR = process.env.ACTUAL_DATA_DIR || './actual-cache';
let actualServerUrl: string | null = initialConnection.config?.serverURL ?? null;
let actualHasPassword = Boolean(initialConnection.config?.password);
const budgetSession = createBudgetSession(initialConnection.config, actualSdkAdapter, {
  // Reads reuse the local copy for this long before syncing again; writes
  // always sync (budget-session.ts).
  syncIntervalMs: Number(process.env.SYNC_INTERVAL_MS ?? 5000),
});
logger.info(
  { area: 'actual', configured: initialConnection.config !== null, locked: CONNECTION_LOCKED },
  initialConnection.config ? `Actual server: ${initialConnection.config.serverURL}` : 'No Actual server connected',
);

const DEFAULT_BUDGET_SYNC_ID = process.env.ACTUAL_BUDGET_SYNC_ID ?? '';

/**
 * The budget a request is scoped to, honoring a per-request override (the
 * budget picker in Settings) and falling back to the .env default. May be
 * empty: that's a legitimate state for the category memory, which has an
 * unscoped bucket for mappings made before scoping existed (categorydb.ts).
 */
function resolveBudgetScope(budgetSyncId?: unknown): string {
  const override = typeof budgetSyncId === 'string' ? budgetSyncId.trim() : '';
  return override || DEFAULT_BUDGET_SYNC_ID;
}

/**
 * Same choice, but as a reference to a budget Actual must actually open —
 * so here an empty sync id is not a valid answer and gets rejected with a
 * code the client can branch on, rather than reaching downloadBudget('').
 */
function resolveBudgetRef(budgetSyncId?: unknown, budgetPassword?: unknown): BudgetRef {
  const syncId = resolveBudgetScope(budgetSyncId);
  if (!syncId) throw new NoBudgetSelectedError();
  return {
    syncId,
    budgetPassword: typeof budgetPassword === 'string' && budgetPassword ? budgetPassword : undefined,
  };
}

/**
 * Maps an error to its JSON response. Expected failures (a typed
 * ImporterError) are logged at warn with their code; anything else is a
 * bug, logged at error with its stack. Both responses carry the request id,
 * so a failure the user sees can be found in this log.
 */
function sendImporterError(res: Response, err: unknown, fallbackMessage: string): void {
  const requestId = res.locals.requestId as string | undefined;
  if (err instanceof ImporterError) {
    requestLog(res).warn({ code: err.code, status: err.status }, err.message);
    res.status(err.status).json({ error: err.message, code: err.code, requestId });
    return;
  }
  requestLog(res).error({ err }, fallbackMessage);
  res.status(500).json({ error: fallbackMessage, code: 'INTERNAL_ERROR', requestId });
}

// --- Auth ------------------------------------------------------------------
//
// A shared secret, not real auth (no users/sessions) — just enough that
// "anyone on the LAN can write to my budget" isn't the default. GET
// /health stays open so the app can always tell "backend unreachable"
// apart from "backend reachable, token rejected".

const IMPORT_TOKEN = process.env.IMPORT_TOKEN;
if (!IMPORT_TOKEN) {
  logger.warn(
    { area: 'auth' },
    'IMPORT_TOKEN is not set — running with NO authentication. ' +
      'Anyone who can reach this port can read/write your budget. Set IMPORT_TOKEN in .env to require the X-Import-Token header.',
  );
}

app.use((req: Request, res: Response, next: NextFunction) => {
  if (req.path === '/health' || !IMPORT_TOKEN) return next();

  const provided = req.header('X-Import-Token') ?? '';
  const expected = IMPORT_TOKEN;
  const ok =
    provided.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected));

  if (!ok) {
    // The address only: never what was sent as the token.
    requestLog(res).warn({ ip: req.ip, tokenSent: provided.length > 0 }, 'Rejected: missing or invalid token');
    return res.status(401).json({ error: 'Missing or invalid X-Import-Token header.', code: 'UNAUTHORIZED' });
  }
  return next();
});

// --- Parsing / importing -----------------------------------------------

/** How many statements one POST /parse may carry. */
const MAX_PARSE_FILES = 20;

// Upload handling lives in upload.ts: memory storage only (the PDF never
// touches disk, per the "no residual copies" privacy goal), per-file and
// per-request size caps, and a log line whenever an upload is rejected.
//
// POST /parse takes either field name, so one-file clients sending
// "statement" and multi-file clients sending "statements" both just work.
const receiveStatements = receiveFiles({ fields: ['statement', 'statements'], maxFiles: MAX_PARSE_FILES });
const receiveStatement = receiveFiles({
  fields: ['statement'],
  maxFiles: 1,
  tooManyHint: 'Use POST /parse to parse several statements, then POST /import/confirm.',
});

function readPassword(body: Record<string, unknown>): string | undefined {
  return typeof body.password === 'string' && body.password ? body.password : undefined;
}

/**
 * Parses one statement and enriches it the way clients expect: a dedupe id
 * per transaction (so edits on the review screen don't break re-import
 * dedupe) plus the suggested category from local memory.
 *
 * Used for every file POST /parse receives, one or many, so
 * `assignImportedIds` runs **once per statement**.
 * Stamping a whole batch at once would number occurrences relative to the
 * batch, giving a movement that appears in two overlapping statements two
 * different ids, which re-imports it as a duplicate.
 */
async function parseAndEnrich(buffer: Buffer, password: string | undefined, budgetScope: string) {
  const { bankId, transactions } = await processStatement(buffer, password);
  const lookupLog = logger.child({ area: 'categories' });
  const enriched = assignImportedIds(transactions).map((tx) => {
    const match = lookupCategory(tx.payee, budgetScope);
    lookupLog.debug(
      { payee: tx.payee, scope: budgetScope || '(unscoped)', hit: Boolean(match), categoryId: match?.categoryId, importedId: tx.importedId },
      'Category lookup',
    );
    return {
      ...tx,
      suggestedCategoryId: match?.categoryId,
      suggestedCategoryName: match?.categoryName,
    };
  });
  return { bankId, transactions: enriched };
}

/**
 * Parses one or more statements WITHOUT touching Actual. The front end
 * reviews and edits the result, then confirms with POST /import/confirm.
 * Multipart field: "statement" or "statements", repeated for several files.
 *
 * The number of files received picks the response shape:
 *
 * - **One file** → `{ bankId, transactions }`, and a failure is an HTTP error
 *   with its `code` (e.g. 422 NO_TRANSACTIONS) — the shape single-statement
 *   clients like the mobile app rely on.
 * - **Several files** → `{ files: [...], parsed, failed, transactions }` with
 *   200 even when some failed: partial success is the normal outcome of a
 *   batch, so each file carries its own `status` and `code` and the client
 *   decides per file. A request-level problem (no files, too many, too big)
 *   is still a 4xx.
 *
 * One `password` applies to every file. Statements needing a different one
 * come back as PDF_PASSWORD_REQUIRED/INCORRECT and can be re-sent alone —
 * keyed-by-filename passwords would be unreliable anyway, since statements
 * get renamed in transit.
 */
app.post('/parse', receiveStatements, async (req: Request, res: Response) => {
  const files = Array.isArray(req.files) ? req.files : [];
  if (files.length === 0) {
    return res.status(400).json({
      error: 'No file uploaded. Expected one or more multipart fields named "statement" or "statements".',
      code: 'MISSING_FIELD',
    });
  }

  const password = readPassword(req.body);
  const budgetScope = resolveBudgetScope(req.body.budgetSyncId);

  if (files.length > 1) {
    // parseStatements never throws for a per-file failure, so there is no
    // try/catch here: anything escaping it is a genuine bug, and the global
    // error handler turns that into a 500.
    const results = await parseStatements(files, (buffer) => parseAndEnrich(buffer, password, budgetScope));
    return res.json({ files: results, ...summarize(results) });
  }

  try {
    const { bankId, transactions } = await parseAndEnrich(files[0].buffer, password, budgetScope);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        code: 'NO_TRANSACTIONS',
        bankId,
      });
    }

    return res.json({ bankId, transactions });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while parsing the statement.');
  }
});

/**
 * Imports a (possibly user-edited) transaction list that already went
 * through POST /parse. No file upload here — JSON only.
 */
app.post('/import/confirm', async (req: Request, res: Response) => {
  const { accountId, transactions, budgetSyncId, budgetPassword } = req.body ?? {};

  if (!accountId) {
    return res
      .status(400)
      .json({ error: 'Missing required field "accountId" (the Actual account to import into).', code: 'MISSING_FIELD' });
  }
  if (!Array.isArray(transactions) || transactions.length === 0) {
    return res.status(400).json({ error: 'Missing or empty "transactions" array.', code: 'MISSING_FIELD' });
  }

  try {
    const result = await importToActual(
      budgetSession,
      resolveBudgetRef(budgetSyncId, budgetPassword),
      accountId,
      transactions,
    );
    requestLog(res).info(
      { accountId, sent: transactions.length, added: result.added, updated: result.updated, categorized: result.categorized },
      'Import confirmed',
    );
    return res.json(result);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while importing to Actual.');
  }
});

/**
 * Undoes one import as a soft delete: the transactions it added get amount
 * 0.00 and a "removed" note in Actual (nothing is deleted there), and the
 * originals are kept in the backend's removal log. Body: { accountId,
 * transactionIds } where transactionIds is the `addedIds` that import's
 * POST /import/confirm returned. See undoImport for why a wrong id can't
 * touch anything this app didn't import.
 */
app.post('/import/undo', async (req: Request, res: Response) => {
  const { accountId, transactionIds, budgetSyncId, budgetPassword } = req.body ?? {};

  if (!accountId) {
    return res
      .status(400)
      .json({ error: 'Missing required field "accountId" (the account the import went into).', code: 'MISSING_FIELD' });
  }
  if (
    !Array.isArray(transactionIds) ||
    transactionIds.length === 0 ||
    !transactionIds.every((id) => typeof id === 'string' && id)
  ) {
    return res.status(400).json({
      error: 'Missing or invalid "transactionIds": the addedIds returned by POST /import/confirm.',
      code: 'MISSING_FIELD',
    });
  }

  try {
    const budget = resolveBudgetRef(budgetSyncId, budgetPassword);
    const { removed, skipped, softDeleted } = await undoImport(budgetSession, budget, accountId, transactionIds);
    const removedAt = new Date().toISOString();
    recordRemovals(softDeleted.map((t) => ({ ...t, budgetSyncId: budget.syncId, accountId, removedAt })));
    requestLog(res).info({ accountId, removed, skipped }, 'Import removed (soft delete)');
    return res.json({ removed, skipped });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while undoing the import.');
  }
});

/**
 * Kept unchanged for backwards compatibility: parse-and-import in one
 * shot, no review step. New clients should prefer POST /parse followed by
 * POST /import/confirm.
 */
app.post('/import', receiveStatement, async (req: Request, res: Response) => {
  if (!req.file) {
    return res
      .status(400)
      .json({ error: 'No file uploaded. Expected multipart field "statement".', code: 'MISSING_FIELD' });
  }

  const accountId = req.body.accountId as string | undefined;
  if (!accountId) {
    return res
      .status(400)
      .json({ error: 'Missing required field "accountId" (the Actual account to import into).', code: 'MISSING_FIELD' });
  }

  const password = typeof req.body.password === 'string' && req.body.password ? req.body.password : undefined;

  try {
    const budget = resolveBudgetRef(req.body.budgetSyncId, req.body.budgetPassword);
    const { bankId, transactions } = await processStatement(req.file.buffer, password);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        code: 'NO_TRANSACTIONS',
        bankId,
      });
    }

    const result = await importToActual(budgetSession, budget, accountId, transactions);

    return res.json({
      bankId,
      parsed: transactions.length,
      added: result.added,
      updated: result.updated,
      categorized: result.categorized,
    });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while processing the statement.');
  }
});

// --- Actual metadata (accounts / categories / budgets) ------------------

app.get('/accounts', async (req: Request, res: Response) => {
  try {
    const accounts = await listAccounts(budgetSession, resolveBudgetRef(req.query.budgetSyncId));
    res.json({ accounts });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual accounts.');
  }
});

app.get('/actual/categories', async (req: Request, res: Response) => {
  try {
    const groups = await listCategoryGroups(budgetSession, resolveBudgetRef(req.query.budgetSyncId));
    res.json({ groups });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual categories.');
  }
});

/**
 * Makes sure a category exists in Actual (the app's "Match your categories"
 * → "Create in Actual"). Idempotent by name; see ensureCategory.
 */
app.post('/actual/categories', async (req: Request, res: Response) => {
  const { budgetSyncId, budgetPassword, groupName, name, isIncome } = req.body ?? {};
  for (const [field, value] of [
    ['name', name],
    ['groupName', groupName],
  ] as const) {
    if (typeof value !== 'string' || !value.trim()) {
      return sendImporterError(res, new InvalidFieldError(field, 'must be a non-empty string'), '');
    }
    if (value.trim().length > 100) {
      return sendImporterError(res, new InvalidFieldError(field, 'must be at most 100 characters'), '');
    }
  }
  try {
    const result = await ensureCategory(budgetSession, resolveBudgetRef(budgetSyncId, budgetPassword), {
      groupName,
      name,
      isIncome: isIncome === true,
    });
    logger.info({ categoryId: result.id, created: result.created }, 'Category ensured in Actual');
    res.status(result.created ? 201 : 200).json(result);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while creating an Actual category.');
  }
});

app.get('/budgets', async (_req: Request, res: Response) => {
  try {
    const budgets = await listBudgets(budgetSession);
    res.json({ budgets });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual budgets.');
  }
});

// Read-only metrics for the app's dashboard (see src/dashboard.ts).
// `months` is clamped to 1..24 so a typo can't ask for a decade of buckets.
app.get('/dashboard', async (req: Request, res: Response) => {
  const requested = Number.parseInt(String(req.query.months ?? '6'), 10);
  const months = Number.isFinite(requested) ? Math.min(Math.max(requested, 1), 24) : 6;
  try {
    const dashboard = await getDashboard(budgetSession, resolveBudgetRef(req.query.budgetSyncId), { months });
    res.json(dashboard);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while building the dashboard.');
  }
});

// --- Everyday app screens (one call per screen) --------------------------

/**
 * Quick add: one transaction typed in the app. Safe to retry with the same
 * clientId (see transactions.ts). Teaches the category memory too, so the
 * payee is pre-categorized next time, in a statement or here.
 */
app.post('/transactions', async (req: Request, res: Response) => {
  try {
    const input = parseManualTransaction(req.body);
    const budget = resolveBudgetRef(req.body?.budgetSyncId, req.body?.budgetPassword);
    const result = await addManualTransaction(budgetSession, budget, input);
    if (input.payeeName && input.categoryId) {
      rememberCategory(input.payeeName, input.categoryId, undefined, budget.syncId);
    }
    requestLog(res).info(
      { accountId: input.accountId, id: result.id, created: result.created, categorized: Boolean(input.categoryId) },
      result.created ? 'Transaction added' : 'Transaction already added (retry)',
    );
    res.status(result.created ? 201 : 200).json(result);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while adding the transaction.');
  }
});

app.get('/quick-add/options', async (req: Request, res: Response) => {
  try {
    res.json(await getQuickAddOptions(budgetSession, resolveBudgetRef(req.query.budgetSyncId)));
  } catch (err) {
    sendImporterError(res, err, 'Internal error while loading the quick-add options.');
  }
});

/** One account's balance and transactions, newest first; `before` = the previous page's nextCursor. */
app.get('/accounts/:id/transactions', async (req: Request, res: Response) => {
  try {
    const before = typeof req.query.before === 'string' && req.query.before ? req.query.before : undefined;
    const page = await getAccountPage(budgetSession, resolveBudgetRef(req.query.budgetSyncId), req.params.id, {
      before,
      limit: parseLimit(req.query.limit),
    });
    res.json(page);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while loading the account.');
  }
});

/** This month's budget (or `month=YYYY-MM`): budgeted, spent and left per category. */
app.get('/budget-month', async (req: Request, res: Response) => {
  try {
    const month = parseMonth(req.query.month);
    res.json(await getBudgetMonth(budgetSession, resolveBudgetRef(req.query.budgetSyncId), month));
  } catch (err) {
    sendImporterError(res, err, 'Internal error while loading the budget.');
  }
});

app.get('/config', (_req: Request, res: Response) => {
  const aiInUse = PARSER_MODE === 'ai' || PARSER_MODE === 'both';
  const provider = aiInUse ? getAiProvider() : undefined;
  res.json({
    parserMode: PARSER_MODE,
    aiProvider: provider?.name,
    aiConfigured: provider ? provider.isConfigured() : false,
    defaultBudgetSyncId: DEFAULT_BUDGET_SYNC_ID || undefined,
    actual: { configured: budgetSession.isConfigured(), locked: CONNECTION_LOCKED },
  });
});

// --- Actual connection (optional; see src/actual-connection.ts) ---------

function connectionStatus(serverVersion?: string | null) {
  return {
    configured: budgetSession.isConfigured(),
    locked: CONNECTION_LOCKED,
    serverUrl: actualServerUrl ?? undefined,
    hasPassword: actualHasPassword,
    ...(serverVersion ? { serverVersion } : {}),
  };
}

/** Changing where the backend sends budget data needs a token and an unlocked connection. */
function assertConnectionEditable() {
  if (!IMPORT_TOKEN) throw new AuthRequiredError();
  if (CONNECTION_LOCKED) throw new ConnectionLockedError();
}

app.get('/actual/connection', (_req: Request, res: Response) => {
  res.json(connectionStatus());
});

/**
 * Tests the server (reachable, recent enough, password accepted) and only
 * then saves it and points the session at it. No restart needed.
 */
app.put('/actual/connection', async (req: Request, res: Response) => {
  try {
    assertConnectionEditable();
    const serverUrl = normalizeServerUrl(req.body?.serverUrl);
    const password = typeof req.body?.password === 'string' ? req.body.password : '';
    const { version } = await probeActualServer(serverUrl, password);
    connectionStore.write({ serverUrl, password });
    await budgetSession.reconfigure({ serverURL: serverUrl, password, dataDir: ACTUAL_DATA_DIR });
    actualServerUrl = serverUrl;
    actualHasPassword = password !== '';
    requestLog(res).info({ serverUrl, serverVersion: version }, 'Actual server connected');
    return res.json(connectionStatus(version));
  } catch (err) {
    sendImporterError(res, err, 'Internal error while connecting to Actual.');
  }
});

/**
 * Disconnects: the backend keeps running without Actual. The downloaded
 * budget cache in ACTUAL_DATA_DIR is left in place (the next connection
 * re-downloads what it needs anyway).
 */
app.delete('/actual/connection', async (_req: Request, res: Response) => {
  try {
    assertConnectionEditable();
    connectionStore.clear();
    await budgetSession.reconfigure(null);
    actualServerUrl = null;
    actualHasPassword = false;
    requestLog(res).info('Actual server disconnected');
    return res.json(connectionStatus());
  } catch (err) {
    sendImporterError(res, err, 'Internal error while disconnecting from Actual.');
  }
});

// --- Category memory (see src/categorydb.ts) ---------------------------

app.get('/categories', (req: Request, res: Response) => {
  const budgetSyncId = resolveBudgetScope(req.query.budgetSyncId);
  res.json({ mappings: listCategoryMappings(budgetSyncId) });
});

app.post('/categories', (req: Request, res: Response) => {
  const { payee, categoryId, categoryName, budgetSyncId } = req.body ?? {};
  if (!payee || !categoryId) {
    return res.status(400).json({ error: 'Both "payee" and "categoryId" are required.', code: 'MISSING_FIELD' });
  }
  rememberCategory(payee, categoryId, categoryName, resolveBudgetScope(budgetSyncId));
  res.status(204).end();
});

/** Forgets every mapping of the budget in scope. Answers how many were removed. */
app.delete('/categories', (req: Request, res: Response) => {
  const budgetSyncId = resolveBudgetScope(req.query.budgetSyncId);
  res.json({ deleted: clearCategoryMappings(budgetSyncId) });
});

app.delete('/categories/:payee', (req: Request, res: Response) => {
  const budgetSyncId = resolveBudgetScope(req.query.budgetSyncId);
  const deleted = deleteCategoryMapping(req.params.payee, budgetSyncId);
  res.status(deleted ? 204 : 404).end();
});

// Pulls already-categorized transactions back from Actual for a date
// range and learns payee -> category from them. This is how the memory
// gets built without a manual admin UI: categorize normally in the Actual
// app, then call this to backfill.
app.post('/categories/learn-from-actual', async (req: Request, res: Response) => {
  const { accountId, startDate, endDate, budgetSyncId, budgetPassword } = req.body ?? {};
  if (!accountId || !startDate || !endDate) {
    return res.status(400).json({
      error: 'Required: "accountId", "startDate" (YYYY-MM-DD), "endDate" (YYYY-MM-DD).',
      code: 'MISSING_FIELD',
    });
  }
  try {
    const result = await learnCategoriesFromActual(
      budgetSession,
      resolveBudgetRef(budgetSyncId, budgetPassword),
      accountId,
      startDate,
      endDate,
    );
    res.json(result);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while syncing categories from Actual.');
  }
});

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

/**
 * The most recent backend log lines (JSON, one per entry), for the app's
 * "Share logs". Query: tail (default 500, max 5000), level (debug|info|warn|error).
 * Refused when auth is disabled: logs describe the user's activity.
 */
app.get('/logs', (req: Request, res: Response) => {
  try {
    if (!IMPORT_TOKEN) throw new AuthRequiredError();
    const tail = Math.min(Math.max(Number(req.query.tail) || 500, 1), 5000);
    const level = typeof req.query.level === 'string' ? req.query.level : undefined;
    return res.json({ lines: readRecentLogLines(logDir(), tail, level) });
  } catch (err) {
    sendImporterError(res, err, 'Could not read the logs.');
  }
});

// --- Error handling ----------------------------------------------------
//
// Registered last, so it sees anything the routes threw — including the
// typed upload rejections from upload.ts. Without it those would escape as
// Express's default HTML 500 and break the promise that every failure
// carries a machine-readable `code`.
app.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
  if (res.headersSent) return next(err);
  return sendImporterError(res, err, 'Internal server error.');
});

// @actual-app/api leaks a duplicate of some errors it also returns to the
// caller (see actual-adapter.ts). Those were already turned into a JSON
// error response, so dropping the duplicate is safe. Anything else is still
// rethrown, keeping Node's default of crashing on a genuine unhandled bug.
process.on('unhandledRejection', (reason) => {
  if (isHandledSdkError(reason)) {
    logger.debug({ area: 'actual', err: reason }, 'Dropped a duplicate error from @actual-app/api');
    return;
  }
  throw reason;
});

// Last stop for a genuine bug: record it with its stack, flush, then exit as
// Node would have (a process in an unknown state shouldn't keep serving).
process.on('uncaughtException', (err) => {
  logger.fatal({ area: 'app', err }, 'Uncaught exception — exiting');
  logger.flush();
  setTimeout(() => process.exit(1), 100).unref();
});

const PORT = process.env.PORT ?? 3000;
const server = app.listen(PORT, () => {
  log.info({ port: Number(PORT), debugLogging: debugFromEnv() }, `PDF importer backend listening on port ${PORT}`);
});
void initLogFile().then((dir) => {
  if (dir) log.info({ dir }, 'Writing log files');
});

// Actual's API keeps a local sqlite cache open; shut it down cleanly so it
// doesn't leave a stale lock file if you restart the process a lot during
// development. shutdown() waits for any in-flight Actual work (so it never
// kills an import halfway); if that work hangs, a second signal force-quits.
//
// SIGTERM as well as SIGINT: a container or service manager stopping the
// process sends SIGTERM, and that is exactly the restart-often case the
// clean shutdown exists for.
let shuttingDown = false;
async function shutdownGracefully(signal: string) {
  if (shuttingDown) process.exit(1);
  shuttingDown = true;
  log.info({ signal }, 'Shutting down — closing the Actual connection');
  try {
    await budgetSession.shutdown();
  } catch (err) {
    log.error({ err }, 'Error while shutting down the Actual connection');
  }
  logger.flush();
  server.close(() => process.exit(0));
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => void shutdownGracefully(signal));
}
