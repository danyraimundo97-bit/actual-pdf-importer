/**
 * The Actual server connection, which is optional (docs/plans/core-app.md,
 * Milestone 1).
 *
 * Where it comes from, in order:
 * 1. `ACTUAL_SERVER_URL` in .env → *locked*: shown to the app, not editable;
 * 2. the connection the app saved (`actual-connection.json` next to the
 *    category DB, file mode 0600);
 * 3. otherwise none: the backend runs and parses statements, and Actual
 *    routes answer ACTUAL_NOT_CONFIGURED.
 *
 * The server password never leaves this module except into the SDK's
 * config: GET /actual/connection only reports whether one is set.
 */
import fs from 'fs';
import path from 'path';
import type { ServerConfig } from './budget-session';
import {
  ActualAuthFailedError,
  ActualUnreachableError,
  ActualVersionTooOldError,
  InvalidFieldError,
} from './errors';

export interface StoredConnection {
  serverUrl: string;
  password: string;
}

export interface ResolvedConnection {
  /** Null = no Actual server configured. */
  config: ServerConfig | null;
  /** Set in .env, so the app can't change it. */
  locked: boolean;
}

export interface ConnectionStore {
  read(): StoredConnection | null;
  write(connection: StoredConnection): void;
  clear(): void;
}

export function defaultConnectionFile(env: NodeJS.ProcessEnv = process.env): string {
  return path.join(path.dirname(env.CATEGORY_DB_PATH || './data/categories.db'), 'actual-connection.json');
}

export function fileConnectionStore(file: string): ConnectionStore {
  return {
    read() {
      try {
        const data = JSON.parse(fs.readFileSync(file, 'utf8'));
        return typeof data?.serverUrl === 'string' && data.serverUrl
          ? { serverUrl: data.serverUrl, password: typeof data.password === 'string' ? data.password : '' }
          : null;
      } catch {
        return null; // missing or unreadable: not configured
      }
    },
    write(connection) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      const tmp = `${file}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(connection), { mode: 0o600 });
      fs.renameSync(tmp, file);
      fs.chmodSync(file, 0o600); // in case the file existed with looser permissions
    },
    clear() {
      fs.rmSync(file, { force: true });
    },
  };
}

export function resolveConnection(env: NodeJS.ProcessEnv, store: ConnectionStore): ResolvedConnection {
  const dataDir = env.ACTUAL_DATA_DIR || './actual-cache';
  const fromEnv = env.ACTUAL_SERVER_URL?.trim();
  if (fromEnv) {
    return { config: { serverURL: fromEnv, password: env.ACTUAL_PASSWORD ?? '', dataDir }, locked: true };
  }
  const stored = store.read();
  return {
    config: stored ? { serverURL: stored.serverUrl, password: stored.password, dataDir } : null,
    locked: false,
  };
}

/** Trims, adds `http://` when no scheme was typed, drops trailing slashes. */
export function normalizeServerUrl(input: unknown): string {
  if (typeof input !== 'string' || !input.trim()) throw new InvalidFieldError('serverUrl', 'it is empty');
  let url = input.trim();
  if (!/^[a-z]+:\/\//i.test(url)) url = `http://${url}`;
  url = url.replace(/\/+$/, '');
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new InvalidFieldError('serverUrl', 'not a URL');
  }
  if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
    throw new InvalidFieldError('serverUrl', 'only http and https are supported');
  }
  return url;
}

/** `26.10.1` → [26, 10, 1]; anything unparseable → null. */
export function parseVersion(version: string): number[] | null {
  const match = version.trim().replace(/^v/, '').match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
  return match ? [Number(match[1]), Number(match[2]), Number(match[3] ?? 0)] : null;
}

export function isAtLeast(version: string, minimum: string): boolean {
  const a = parseVersion(version);
  const b = parseVersion(minimum);
  if (!a || !b) return true; // can't tell: don't block on it
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) return a[i] > b[i];
  }
  return true;
}

/**
 * The oldest Actual server this backend may talk to: the major.minor of
 * its own @actual-app/api, since the library upgrades a budget's file
 * format and an older server may no longer open it (TODO §2).
 */
export function minimumServerVersion(): string {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { version } = require('@actual-app/api/package.json') as { version: string };
  const parsed = parseVersion(version);
  return parsed ? `${parsed[0]}.${parsed[1]}.0` : version;
}

type Fetch = typeof fetch;

/**
 * Checks a server before it's saved, over plain HTTP so the SDK's one
 * global connection (possibly busy with another budget) isn't disturbed:
 * `GET /info` for the version, then a password login.
 *
 * Endpoints as served by Actual's sync server: `/info` →
 * `{ build: { version } }`, `/account/login` → `{ status: 'ok' }` or
 * `{ status: 'error', reason: 'invalid-password' }`.
 */
export async function probeActualServer(
  serverUrl: string,
  password: string,
  options: { fetch?: Fetch; timeoutMs?: number; minimumVersion?: string } = {},
): Promise<{ version: string | null }> {
  const doFetch = options.fetch ?? fetch;
  const timeoutMs = options.timeoutMs ?? 8000;
  const call = async (pathName: string, init?: RequestInit) => {
    try {
      return await doFetch(`${serverUrl}${pathName}`, { ...init, signal: AbortSignal.timeout(timeoutMs) });
    } catch {
      throw new ActualUnreachableError(serverUrl);
    }
  };

  const info = await call('/info');
  const infoBody = (info.ok ? await info.json().catch(() => null) : null) as { build?: { version?: unknown } } | null;
  const version: string | null = typeof infoBody?.build?.version === 'string' ? infoBody.build.version : null;
  if (!info.ok || !infoBody?.build) {
    // Something answered, but not an Actual server (or a very old one).
    throw new ActualUnreachableError(serverUrl);
  }
  const minimum = options.minimumVersion ?? minimumServerVersion();
  if (version && !isAtLeast(version, minimum)) throw new ActualVersionTooOldError(version, minimum);

  const login = await call('/account/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ loginMethod: 'password', password }),
  });
  const loginBody = (await login.json().catch(() => null)) as { status?: string } | null;
  if (loginBody?.status !== 'ok') throw new ActualAuthFailedError();

  return { version };
}
