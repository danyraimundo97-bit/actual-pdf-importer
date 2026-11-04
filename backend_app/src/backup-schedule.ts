/**
 * When backups run (docs/plans/backups.md, Phase 2).
 *
 * No cron: a timer checks every 15 minutes whether a backup is *due*
 * (`nextDue`, a pure function), so a backend that was off at the scheduled
 * time backs up at its next check instead of waiting a whole period. Each
 * run makes an app-data backup and, with Actual connected, one per chosen
 * budget. Budget backups are ordinary session turns, so they queue behind
 * in-flight Actual work and never run alongside it.
 *
 * Settings live in `backup-settings.json` next to the category DB, mode
 * 0600, since they can hold encrypted budgets' passwords; the last result
 * per folder in `backup-state.json`.
 */
import fs from 'fs';
import path from 'path';
import type { Logger } from 'pino';
import { listBudgets } from './actual';
import {
  APP_DATA_FOLDER,
  backupAppData,
  backupBudget,
  pruneBackups,
  type BackupFile,
} from './backup';
import type { BudgetSession } from './budget-session';
import {
  ActualNotConfiguredError,
  BudgetNotFoundError,
  BudgetPasswordRequiredError,
  ImporterError,
  InvalidFieldError,
} from './errors';
import { logger } from './logger';

export const FREQUENCIES = ['off', 'daily', 'weekly', 'monthly', 'yearly'] as const;
export type Frequency = (typeof FREQUENCIES)[number];

export interface BackupBudget {
  syncId: string;
  name?: string;
  /** Only for end-to-end encrypted budgets; never sent back to the app. */
  password?: string;
}

export interface BackupSettings {
  frequency: Frequency;
  /** Local time of the backend, `HH:MM`. */
  time: string;
  /** How many backups to keep, per budget and for app data. */
  keep: number;
  budgets: BackupBudget[];
}

export const DEFAULT_SETTINGS: BackupSettings = { frequency: 'off', time: '03:00', keep: 10, budgets: [] };

export interface TargetState {
  lastAttemptAt?: string;
  lastSuccessAt?: string;
  lastFile?: string;
  lastError?: { code: string; message: string };
}

/** Per folder: `app-data` or a budget's sync id. */
export type BackupState = Record<string, TargetState>;

/** A failed backup is tried again after this long, not a whole period later. */
export const RETRY_AFTER_MS = 60 * 60 * 1000;
export const CHECK_EVERY_MS = 15 * 60 * 1000;

// --- When ----------------------------------------------------------------------

function atTime(day: Date, time: string): Date {
  const [h, m] = time.split(':').map(Number);
  return new Date(day.getFullYear(), day.getMonth(), day.getDate(), h, m, 0, 0);
}

function daysInMonth(year: number, month: number): number {
  return new Date(year, month + 1, 0).getDate();
}

/** The calendar day one period after `from` (months and years clamp to the month's end). */
export function addPeriod(from: Date, frequency: Exclude<Frequency, 'off'>): Date {
  const y = from.getFullYear();
  const m = from.getMonth();
  const d = from.getDate();
  switch (frequency) {
    case 'daily':
      return new Date(y, m, d + 1);
    case 'weekly':
      return new Date(y, m, d + 7);
    case 'monthly': {
      const ny = m === 11 ? y + 1 : y;
      const nm = (m + 1) % 12;
      return new Date(ny, nm, Math.min(d, daysInMonth(ny, nm)));
    }
    case 'yearly':
      return new Date(y + 1, m, Math.min(d, daysInMonth(y + 1, m)));
  }
}

/**
 * When this folder's next backup is due; null when backups are off.
 * Never backed up → now. Last attempt failed → an hour after it. Otherwise
 * the scheduled time, one period after the day of the last success.
 */
export function nextDue(settings: Pick<BackupSettings, 'frequency' | 'time'>, state: TargetState | undefined, now: Date): Date | null {
  if (settings.frequency === 'off') return null;
  const success = state?.lastSuccessAt ? new Date(state.lastSuccessAt) : null;
  const attempt = state?.lastAttemptAt ? new Date(state.lastAttemptAt) : null;
  if (attempt && (!success || attempt > success)) return new Date(attempt.getTime() + RETRY_AFTER_MS);
  if (!success) return now;
  return atTime(addPeriod(success, settings.frequency), settings.time);
}

export function isDue(settings: Pick<BackupSettings, 'frequency' | 'time'>, state: TargetState | undefined, now: Date): boolean {
  const due = nextDue(settings, state, now);
  return due !== null && due.getTime() <= now.getTime();
}

