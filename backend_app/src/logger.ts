/**
 * The backend's logger (docs/plans/logging.md).
 *
 * - **Levels**: debug is written only with `LOG_DEBUG=true`; info, warn and
 *   error are always written.
 * - **Destinations**: stdout (pretty in a dev terminal, JSON otherwise, which
 *   Docker captures) and, once `initLogFile()` has run, daily-rotated JSON
 *   files in `LOG_DIR`.
 * - **What may be logged** is decided by field name, as in the app's
 *   `redaction.dart`: secrets are replaced, amounts and raw statement lines
 *   are always dropped, payees only survive at debug, ids are always fine.
 *
 * Modules take a child per area: `const log = logger.child({ area: 'parser' })`.
 */
import fs from 'fs';
import path from 'path';
import pino, { DestinationStream, Logger, StreamEntry } from 'pino';

export const REDACTED = '<redacted>';

const SECRET_KEYS = new Set([
  'token',
  'apitoken',
  'importtoken',
  'x-import-token',
  'authorization',
  'password',
  'budgetpassword',
  'statementpassword',
  'serverpassword',
  'apikey',
  'secret',
]);
const ALWAYS_DROPPED = new Set(['rawline', 'pdf', 'bytes', 'buffer', 'text', 'pdftext', 'block', 'body']);
const DEBUG_ONLY = new Set(['payee', 'payeekey', 'payeename', 'payeelabel', 'description', 'importedpayee']);

const norm = (key: string) => key.toLowerCase().replace(/_/g, '');

function isSecret(key: string): boolean {
  const k = norm(key);
  return SECRET_KEYS.has(k) || k.endsWith('password') || k.endsWith('token') || k.endsWith('apikey');
}

function isMoney(key: string): boolean {
  const k = norm(key);
  return k === 'amount' || k.startsWith('amount') || k.startsWith('balance') || k.endsWith('cents');
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && Object.getPrototypeOf(value) === Object.prototype;
}

/**
 * Returns a copy of `fields` that is safe to write. Errors and other class
 * instances are kept as they are (pino serializes errors with their stack).
 */
export function redactFields(fields: Record<string, unknown>, debugEnabled: boolean): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    const k = norm(key);
    if (isSecret(key)) out[key] = REDACTED;
    else if (isMoney(key) || ALWAYS_DROPPED.has(k)) continue;
    else if (DEBUG_ONLY.has(k) && !debugEnabled) continue;
    else if (isPlainObject(value)) out[key] = redactFields(value, debugEnabled);
    else out[key] = value;
  }
  return out;
}

export const debugFromEnv = (): boolean => /^(1|true|yes|on)$/i.test(process.env.LOG_DEBUG ?? '');

export interface LoggerOptions {
  debug: boolean;
  /** Where lines go. Defaults to stdout (pretty in a dev terminal). */
  streams?: StreamEntry[];
}

function stdoutStream(): DestinationStream {
  if (process.stdout.isTTY && process.env.NODE_ENV !== 'production') {
    try {
      // Dev dependency: absent in the Docker image, where JSON is wanted anyway.
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const pretty = require('pino-pretty') as (opts: object) => DestinationStream;
      return pretty({ colorize: true, sync: true, translateTime: 'SYS:HH:MM:ss.l', ignore: 'pid,hostname' });
    } catch {
      /* fall through to JSON */
    }
  }
  return pino.destination({ fd: 1, sync: false });
}

export type AppLogger = Logger & { multistream?: ReturnType<typeof pino.multistream> };

export function createLogger(options: LoggerOptions): AppLogger {
  const debug = options.debug;
  const multistream = pino.multistream(options.streams ?? [{ level: 'debug', stream: stdoutStream() }]);
  const instance = pino(
    {
      level: debug ? 'debug' : 'info',
      base: undefined, // no pid/hostname: one process, one host
      timestamp: pino.stdTimeFunctions.isoTime,
      formatters: {
        log: (fields) => redactFields(fields as Record<string, unknown>, debug),
      },
    },
    multistream,
  ) as AppLogger;
  instance.multistream = multistream;
  return instance;
}

/** The process-wide logger. */
export const logger: AppLogger = createLogger({ debug: debugFromEnv() });

export const logDir = (): string =>
  process.env.LOG_DIR ||
  path.join(path.dirname(process.env.CATEGORY_DB_PATH || './category-memory.db'), 'logs');

/** File names pino-roll produces: `backend.2026-11-02.1.log`. */
export const LOG_FILE_PATTERN = /^backend\.\d{4}-\d{2}-\d{2}\.\d+\.log$/;

/**
 * Adds the rotated log files: daily, or at 10 MB, keeping 14 old files.
 * Async because pino-roll opens its stream asynchronously; until it's done
 * (milliseconds at startup) lines only go to stdout. A failure is logged and
 * the backend keeps running with stdout only.
 */
export async function initLogFile(target: AppLogger = logger, dir = logDir()): Promise<string | null> {
  try {
    fs.mkdirSync(dir, { recursive: true });
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const roll = require('pino-roll') as (opts: object) => Promise<DestinationStream>;
    const stream = await roll({
      file: path.join(dir, 'backend'),
      extension: '.log',
      frequency: 'daily',
      dateFormat: 'yyyy-MM-dd',
      size: '10m',
      mkdir: true,
      limit: { count: 14 },
    });
    target.multistream?.add({ level: 'debug', stream });
    return dir;
  } catch (err) {
    target.error({ area: 'app', err, dir }, 'Could not open the log file; logging to stdout only');
    return null;
  }
}

const LEVEL_NUMBERS: Record<string, number> = { debug: 20, info: 30, warn: 40, error: 50 };

/**
 * The last `tail` lines of the log files, newest last, optionally only at
 * `minLevel` and above. Used by GET /logs so the app can attach the
 * backend's side to a log report.
 */
export function readRecentLogLines(dir: string, tail: number, minLevel?: string): string[] {
  if (!fs.existsSync(dir)) return [];
  const min = minLevel ? LEVEL_NUMBERS[minLevel] : undefined;
  const files = fs
    .readdirSync(dir)
    .filter((name) => LOG_FILE_PATTERN.test(name))
    .map((name) => ({ name, mtime: fs.statSync(path.join(dir, name)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime || b.name.localeCompare(a.name, undefined, { numeric: true }));

  const collected: string[] = [];
  for (const { name } of files) {
    const lines = fs
      .readFileSync(path.join(dir, name), 'utf8')
      .split('\n')
      .filter((line) => line.trim() !== '')
      .filter((line) => {
        if (min === undefined) return true;
        try {
          return (JSON.parse(line).level ?? 0) >= min;
        } catch {
          return true;
        }
      });
    collected.unshift(...lines);
    if (collected.length >= tail) break;
  }
  return collected.slice(-tail);
}
