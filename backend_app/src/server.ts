import 'dotenv/config';
import express, { Request, Response } from 'express';
import multer from 'multer';
import pdfParse from 'pdf-parse';
import { identifyAndParse, UnrecognizedBankError } from './index';
import { importToActual, shutdownActual } from './actual';

const app = express();

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
    const { text } = await pdfParse(req.file.buffer);
    const { bankId, transactions } = await identifyAndParse(text);

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
    });
  } catch (err) {
    if (err instanceof UnrecognizedBankError) {
      return res.status(422).json({ error: err.message });
    }
    console.error('[import] unexpected error:', err);
    return res.status(500).json({ error: 'Internal error while processing the statement.' });
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
