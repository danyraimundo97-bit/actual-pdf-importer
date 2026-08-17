import 'dotenv/config';
import express, { Request, Response } from 'express';
import multer from 'multer';
import { processStatement, UnrecognizedBankError } from './index';
import { importToActual, learnCategoriesFromActual, shutdownActual } from './actual';
import { deleteCategoryMapping, listCategoryMappings, rememberCategory } from './categorydb';

const app = express();
app.use(express.json());

// Memory storage only — the PDF never touches disk, in keeping with the
// "100% offline / no residual copies" privacy goal. Cap size to something
// generous for a bank statement (20MB) so a bad upload can't exhaust RAM.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

const ACTUAL_CONFIG = {
  serverURL: process.env.ACTUAL_SERVER_URL ?? 'http://localhost:5006',
  password: process.env.ACTUAL_PASSWORD ?? '',
  dataDir: process.env.ACTUAL_DATA_DIR ?? './actual-cache',
  budgetSyncId: process.env.ACTUAL_BUDGET_SYNC_ID ?? '',
};

app.post('/import', upload.single('statement'), async (req: Request, res: Response) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded. Expected multipart field "statement".' });
  }

  const accountId = req.body.accountId as string | undefined;
  if (!accountId) {
    return res.status(400).json({ error: 'Missing required field "accountId" (the Actual account to import into).' });
  }

  try {
    // processStatement() decides internally whether to extract text
    // locally first (PARSER_MODE=regex/both) or send the PDF straight to
    // the AI provider (PARSER_MODE=ai) — see src/index.ts.
    const { bankId, transactions } = await processStatement(req.file.buffer);

    if (transactions.length === 0) {
      return res.status(422).json({
        error: `Recognized "${bankId}" but extracted zero transactions. The statement layout may have changed.`,
        bankId,
      });
    }

    const result = await importToActual(ACTUAL_CONFIG, accountId, transactions);

    return res.json({
      bankId,
      parsed: transactions.length,
      added: result.added,
      updated: result.updated,
      categorized: result.categorized,
    });
  } catch (err) {
    if (err instanceof UnrecognizedBankError) {
      return res.status(422).json({ error: err.message });
    }
    console.error('[import] unexpected error:', err);
    return res.status(500).json({ error: 'Internal error while processing the statement.' });
  }
});

// --- Category memory (see src/categorydb.ts) ---------------------------

app.get('/categories', (_req, res) => {
  res.json({ mappings: listCategoryMappings() });
});

app.post('/categories', (req: Request, res: Response) => {
  const { payee, categoryId, categoryName } = req.body ?? {};
  if (!payee || !categoryId) {
    return res.status(400).json({ error: 'Both "payee" and "categoryId" are required.' });
  }
  rememberCategory(payee, categoryId, categoryName);
  res.status(204).end();
});

app.delete('/categories/:payee', (req: Request, res: Response) => {
  const deleted = deleteCategoryMapping(req.params.payee);
  res.status(deleted ? 204 : 404).end();
});

// Pulls already-categorized transactions back from Actual for a date
// range and learns payee -> category from them. This is how the memory
// gets built without a manual admin UI: categorize normally in the Actual
// app, then call this to backfill.
app.post('/categories/learn-from-actual', async (req: Request, res: Response) => {
  const { accountId, startDate, endDate } = req.body ?? {};
  if (!accountId || !startDate || !endDate) {
    return res.status(400).json({ error: 'Required: "accountId", "startDate" (YYYY-MM-DD), "endDate" (YYYY-MM-DD).' });
  }
  try {
    const result = await learnCategoriesFromActual(ACTUAL_CONFIG, accountId, startDate, endDate);
    res.json(result);
  } catch (err) {
    console.error('[categories/learn-from-actual] unexpected error:', err);
    res.status(500).json({ error: 'Internal error while syncing categories from Actual.' });
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