// --- Settings -------------------------------------------------------------------

/** Checks what the app sent; keeps a stored password when the app sends none for that budget. */
export function parseSettings(body: unknown, current: BackupSettings): BackupSettings {
  const b = (body ?? {}) as Record<string, unknown>;
  const frequency = b.frequency ?? current.frequency;
  if (typeof frequency !== 'string' || !(FREQUENCIES as readonly string[]).includes(frequency)) {
    throw new InvalidFieldError('frequency', `one of ${FREQUENCIES.join(', ')}`);
  }
  const time = b.time ?? current.time;
  if (typeof time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) {
    throw new InvalidFieldError('time', 'HH:MM, 24-hour');
  }
  const keep = b.keep ?? current.keep;
  if (typeof keep !== 'number' || !Number.isInteger(keep) || keep < 1 || keep > 365) {
    throw new InvalidFieldError('keep', 'a whole number from 1 to 365');
  }
  let budgets = current.budgets;
  if (b.budgets !== undefined) {
    if (!Array.isArray(b.budgets) || b.budgets.length > 20) throw new InvalidFieldError('budgets', 'a list of up to 20');
    budgets = b.budgets.map((raw) => {
      const r = (raw ?? {}) as Record<string, unknown>;
      if (typeof r.syncId !== 'string' || !/^[A-Za-z0-9-]{1,64}$/.test(r.syncId)) {
        throw new InvalidFieldError('budgets', 'each needs a syncId');
      }
      const before = current.budgets.find((x) => x.syncId === r.syncId);
      // `password`: a string sets it, null forgets it, absent keeps it.
      const password =
        typeof r.password === 'string' && r.password ? r.password : r.password === null ? undefined : before?.password;
      return {
        syncId: r.syncId,
        name: typeof r.name === 'string' ? r.name.slice(0, 200) : before?.name,
        ...(password ? { password } : {}),
      };
    });
  }
  return { frequency: frequency as Frequency, time, keep, budgets };
}

/** The settings as the app sees them: whether a password is kept, never the password. */
export function publicSettings(settings: BackupSettings) {
  return {
    ...settings,
    budgets: settings.budgets.map(({ syncId, name, password }) => ({ syncId, name, hasPassword: Boolean(password) })),
  };
}

export interface JsonStore<T> {
  read(): T;
  write(value: T): void;
}

