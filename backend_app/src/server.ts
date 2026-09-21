import 'dotenv/config';
import crypto from 'crypto';
import express, { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import { processStatement, PARSER_MODE } from './index';
import { ImporterError, NoBudgetSelectedError } from './errors';
import { getAiProvider } from './parsers/ai-providers';
import {
  assignImportedIds,
  importToActual,
  learnCategoriesFromActual,
  listAccounts,
  listBudgets,
  listCategoryGroups,
} from './actual';
import { actualSdkAdapter } from './actual-adapter';
import { BudgetRef, createBudgetSession } from './budget-session';
import { deleteCategoryMapping, listCategoryMappings, lookupCategory, rememberCategory } from './categorydb';

const app = express();
app.use(express.json());

// Memory storage only — the PDF never touches disk, in keeping with the
// "100% offline / no residual copies" privacy goal. Cap size to something
// generous for a bank statement (20MB) so a bad upload can't exhaust RAM.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

// Server credentials never vary per request, so they're fixed when the
// budget session is created; only the budget choice is per-request.
const budgetSession = createBudgetSession(
  {
    serverURL: process.env.ACTUAL_SERVER_URL ?? 'http://localhost:5006',
    password: process.env.ACTUAL_PASSWORD ?? '',
    dataDir: process.env.ACTUAL_DATA_DIR ?? './actual-cache',
  },
  actualSdkAdapter,
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

function sendImporterError(res: Response, err: unknown, fallbackMessage: string): void {
  if (err instanceof ImporterError) {
    res.status(err.status).json({ error: err.message, code: err.code });
    return;
  }
  console.error(fallbackMessage, err);
  res.status(500).json({ error: fallbackMessage, code: 'INTERNAL_ERROR' });
}

// --- Auth ------------------------------------------------------------------
//
// A shared secret, not real auth (no users/sessions) — just enough that
// "anyone on the LAN can write to my budget" isn't the default. GET
// /health stays open so the app can always tell "backend unreachable"
// apart from "backend reachable, token rejected".

const IMPORT_TOKEN = process.env.IMPORT_TOKEN;
if (!IMPORT_TOKEN) {
  console.warn(
    '[auth] IMPORT_TOKEN is not set — running with NO authentication. ' +
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
    return res.status(401).json({ error: 'Missing or invalid X-Import-Token header.', code: 'UNAUTHORIZED' });
  }
  return next();
});

// --- Parsing / importing -----------------------------------------------

/**
 * Parses a statement WITHOUT touching Actual. The front end reviews and
 * edits the result, then confirms with POST /import/confirm. Each
 * transaction is enriched with its dedupe id (so edits on the review
 * screen don't break re-import dedupe) and its suggested category from
 * local memory, scoped to the budget in play.
 */
app.post('/parse', upload.single('statement'), async (req: Request, res: Response) => {
  if (!req.file) {
    return res
      .status(400)
      .json({ error: 'No file uploaded. Expected multipart field "statement".', code: 'MISSING_FIELD' });
  }

  const password = typeof req.body.password === 'string' && req.body.password ? req.body.password : undefined;
  const budgetSyncId = resolveBudgetScope(req.body.budgetSyncId);

  try {
    const { bankId, transactions } = await processStatement(req.file.buffer, password);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        code: 'NO_TRANSACTIONS',
        bankId,
      });
    }

    const enriched = assignImportedIds(transactions).map((tx) => {
      const match = lookupCategory(tx.payee, budgetSyncId);
      return {
        ...tx,
        suggestedCategoryId: match?.categoryId,
        suggestedCategoryName: match?.categoryName,
      };
    });

    return res.json({ bankId, transactions: enriched });
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
    return res.json(result);
  } catch (err) {
    sendImporterError(res, err, 'Internal error while importing to Actual.');
  }
});

/**
 * Kept unchanged for backwards compatibility: parse-and-import in one
 * shot, no review step. New clients should prefer POST /parse followed by
 * POST /import/confirm.
 */
app.post('/import', upload.single('statement'), async (req: Request, res: Response) => {
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

app.get('/budgets', async (_req: Request, res: Response) => {
  try {
    const budgets = await listBudgets(budgetSession);
    res.json({ budgets });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual budgets.');
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
  });
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

const PORT = process.env.PORT ?? 3000;
const server = app.listen(PORT, () => {
  console.log(`PDF importer backend listening on port ${PORT}`);
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
  console.log(`
[server] ${signal} received — closing the Actual connection...`);
  try {
    await budgetSession.shutdown();
  } catch (err) {
    console.error('Error while shutting down the Actual connection:', err);
  }
  server.close(() => process.exit(0));
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => void shutdownGracefully(signal));
}
