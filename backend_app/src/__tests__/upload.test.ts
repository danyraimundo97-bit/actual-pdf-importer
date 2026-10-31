import { after, before, beforeEach, mock, test } from 'node:test';
import assert from 'node:assert/strict';
import { AddressInfo } from 'node:net';
import { Server } from 'node:http';
import express, { NextFunction, Request, Response } from 'express';
import { ImporterError } from '../errors';
import { receiveFiles, UploadLimits } from '../upload';

// Small limits so the tests can cross them with a few bytes.
const LIMITS: UploadLimits = { maxFileBytes: 1000, maxTotalBytes: 2500 };

let server: Server;
let baseUrl: string;
let warnings: string[];

before(async () => {
  const app = express();
  const echo = (req: Request, res: Response) => {
    const files = Array.isArray(req.files) ? req.files : [];
    res.json({ files: files.length, single: req.file?.originalname ?? null });
  };
  app.post(
    '/one',
    receiveFiles({ fields: ['statement'], maxFiles: 1, tooManyHint: 'Use the batch route.', limits: LIMITS }),
    echo,
  );
  app.post('/many', receiveFiles({ fields: ['statement', 'statements'], maxFiles: 3, limits: LIMITS }), echo);
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    assert.ok(err instanceof ImporterError, `expected an ImporterError, got ${String(err)}`);
    res.status(err.status).json({ code: err.code, error: err.message });
  });

  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(() => new Promise<void>((resolve) => server.close(() => resolve())));

beforeEach(() => {
  warnings = [];
  mock.method(console, 'warn', (msg: string) => warnings.push(msg));
});

async function send(path: string, field: string, sizes: number[]) {
  const form = new FormData();
  sizes.forEach((size, i) => form.append(field, new Blob([Buffer.alloc(size)]), `s${i}.pdf`));
  const res = await fetch(`${baseUrl}${path}`, { method: 'POST', body: form });
  return { status: res.status, body: (await res.json()) as Record<string, unknown> };
}

test('files within every limit pass through, and a single-file route also gets req.file', async () => {
  assert.deepEqual(await send('/many', 'statements', [100, 100, 100]), {
    status: 200,
    body: { files: 3, single: null },
  });
  assert.deepEqual(await send('/one', 'statement', [100]), { status: 200, body: { files: 1, single: 's0.pdf' } });
  assert.deepEqual(warnings, []);
});

test('too many files reports the exact number received, not the limit plus one', async () => {
  const { status, body } = await send('/many', 'statements', [10, 10, 10, 10, 10]);
  assert.equal(status, 400);
  assert.equal(body.code, 'TOO_MANY_FILES');
  assert.match(String(body.error), /received 5, the maximum per request is 3/);
  assert.equal(warnings.length, 1);
  assert.match(warnings[0], /POST \/many rejected with TOO_MANY_FILES: received 5 file\(s\), \d+B in total/);
});

test('two files on a single-file route say the maximum is 1 and point at the batch route', async () => {
  const { status, body } = await send('/one', 'statement', [10, 10]);
  assert.equal(status, 400);
  assert.equal(body.code, 'TOO_MANY_FILES');
  assert.match(String(body.error), /received 2, the maximum per request is 1\. Use the batch route\./);
});

test('one oversized file is FILE_TOO_LARGE', async () => {
  const { status, body } = await send('/many', 'statements', [100, 1500]);
  assert.equal(status, 413);
  assert.equal(body.code, 'FILE_TOO_LARGE');
  assert.match(warnings[0], /rejected with FILE_TOO_LARGE: received at least 2 file\(s\)/);
});

test('files each under the per-file limit but too big together are BATCH_TOO_LARGE', async () => {
  const { status, body } = await send('/many', 'statements', [900, 900, 900]);
  assert.equal(status, 413);
  assert.equal(body.code, 'BATCH_TOO_LARGE');
  assert.match(warnings[0], /rejected with BATCH_TOO_LARGE: received an unknown number of file\(s\) \(refused before reading\), 3\.\dKB in total/);
});

test('a file under the wrong field name is MISSING_FIELD, not TOO_MANY_FILES', async () => {
  const { status, body } = await send('/many', 'file', [10]);
  assert.equal(status, 400);
  assert.equal(body.code, 'MISSING_FIELD');
  assert.match(String(body.error), /expects files under "statement" or "statements"/);
});
