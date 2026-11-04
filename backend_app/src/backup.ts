/**
 * Backups (docs/plans/backups.md): the Actual budget, as the zip Actual's own
 * Export makes, and the app's data (categories, category memory, removal
 * log) as gzipped JSON.
 *
 * Layout: `<backupDir>/app-data/<stamp>.json.gz` and
 * `<backupDir>/<budget sync id>/<stamp>.zip`. Files are written to a `.tmp`
 * name and renamed when complete, so a crash never leaves a half-written
 * file that looks valid. A file is only ever reached through the listing
 * (`findBackup`), never by joining user input into a path.
 */
import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import type { BudgetRef, BudgetSession } from './budget-session';
import {
  exportCategoryData,
  restoreCategoryData,
  type AppCategoryChange,
  type BackupMapping,
} from './categorydb';
import { BackupInvalidError, BackupNotFoundError, BackupTooNewError } from './errors';
import { logger } from './logger';
import { listAllRemovals, recordRemovals, type RemovedTransaction } from './removal-log';

const log = logger.child({ area: 'backup' });

export const APP_DATA_FOLDER = 'app-data';
export const APP_DATA_SCHEMA_VERSION = 1;
/** Suffix of the safety copy a restore makes first; never pruned. */
export const BEFORE_RESTORE = '-before-restore';

const BUDGET_EXT = '.zip';
const APP_DATA_EXT = '.json.gz';
/** A budget folder is its sync id; anything else is not ours. */
const FOLDER_RE = /^[A-Za-z0-9-]{1,64}$/;

export function defaultBackupDir(env: NodeJS.ProcessEnv = process.env): string {
  return env.BACKUP_DIR || path.join(path.dirname(env.CATEGORY_DB_PATH || './data/categories.db'), 'backups');
}

export interface BackupFile {
  /** `app-data` or a budget's sync id. */
  folder: string;
  file: string;
  size: number;
  createdAt: string;
  /** The safety copy a restore made (app data only). */
  beforeRestore: boolean;
}

export interface AppDataBackup {
  manifest: { kind: 'app-data'; schemaVersion: number; createdAt: string; appVersion: string };
  appCategories: AppCategoryChange[];
  mappings: BackupMapping[];
  removals: RemovedTransaction[];
}

const pad = (n: number, width = 2) => String(n).padStart(width, '0');

/** `YYYY-MM-DD_HHmmss` in the backend's local time: sorts by date, reads as one. */
export function backupStamp(at: Date): string {
  return (
    `${at.getFullYear()}-${pad(at.getMonth() + 1)}-${pad(at.getDate())}_` +
    `${pad(at.getHours())}${pad(at.getMinutes())}${pad(at.getSeconds())}`
  );
}

function isBackupName(file: string): boolean {
  return /^\d{4}-\d{2}-\d{2}_\d{6}(-\d+)?(-before-restore)?(\.zip|\.json\.gz)$/.test(file);
}

/** Writes `bytes` as `<folder>/<stamp><suffix><ext>` atomically; returns the file name. */
function writeBackup(dir: string, folder: string, at: Date, ext: string, bytes: Uint8Array, suffix = ''): string {
  const folderPath = path.join(dir, folder);
  fs.mkdirSync(folderPath, { recursive: true });
  const stamp = backupStamp(at);
  let file = `${stamp}${suffix}${ext}`;
  // Two backups in one second (a manual one right after a scheduled one).
  for (let n = 2; fs.existsSync(path.join(folderPath, file)); n++) file = `${stamp}-${n}${suffix}${ext}`;
  const tmp = path.join(folderPath, `.${file}.tmp`);
  try {
    fs.writeFileSync(tmp, bytes, { mode: 0o600 });
    fs.renameSync(tmp, path.join(folderPath, file));
  } finally {
    fs.rmSync(tmp, { force: true });
  }
  return file;
}

