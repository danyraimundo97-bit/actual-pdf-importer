import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import {
  fileConnectionStore,
  isAtLeast,
  normalizeServerUrl,
  probeActualServer,
  resolveConnection,
} from '../actual-connection';

function tempFile() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'conn-'));
  return { file: path.join(dir, 'sub', 'actual-connection.json'), cleanup: () => fs.rmSync(dir, { recursive: true, force: true }) };
}

test('the store round-trips, writes mode 0600, and clear() forgets', () => {
  const { file, cleanup } = tempFile();
  try {
    const store = fileConnectionStore(file);
    assert.equal(store.read(), null);
    store.write({ serverUrl: 'http://actual:5006', password: 'pw' });
    assert.deepEqual(store.read(), { serverUrl: 'http://actual:5006', password: 'pw' });
    assert.equal(fs.statSync(file).mode & 0o777, 0o600);
    store.clear();
    assert.equal(store.read(), null);
  } finally {
    cleanup();
  }
});

test('.env wins and locks; else the stored connection; else none (no localhost default)', () => {
  const stored = { read: () => ({ serverUrl: 'http://saved', password: 's' }), write() {}, clear() {} };
  const empty = { read: () => null, write() {}, clear() {} };

  const fromEnv = resolveConnection({ ACTUAL_SERVER_URL: 'http://env', ACTUAL_PASSWORD: 'e' }, stored);
  assert.equal(fromEnv.locked, true);
  assert.equal(fromEnv.config?.serverURL, 'http://env');
  assert.equal(fromEnv.config?.password, 'e');

  const fromStore = resolveConnection({}, stored);
  assert.equal(fromStore.locked, false);
  assert.equal(fromStore.config?.serverURL, 'http://saved');

  assert.deepEqual(resolveConnection({}, empty), { config: null, locked: false });
});

test('server URLs are normalized and validated', () => {
  assert.equal(normalizeServerUrl(' 192.168.1.5:5006/ '), 'http://192.168.1.5:5006');
  assert.equal(normalizeServerUrl('https://budget.example.com//'), 'https://budget.example.com');
  assert.throws(() => normalizeServerUrl(''), { code: 'INVALID_FIELD' });
  assert.throws(() => normalizeServerUrl('ftp://x'), { code: 'INVALID_FIELD' });
});

test('version comparison', () => {
  assert.equal(isAtLeast('26.10.0', '26.10.0'), true);
  assert.equal(isAtLeast('26.11.2', '26.10.0'), true);
  assert.equal(isAtLeast('27.1.0', '26.10.0'), true);
  assert.equal(isAtLeast('26.9.9', '26.10.0'), false);
  assert.equal(isAtLeast('6.10.0', '26.10.0'), false);
  assert.equal(isAtLeast('nightly', '26.10.0'), true, "unparseable versions don't block");
});

/** A fake Actual server: `/info` and `/account/login`. */
function fakeServer(opts: { version?: string; password?: string; down?: boolean; notActual?: boolean }) {
  const calls: string[] = [];
  const fetchImpl = (async (url: string, init?: RequestInit) => {
    calls.push(url);
    if (opts.down) throw new TypeError('fetch failed');
    if (url.endsWith('/info')) {
      return opts.notActual
        ? new Response('<html>', { status: 200 })
        : Response.json({ build: { name: '@actual-app/sync-server', version: opts.version ?? '26.10.0' } });
    }
    if (url.endsWith('/account/login')) {
      const body = JSON.parse(String(init?.body));
      return body.password === opts.password
        ? Response.json({ status: 'ok', data: { token: 't' } })
        : Response.json({ status: 'error', reason: 'invalid-password' }, { status: 400 });
    }
    return new Response('not found', { status: 404 });
  }) as typeof fetch;
  return { fetchImpl, calls };
}

const MIN = { minimumVersion: '26.10.0' };

test('probe: a reachable, recent server with the right password passes and reports its version', async () => {
  const { fetchImpl } = fakeServer({ password: 'pw', version: '26.10.1' });
  assert.deepEqual(await probeActualServer('http://a', 'pw', { fetch: fetchImpl, ...MIN }), { version: '26.10.1' });
});

test('probe: each failure has its own code', async () => {
  await assert.rejects(probeActualServer('http://a', 'pw', { fetch: fakeServer({ down: true }).fetchImpl, ...MIN }), {
    code: 'ACTUAL_UNREACHABLE',
  });
  await assert.rejects(
    probeActualServer('http://a', 'pw', { fetch: fakeServer({ notActual: true }).fetchImpl, ...MIN }),
    { code: 'ACTUAL_UNREACHABLE' },
  );
  await assert.rejects(
    probeActualServer('http://a', 'wrong', { fetch: fakeServer({ password: 'pw' }).fetchImpl, ...MIN }),
    { code: 'ACTUAL_AUTH_FAILED' },
  );
  const old = fakeServer({ password: 'pw', version: '25.4.0' });
  await assert.rejects(probeActualServer('http://a', 'pw', { fetch: old.fetchImpl, ...MIN }), {
    code: 'ACTUAL_VERSION_TOO_OLD',
  });
  assert.equal(old.calls.length, 1, 'a too-old server is rejected before the password is sent');
});
