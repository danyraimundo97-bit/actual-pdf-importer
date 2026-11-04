# Plan: scheduled backups of the Actual budget and the app's category memory

Branch `feature/backups`. Decided 2026-11-02.

## The backend's role from now on

The app does everything it can on its own: parsing, reviewing, categories, category memory. The
backend keeps only what a phone can't do:

1. **Sync with Actual**: the gateway through `@actual-app/api` (the core-app plan).
2. **Backups**, on a schedule: daily, weekly, monthly or yearly (this plan), of two things:
   - the **Actual budget**;
   - the **app's data**: categories (predefined ones as renamed/hidden, and the user's own) and
     the category memory (payee → category), plus the backend's removal log.
3. **The AI parser**, as the opt-in fallback for statements no on-device parser recognises
   (kept; API keys can't ship in the app).
4. **The copy of the category memory that refills a phone.** When a phone connects to the
   backend, its local database is repopulated from the backend and Actual (dart-parser plan,
   Phase 4, "Repopulate on connect").

Statement parsing with the regex parsers leaves the backend once the Dart port has replaced it
(dart-parser plan, Phase 6).

Depends on `feature/core-app` Milestone 1: the connection store, the reconfigurable budget
session and `ACTUAL_NOT_CONFIGURED`. Uses the logger from `feature/logging`. The app-data
backup also needs the phone's local database and its sync (`feature/dart-parser`, Phase 4).
Merge order: logging → core-app → dart-parser → backups. The branch now sits on dart-parser (Phase 4d included).

---

## Phase 0 — Verify the backup format (done 2026-11-03)

A backup must be restorable with Actual's own **Import file → Actual**.

Checked against a scratch `@actual-app/sync-server` 26.10.0 with `@actual-app/api` 26.10.0 and a
sample budget (one account, a category group, two categorised transactions, a budgeted amount):

- `@actual-app/api` 26.10 has `exportBudget()` (the same handler as Actual's **Export**) and
  `importBudget()` (the same as **Import file → Actual**). The export is a zip of `db.sqlite` +
  `metadata.json`, made inside the budget's mutator queue from an in-memory copy, so it can't
  catch the file mid-write. No `db.backup()`, no zip library, no knowledge of the cache layout
  (`<dataDir>/<budget-id>/{db.sqlite,cache.sqlite,metadata.json}`) needed.
- Importing the zip gives back the same accounts, categories, transactions and budgeted amounts,
  as a **new** budget on the server (new `groupId` and `cloudFileId`): restoring never overwrites
  the original. `metadata.json` carries `resetClock: true`, which makes Actual start a fresh sync
  history for the copy.
- `metadata.json` holds the server's user id. A backup is the whole budget anyway: backups are
  as private as the budget and are only served with the token.

## Phase 1a — App data backup

Needs only the backend, **not** Actual, so it also works for someone who never connects a budget.

- **What reaches the backend**: done in dart-parser Phase 4d. `POST /categories/sync` keeps the
  phone's groups, categories and links (`app_categories`, opaque JSON per row, newest
  `updatedAt` wins) and the category memory (`payee_categories`, with tombstones) on the backend.
  The phone syncs on start, on connection changes and shortly after every edit.
- **Format**: one gzipped JSON file, `BACKUP_DIR/app-data/<YYYY-MM-DD_HHmmss>.json.gz` (no zip
  library; opens anywhere):

  ```jsonc
  { "manifest": { "kind": "app-data", "schemaVersion": 1, "createdAt": "<ISO>", "appVersion": "0.1.0" },
    "appCategories": [{ "kind", "id", "data", "updatedAt" }],          // all rows
    "mappings": [{ "budgetSyncId", "payee", "categoryId", "categoryName", "updatedAt" }],  // live only
    "removals": [ RemovedTransaction ] }
  ```

  Written to a `.tmp` name and renamed when complete, so a crash never leaves a half-written
  file that looks valid. Read from SQLite in one transaction, so it's consistent.
- Never touches Actual, so it never waits for a budget session turn.

**Restore** (automated, unlike the budget, since it only touches the backend's own data). No file
swapping and no "replace mode" on the phones: a restore is written as *new edits*, so the normal
sync carries it everywhere.

- Backend `POST /backups/app-data/:file/restore`:
  1. makes a fresh app-data backup first (the "before restore" safety copy, name suffixed
     `-before-restore`, never pruned automatically);
  2. refuses a newer `schemaVersion` with `BACKUP_TOO_NEW` (older ones are upgraded in code);
  3. in one transaction: every row of the backup is written with `updated_at` = now (so it wins
     over every phone's older edit); every live mapping that isn't in the backup becomes a
     tombstone with `updated_at` = now; removal-log rows missing here are added (the log is only
     ever added to).
- App: Settings → Backups → an app-data backup → "Restore". The phone syncs first (so the
  backend knows its latest rows), then restores, then syncs again and ends up as the backup.
  Other phones pick it up on their next sync.
- Known limit: app categories have no tombstones (the app hides, never deletes), so a category
  created after the backup stays; mappings to it are forgotten by the restore.

**No backend at all**: Settings → Backups shows "Export app data" instead: the phone's tables in
the same JSON shape (its mappings carry the phone's own category ids), gzipped in memory and
handed to the share sheet, and "Import app data" to read one back. One format both ways.

## Phase 1b — Actual budget backup

`src/backup.ts`, `backupBudget(session, budgetRef, backupDir)`:

1. One budget session turn: `withBudget(budget, …)` downloads/syncs, so the copy is up to date,
   and inside it `port.exportBudget()` (added to `ActualPort`).
2. Write the bytes to `BACKUP_DIR/<budget-sync-id>/<YYYY-MM-DD_HHmmss>.zip` via a `.tmp` name +
   rename. The folder is the sync id (stable, safe as a path); the listing shows the budget name.
3. Log at info (budget id, size, duration) or error (with the stack). Never the contents.

- **Encrypted budgets**: the backup is only possible with the budget password. The app can let
  the backend keep it for backups (opt-in, stored in the 0600 connection store); without it the
  budget is skipped and a warn line + a status in the app say why.
- `BACKUP_DIR` (default `./backups` next to the category DB, i.e. `data/backups`) is inside
  Docker's data volume. Document in `INSTALL.md` that backups on the same disk as the Actual
  server don't protect against losing that disk.

## Phase 2 — Schedule

One schedule for both kinds; each run makes an app-data backup and, when Actual is connected,
one budget backup per scheduled budget. Settings stored in the connection store and edited from
the app:

```jsonc
{ "frequency": "off" | "daily" | "weekly" | "monthly" | "yearly",
  "time": "03:00",            // local time of the backend
  "keep": 10,                 // how many backups to keep, per budget and for app data
  "budgets": ["<syncId>", …]  // default: the budget(s) the app selected
}
```

- **No cron.** An in-process timer checks every 15 minutes whether a backup is *due*: a pure
  function `isDue(lastBackupAt, frequency, time, now)`. This survives restarts and a backend that
  was off at 03:00: the backup runs at the next check, not the next day. Weekly = 7 days after
  the last one, monthly = same day next month (clamped to the month's end), yearly likewise.
- `lastBackupAt` and the last result are stored per budget, so a failure shows up and a
  successful run is never repeated.
- Backups run as normal session turns, so they wait for in-flight requests and never run at the
  same time as another Actual operation.
- After each backup, prune to `keep` per budget, newest kept. Pruning never deletes the backup it
  just made, and never runs after a failure (a broken backend mustn't eat its own history).

## Phase 3 — Routes

All require the token. Changing settings or deleting is refused with `AUTH_REQUIRED` when
`IMPORT_TOKEN` is unset, as for the connection routes.

| Route | Does |
|---|---|
| `GET /backups/settings` · `PUT /backups/settings` | read / change the schedule |
| `GET /backups` | app data + per budget: list (date, size), last run, last error, next due |
| `POST /backups` `{ kind?: "app-data" \| "budget", budgetSyncId? }` | back up now (everything if nothing given) |
| `GET /backups/:folder/:file` | download one zip (`folder` = `app-data` or a budget) |
| `DELETE /backups/:folder/:file` | delete one |
| `POST /backups/app-data/:file/restore` | restore app data (Phase 1a) |

File names are validated against the listing (never joined from user input straight into a
path), so `../` can't reach outside `BACKUP_DIR`. Typed errors: `BACKUP_NOT_FOUND`,
`BACKUP_FAILED`, `BUDGET_PASSWORD_REQUIRED`, `BACKUP_TOO_NEW`, plus `ACTUAL_NOT_CONFIGURED` for
budget backups when there's no Actual (app-data backups don't need it).

**Restoring a budget** is documented, not automated, in v1: download the zip from the app or from
`BACKUP_DIR`, then in Actual's web app **Import file → Actual**. Pushing a backup back onto the
server automatically is too easy to get wrong (it would replace the live budget).

## Phase 4 — App

Settings → **Backups** (with a backend: everything below; budget parts only when Actual is
connected; with no backend: just "Export app data" / "Import app data"):

- Frequency as a segmented control: Off · Daily · Weekly · Monthly · Yearly; time picker; "Keep
  last N" stepper.
- Status card: last backup (time, size) or the last error in plain words, and when the next one
  is due. "Back up now" button.
- Two lists, "App data" and one per budget, each backup with Share (downloads to memory and hands it to the share
  sheet, so it can go to Drive, email, a computer) and Delete with confirmation.
- App-data backups also get "Restore" (Phase 1a); budget backups get a short "How to restore"
  sheet with the Import file → Actual steps.

## Tests

- `isDue` for every frequency: first run, exactly on time, backend off over the due time, month
  ends (31 Jan → 28/29 Feb), leap years for yearly.
- Pruning: keeps `keep` newest, never the new one, nothing after a failure.
- `backupBudget` with the fake adapter and a temporary dir: the exported bytes land in the
  budget folder, `.tmp` never left behind, encrypted budget without password skipped.
- App data: file contents + manifest; restore makes the safety copy first, refuses a newer
  `schemaVersion`, wins over older phone edits, tombstones mappings made after the backup, and a
  phone syncing afterwards ends with the backup's memory; export → import round-trip with no
  backend.
- Routes: path traversal refused, `AUTH_REQUIRED` without a token, `ACTUAL_NOT_CONFIGURED`.
- App: settings round-trip, status card states, share flow with a fake API.

## Not in this plan

- Automatic restore to the Actual server.
- Off-site copies (S3, Drive). Sharing from the app covers it by hand; revisit later.

---

## As built (2026-11-03, uncommitted)

- Backend:
  - `src/backup.ts` (files, app data, budget, restore, pruning) and `src/backup-schedule.ts`
    (`nextDue`, settings, scheduler);
  - the routes in `server.ts`;
  - `exportBudget` added to `ActualPort`;
  - `exportCategoryData` / `restoreCategoryData` in `categorydb.ts` and `listAllRemovals` in
    `removal-log.ts`;
  - error codes `BACKUP_NOT_FOUND`, `BACKUP_INVALID`, `BACKUP_TOO_NEW`, `BACKUP_FAILED` and
    `BUDGET_PASSWORD_REQUIRED`;
  - `BACKUP_DIR` in `.env.example` and `docker-compose.yml`, and a "Backups" section in
    `INSTALL.md`.
- Backend tests in `src/__tests__/backup.test.ts`: 13 tests covering the stamp, the format and
  manifest, refusals, restore through the sync, path traversal, pruning, budget backup, `addPeriod`
  and `nextDue`, settings, and the scheduler with and without Actual.
- Checked end to end against a scratch Actual 26.10 server:
  - settings, back up now, download, and restore;
  - a budget backup holds `db.sqlite` + `metadata.json`;
  - `../` gets 404 and no token gets 401;
  - the settings file is mode 0600.
- App:
  - Settings → Backups (`features/backups/screens/backups_screen.dart`, route
    `/settings/backups`) and `BackupsApi`;
  - the app-data file format on the phone (`data/local/db/app_data_file.dart`, export/import
    with or without a backend);
  - the category row read/write moved out of `CategorySync` into `app_category_rows.dart` so both
    use it;
  - tests in `test/backups_test.dart`.
- **Differences from the plan above:**
  - app data is `.json.gz`, not a zip;
  - restore writes new edits instead of swapping DB files, so there's no "replace mode" on phones;
  - the budget backup uses `exportBudget()`, with no `db.backup()` and no zip library.
- **Not done:**
  - Choosing budgets other than the selected one for backups. The switch covers the selected
    budget; switching budget in Settings and turning it on adds another.
  - A check on a real phone.