/** The backups in one folder, newest first. Leftover `.tmp` files are not backups. */
export function listBackups(dir: string, folder: string): BackupFile[] {
  if (!FOLDER_RE.test(folder)) return [];
  let names: string[];
  try {
    names = fs.readdirSync(path.join(dir, folder));
  } catch {
    return [];
  }
  return names
    .filter(isBackupName)
    .map((file) => {
      const stat = fs.statSync(path.join(dir, folder, file));
      return {
        folder,
        file,
        size: stat.size,
        createdAt: stat.mtime.toISOString(),
        beforeRestore: file.includes(BEFORE_RESTORE),
      };
    })
    .sort((a, b) => (a.file < b.file ? 1 : a.file > b.file ? -1 : 0));
}

/** The folders holding backups: app data first, then budgets. */
export function listBackupFolders(dir: string): string[] {
  let names: string[];
  try {
    names = fs.readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
  } catch {
    return [];
  }
  return names.filter((n) => FOLDER_RE.test(n)).sort((a, b) => (a === APP_DATA_FOLDER ? -1 : b === APP_DATA_FOLDER ? 1 : a.localeCompare(b)));
}

/** The one backup with exactly this name, from the listing; BACKUP_NOT_FOUND otherwise. */
export function findBackup(dir: string, folder: string, file: string): { entry: BackupFile; path: string } {
  const entry = listBackups(dir, folder).find((b) => b.file === file);
  if (!entry) throw new BackupNotFoundError();
  return { entry, path: path.join(dir, entry.folder, entry.file) };
}

export function deleteBackup(dir: string, folder: string, file: string): void {
  fs.rmSync(findBackup(dir, folder, file).path);
}

/**
 * Keeps the `keep` newest backups of a folder and deletes the rest. Never
 * the one just made (`justMade`), never a before-restore safety copy.
 * Called only after a successful backup, so a backend that keeps failing
 * never eats its own history.
 */
export function pruneBackups(dir: string, folder: string, keep: number, justMade: string): string[] {
  const candidates = listBackups(dir, folder).filter((b) => !b.beforeRestore);
  const deleted: string[] = [];
  let kept = 0;
  for (const b of candidates) {
    if (b.file === justMade || kept < keep) {
      kept++;
      continue;
    }
    fs.rmSync(path.join(dir, folder, b.file), { force: true });
    deleted.push(b.file);
  }
  if (deleted.length) log.info({ folder, deleted: deleted.length, keep }, 'Old backups pruned');
  return deleted;
}

// --- App data ---------------------------------------------------------------

export function buildAppDataBackup(now: Date, appVersion: string): AppDataBackup {
  const { appCategories, mappings } = exportCategoryData();
  return {
    manifest: { kind: 'app-data', schemaVersion: APP_DATA_SCHEMA_VERSION, createdAt: now.toISOString(), appVersion },
    appCategories,
    mappings,
    removals: listAllRemovals(),
  };
}

export function backupAppData(
  dir: string,
  options: { now?: Date; appVersion?: string; beforeRestore?: boolean } = {},
): BackupFile {
  const started = Date.now();
  const now = options.now ?? new Date();
  const data = buildAppDataBackup(now, options.appVersion ?? appVersion());
  const gz = zlib.gzipSync(Buffer.from(JSON.stringify(data)));
  const file = writeBackup(dir, APP_DATA_FOLDER, now, APP_DATA_EXT, gz, options.beforeRestore ? BEFORE_RESTORE : '');
  log.info(
    {
      file,
      sizeKb: Math.ceil(gz.length / 1024),
      categories: data.appCategories.length,
      mappings: data.mappings.length,
      removals: data.removals.length,
      ms: Date.now() - started,
    },
    'App data backed up',
  );
  return findBackup(dir, APP_DATA_FOLDER, file).entry;
}