export function jsonFileStore<T>(file: string, fallback: T): JsonStore<T> {
  return {
    read() {
      try {
        return { ...fallback, ...JSON.parse(fs.readFileSync(file, 'utf8')) };
      } catch {
        return structuredClone(fallback);
      }
    },
    write(value) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      const tmp = `${file}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(value, null, 2), { mode: 0o600 });
      fs.renameSync(tmp, file);
      fs.chmodSync(file, 0o600);
    },
  };
}

export function defaultBackupFiles(env: NodeJS.ProcessEnv = process.env) {
  const dataDir = path.dirname(env.CATEGORY_DB_PATH || './data/categories.db');
  return { settings: path.join(dataDir, 'backup-settings.json'), state: path.join(dataDir, 'backup-state.json') };
}

// --- Running ------------------------------------------------------------------------

export interface RunResult {
  folder: string;
  ok: boolean;
  file?: BackupFile;
  error?: { code: string; message: string };
}

export interface BackupScheduler {
  /** Starts the periodic check (and checks once right away). */
  start(): void;
  stop(): void;
  /** Backs up now, whether due or not. Nothing given = app data + every chosen budget. */
  runNow(what?: { kind?: 'app-data' | 'budget'; budgetSyncId?: string }): Promise<RunResult[]>;
  /** One check: backs up whatever is due. */
  check(): Promise<RunResult[]>;
  settings(): BackupSettings;
  updateSettings(next: BackupSettings): void;
  state(): BackupState;
  nextDue(folder: string): Date | null;
}

export function createBackupScheduler(deps: {
  dir: string;
  session: BudgetSession;
  settingsStore: JsonStore<BackupSettings>;
  stateStore: JsonStore<BackupState>;
  now?: () => Date;
  intervalMs?: number;
  log?: Logger;
}): BackupScheduler {
  const log = deps.log ?? logger.child({ area: 'backup' });
  const now = deps.now ?? (() => new Date());
  let timer: NodeJS.Timeout | undefined;
  // Runs are serialized: a manual one waits for a scheduled one.
  let queue: Promise<unknown> = Promise.resolve();

  const enqueue = <T>(fn: () => Promise<T>): Promise<T> => {
    const run = queue.then(fn, fn);
    queue = run.catch(() => undefined);
    return run;
  };

  function record(folder: string, result: RunResult, at: Date) {
    const state = deps.stateStore.read();
    const prev = state[folder] ?? {};
    state[folder] = result.ok
      ? { lastAttemptAt: at.toISOString(), lastSuccessAt: at.toISOString(), lastFile: result.file?.file }
      : { ...prev, lastAttemptAt: at.toISOString(), lastError: result.error };
    deps.stateStore.write(state);
  }

  async function runOne(folder: string, make: () => Promise<BackupFile>): Promise<RunResult> {
    const at = now();
    let result: RunResult;
    try {
      const file = await make();
      pruneBackups(deps.dir, folder, deps.settingsStore.read().keep, file.file);
      result = { folder, ok: true, file };
    } catch (err) {
      const error =
        err instanceof ImporterError
          ? { code: err.code, message: err.message }
          : { code: 'BACKUP_FAILED', message: "The backup failed. The backend's log has the details." };
      if (err instanceof ImporterError) log.warn({ folder, code: err.code }, 'Backup skipped');
      else log.error({ err, folder }, 'Backup failed');
      result = { folder, ok: false, error };
    }
    record(folder, result, at);
    return result;
  }

  async function backUpBudgets(budgets: BackupBudget[]): Promise<RunResult[]> {
    if (budgets.length === 0) return [];
    if (!deps.session.isConfigured()) {
      const err = new ActualNotConfiguredError();
      return Promise.all(budgets.map((b) => runOne(b.syncId, () => Promise.reject(err))));
    }
    let known: Awaited<ReturnType<typeof listBudgets>> | undefined;
    const results: RunResult[] = [];
    for (const b of budgets) {
      results.push(
        await runOne(b.syncId, async () => {
          known ??= await listBudgets(deps.session);
          const info = known.find((k) => k.syncId === b.syncId);
          if (!info) throw new BudgetNotFoundError(b.syncId);
          if (info.encrypted && !b.password) throw new BudgetPasswordRequiredError();
          return backupBudget(deps.session, { syncId: b.syncId, budgetPassword: b.password }, deps.dir, { now });
        }),
      );
    }
    return results;
  }

  const appData = () => runOne(APP_DATA_FOLDER, async () => backupAppData(deps.dir, { now: now() }));

  async function check(): Promise<RunResult[]> {
    const settings = deps.settingsStore.read();
    if (settings.frequency === 'off') return [];
    const state = deps.stateStore.read();
    const at = now();
    const results: RunResult[] = [];
    if (isDue(settings, state[APP_DATA_FOLDER], at)) results.push(await appData());
    // A budget can't be backed up without Actual; a scheduled run just
    // waits for it to be connected instead of recording a failure every 15 minutes.
    if (deps.session.isConfigured()) {
      results.push(...(await backUpBudgets(settings.budgets.filter((b) => isDue(settings, state[b.syncId], at)))));
    }
    return results;
  }

  return {
    start() {
      if (timer) return;
      const tick = () =>
        void enqueue(check).catch((err) => log.error({ err }, 'Backup check failed'));
      tick();
      timer = setInterval(tick, deps.intervalMs ?? CHECK_EVERY_MS);
      timer.unref();
    },
    stop() {
      if (timer) clearInterval(timer);
      timer = undefined;
    },
    runNow(what = {}) {
      return enqueue(async () => {
        const settings = deps.settingsStore.read();
        const results: RunResult[] = [];
        if (what.kind !== 'budget') results.push(await appData());
        if (what.kind !== 'app-data') {
          let budgets = settings.budgets;
          if (what.budgetSyncId) {
            budgets = budgets.filter((b) => b.syncId === what.budgetSyncId);
            if (budgets.length === 0) budgets = [{ syncId: what.budgetSyncId }];
          }
          results.push(...(await backUpBudgets(budgets)));
        }
        return results;
      });
    },
    check: () => enqueue(check),
    settings: () => deps.settingsStore.read(),
    updateSettings(next) {
      deps.settingsStore.write(next);
      log.info(
        { frequency: next.frequency, time: next.time, keep: next.keep, budgets: next.budgets.length },
        'Backup settings changed',
      );
    },
    state: () => deps.stateStore.read(),
    nextDue(folder) {
      return nextDue(deps.settingsStore.read(), deps.stateStore.read()[folder], now());
    },
  };
}
