import 'dotenv/config';
import crypto from 'crypto';
import express, { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import { processStatement, PARSER_MODE } from './index';
import { ImporterError } from './errors';
import { getAiProvider } from './parsers/ai-providers';
import {
  ActualConfig,
  deriveImportedId,
  importToActual,
  learnCategoriesFromActual,
  listAccounts,
  listBudgets,
  listCategoryGroups,
  shutdownActual,
} from './actual';
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

const DEFAULT_ACTUAL_CONFIG = {
  serverURL: process.env.ACTUAL_SERVER_URL ?? 'http://localhost:5006',
  password: process.env.ACTUAL_PASSWORD ?? '',
  dataDir: process.env.ACTUAL_DATA_DIR ?? './actual-cache',
  budgetSyncId: process.env.ACTUAL_BUDGET_SYNC_ID ?? '',
};

/**
 * Builds the ActualConfig for a single request, honoring a per-request
 * budget override (the budget picker in Settings) while falling back to
 * the .env default when the client doesn't specify one.
 */
function resolveActualConfig(budgetSyncId?: unknown, budgetPassword?: unknown): ActualConfig {
  const override = typeof budgetSyncId === 'string' ? budgetSyncId.trim() : '';
  return {
    ...DEFAULT_ACTUAL_CONFIG,
    budgetSyncId: override || DEFAULT_ACTUAL_CONFIG.budgetSyncId,
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
  const budgetSyncId = resolveActualConfig(req.body.budgetSyncId).budgetSyncId;

  try {
    const { bankId, transactions } = await processStatement(req.file.buffer, password);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        code: 'NO_TRANSACTIONS',
        bankId,
      });
    }

    const enriched = transactions.map((tx) => {
      const match = lookupCategory(tx.payee, budgetSyncId);
      return {
        ...tx,
        importedId: deriveImportedId(tx),
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
    const config = resolveActualConfig(budgetSyncId, budgetPassword);
    const result = await importToActual(config, accountId, transactions);
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
  const config = resolveActualConfig(req.body.budgetSyncId, req.body.budgetPassword);

  try {
    const { bankId, transactions } = await processStatement(req.file.buffer, password);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        code: 'NO_TRANSACTIONS',
        bankId,
      });
    }

    const result = await importToActual(config, accountId, transactions);

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
    const config = resolveActualConfig(req.query.budgetSyncId);
    const accounts = await listAccounts(config);
    res.json({ accounts });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual accounts.');
  }
});

app.get('/actual/categories', async (req: Request, res: Response) => {
  try {
    const config = resolveActualConfig(req.query.budgetSyncId);
    const groups = await listCategoryGroups(config);
    res.json({ groups });
  } catch (err) {
    sendImporterError(res, err, 'Internal error while listing Actual categories.');
  }
});

app.get('/budgets', async (_req: Request, res: Response) => {
  try {
    const budgets = await listBudgets(DEFAULT_ACTUAL_CONFIG);
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
    defaultBudgetSyncId: DEFAULT_ACTUAL_CONFIG.budgetSyncId || undefined,
  });
});

// --- Category memory (see src/categorydb.ts) ---------------------------

app.get('/categories', (req: Request, res: Response) => {
  const budgetSyncId = resolveActualConfig(req.query.budgetSyncId).budgetSyncId;
  res.json({ mappings: listCategoryMappings(budgetSyncId) });
});

app.post('/categories', (req: Request, res: Response) => {
  const { payee, categoryId, categoryName, budgetSyncId } = req.body ?? {};
  if (!payee || !categoryId) {
    return res.status(400).json({ error: 'Both "payee" and "categoryId" are required.', code: 'MISSING_FIELD' });
  }
  rememberCategory(payee, categoryId, categoryName, resolveActualConfig(budgetSyncId).budgetSyncId);
  res.status(204).end();
});

app.delete('/categories/:payee', (req: Request, res: Response) => {
  const budgetSyncId = resolveActualConfig(req.query.budgetSyncId).budgetSyncId;
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
    const config = resolveActualConfig(budgetSyncId, budgetPassword);
    const result = await learnCategoriesFromActual(config, accountId, startDate, endDate);
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
// development.
process.on('SIGINT', async () => {
  await shutdownActual();
  server.close(() => process.exit(0));
});