/** Reads and checks an app-data backup. Newer schema → BACKUP_TOO_NEW; not ours → BACKUP_INVALID. */
export function readAppDataBackup(bytes: Buffer): AppDataBackup {
  let data: unknown;
  try {
    data = JSON.parse(zlib.gunzipSync(bytes).toString('utf8'));
  } catch {
    throw new BackupInvalidError();
  }
  const d = data as Partial<AppDataBackup> | null;
  const manifest = d?.manifest;
  if (!manifest || manifest.kind !== 'app-data' || typeof manifest.schemaVersion !== 'number') {
    throw new BackupInvalidError();
  }
  if (manifest.schemaVersion > APP_DATA_SCHEMA_VERSION) throw new BackupTooNewError();
  if (!Array.isArray(d.appCategories) || !Array.isArray(d.mappings) || !Array.isArray(d.removals)) {
    throw new BackupInvalidError();
  }
  for (const c of d.appCategories) {
    if (typeof c?.kind !== 'string' || typeof c.id !== 'string' || typeof c.updatedAt !== 'number') {
      throw new BackupInvalidError();
    }
  }
  for (const m of d.mappings) {
    if (typeof m?.payee !== 'string' || !m.payee.trim() || typeof m.categoryId !== 'string' || !m.categoryId) {
      throw new BackupInvalidError();
    }
  }
  return d as AppDataBackup;
}

/**
 * Restores an app-data backup onto this backend: a safety copy of the
 * current data first, then the backup written as new edits (categorydb's
 * restoreCategoryData), so phones get it on their next sync. The removal
 * log is only added to.
 */
export function restoreAppData(
  dir: string,
  file: string,
  options: { now?: Date } = {},
): { safetyCopy: BackupFile; appCategories: number; mappings: number; forgotten: number; removals: number } {
  const { path: backupPath } = findBackup(dir, APP_DATA_FOLDER, file);
  const data = readAppDataBackup(fs.readFileSync(backupPath));
  const now = options.now ?? new Date();
  const safetyCopy = backupAppData(dir, { now, beforeRestore: true });
  const result = restoreCategoryData({ appCategories: data.appCategories, mappings: data.mappings }, now.getTime());
  recordRemovals(
    data.removals.map((r) => ({
      ...r,
      // recordRemovals binds every field by name: absent optional ones must be null, not undefined.
      payee: r.payee ?? (null as unknown as undefined),
      originalNotes: r.originalNotes ?? (null as unknown as undefined),
    })),
  );
  log.info({ file, safetyCopy: safetyCopy.file, ...result, removals: data.removals.length }, 'App data restored');
  return { safetyCopy, ...result, removals: data.removals.length };
}

// --- Actual budget ------------------------------------------------------------

/**
 * Backs up one budget: a session turn downloads/syncs it, then Actual's own
 * export (db.sqlite + metadata.json, made inside Actual's mutator queue, so
 * consistent) is written to the budget's folder. Restorable with Actual's
 * Import file → Actual, as a new budget.
 */
export async function backupBudget(
  session: BudgetSession,
  budget: BudgetRef,
  dir: string,
  options: { now?: () => Date } = {},
): Promise<BackupFile> {
  if (!FOLDER_RE.test(budget.syncId)) throw new BackupNotFoundError();
  const started = Date.now();
  const bytes = await session.withBudget(budget, (port) => port.exportBudget());
  const now = options.now?.() ?? new Date();
  const file = writeBackup(dir, budget.syncId, now, BUDGET_EXT, bytes);
  log.info(
    { budgetSyncId: budget.syncId, file, sizeKb: Math.ceil(bytes.length / 1024), ms: Date.now() - started },
    'Budget backed up',
  );
  return findBackup(dir, budget.syncId, file).entry;
}

let cachedVersion: string | undefined;
function appVersion(): string {
  if (cachedVersion) return cachedVersion;
  try {
    // dist/backup.js and src/backup.ts both sit one level below package.json.
    cachedVersion = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8')).version as string;
  } catch {
    cachedVersion = 'unknown';
  }
  return cachedVersion;
}
