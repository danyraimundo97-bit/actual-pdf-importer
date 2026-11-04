# Plan: a local ledger that works offline and syncs with Actual

Branch `feature/local-ledger`. Started 2026-11-04.

## Why

The backend and Actual are optional, but Home, Budget and the account screen only show "Connect
Actual" until both are set up. The phone has nothing to show there: its database holds categories,
the category memory and category links, and a statement reviewed without Actual only becomes a CSV
export. Quick add needs Actual too.

The phone starts keeping the money itself, a **local ledger**: accounts, transactions and monthly
budget amounts in the app's database. Home, Budget and the account screen always read from it, with
or without a connection. When Actual is connected, the ledger **syncs with it both ways**:

- it downloads Actual's accounts, transactions and budget amounts;
- it uploads what the phone saved while it wasn't connected.

## Decisions (2026-11-04)

1. **With Actual connected, the phone syncs with it both ways.** The ledger is the phone's offline
   copy of the budget, plus a queue of changes waiting to go up. It isn't a separate, offline-only
   store.
2. **The budget style is a setting**: *simple monthly limits* or *envelopes*. Without Actual, the
   default is simple limits; with Actual, the phone follows the budget's own mode (Actual's "tracking"
   budget is the same as simple limits). The guide explains both (Phase 7).
3. **Copying the ledger to a backend without Actual is left for later** (`backend_app/Docs/Todo.md`).
   Usually a phone with a backend also has Actual; a phone with neither backs up with its own export
   file.
4. **The database is encrypted** (SQLCipher) from the start, before it holds any amounts.

### The two budget styles, in one example

Groceries is set to €300 a month. In October you spend €250.

- **Simple monthly limits**: October shows "Spent €250 of €300", and November starts again at €300.
  Overspending shows in that month only.
- **Envelopes**: the €50 left over stays in the Groceries envelope, so November holds €350.
  Overspending is taken from the next month. "To budget" is income not yet put in any envelope.

Both store the same thing, an amount per category per month, so switching styles or uploading to
Actual loses nothing. Only the totals shown are worked out differently.

## Principles

- **The screens stay; the data source changes.** Home renders a `Dashboard`, Budget a `BudgetMonth`
  and the account screen an `AccountPage`. The ledger builds the same models with pure Dart builders
  ported from the backend, so the screens don't fork and work offline even with Actual connected.
- **Same ids as Actual.** A statement transaction keeps its `importedId` (`pdfimport-…`), and a quick
  add keeps its `clientId` (`app-<clientId>` in Actual). Importing the same statement twice is a no-op
  on the phone, and uploading can't duplicate what Actual already has.
- **Changes go up as a queue.** Every change made on the phone is a ledger row plus an outbox entry.
  Sync sends the outbox first, then downloads, so an offline edit isn't overwritten by the older
  version still in Actual.
- **Category ids stay local.** Ledger rows use the phone's category ids. Only the upload translates
  them, through `category_links`, as imports do now. Actual's categories reach the phone as
  `actual:<id>` rows, as the category sync already makes them.
- **No deleting in Actual.** A transaction removed on the phone is soft-deleted in Actual (amount
  0.00 plus a note, original kept in the removal log), as removing an import already does.
- **Privacy.** PDFs are still never stored. The ledger keeps only the parsed fields (date, payee,
  amount, category, notes) and never `rawLine`, in an encrypted file. Amounts and balances are still
  never logged at any level; ids and counts are fine.

## Data model (drift schema 3)

Every ledger row has a `scope`: `''` for the phone's own budget (no Actual yet), or the
`budgetSyncId` of the Actual budget it mirrors. Switching budgets shows that budget's copy; the
phone's own rows go up into the first budget connected (Phase 5).

```
LedgerAccounts      scope, id ('acct:<uuid>' on the phone, Actual's id once known), name,
                    offBudget, closed, sort, bankId (nullable: suggests the account on import),
                    updatedAt, deleted
LedgerPayees        scope, id ('payee:<uuid>' or Actual's id), name, transferAccountId (nullable),
                    updatedAt, deleted
LedgerTransactions  scope, id ('tx:<uuid>' or Actual's id), accountId, date (YYYY-MM-DD),
                    amountCents, payeeId (nullable), categoryId (nullable), notes, cleared,
                    importedId (nullable, unique per account), startingBalance,
                    transferId (nullable), parentId (nullable, for split children),
                    updatedAt, deleted
LedgerBudgets       scope, categoryId, month (YYYY-MM), budgetedCents, carryover, updatedAt
LedgerOutbox        seq, scope, kind (account | transaction | budget), rowId, op (put | delete),
                    createdAt, attempts, lastError (an error code, never a message with data)
LedgerSyncState     scope, budgetMode ('tracking' | 'envelope'), lastPulledAt,
                    cursorEpoch, cursorLastId (Phase 0)
```

- Transfers and splits from Actual are stored and shown. On the phone they are read-only in v1;
  editing them is listed under "Not in this plan".
- The budget style setting lives in `LedgerSyncState.budgetMode` for an Actual scope (taken from
  Actual) and in settings for the phone's own scope.

## Phase 0: Spike, finding what changed in Actual

`@actual-app/api` has no "changed since" call, and Actual's transactions have no `updatedAt`. Before
building the sync, find the cheapest reliable way to download only what changed, using a scratch
sync-server (as backups Phase 0 did):

- **A**: read Actual's CRDT message log (`messages_crdt`, timestamp per changed cell) through
  `runQuery`/the internal db, and return the rows touched since a cursor.
- **B**: one hash per account and month. The phone sends its hashes, and the backend returns only the
  months that differ. No reliance on Actual internals.
- **C**: download everything each time. This is the fallback for small budgets, to measure against.

Write down the result here with timings for a realistic budget (a few thousand transactions).

### Phase 0 result (2026-11-04): A, with C as the fallback

Measured against a scratch `@actual-app/sync-server` 26.10.0 and `@actual-app/api` 26.10.0, on a
budget of 3,000 transactions (3 accounts, 6 categories, 24 months of budget amounts). A second
client then edited 5 transactions, deleted 2, added 3, renamed a payee and changed a budget amount.
The scripts are in the session scratchpad, not the repo.

| | What it costs | What it finds |
|---|---|---|
| **A**, the change log | Reading the log: under 1 ms. Fetching the 10 changed rows by id (`aqlQuery` with `withDead()`, so deletions come back as tombstones): 2 ms. | Exactly the 10 transactions, plus `payees` (the rename and the new payee), `payee_mapping` and `zero_budgets` (the budget amount). Nothing extra. |
| **B**, hashes per account and month | Query plus hashing: about 40 ms, then the phone has to hash the same fields the same way. | The 2 months that changed. **Misses payee renames**: transactions hold the payee's id, so their rows don't change. |
| **C**, everything | Query: 35 ms. 1.1 MB of JSON, 109 KB gzipped. | Everything, so it's always right. |

The cached budget opens in about 110 ms (a first download takes about 350 ms), and that's needed
for all three.

**How the change log works** (`messages_crdt` in the budget's `db.sqlite`):

- Every change Actual applies is a row: `dataset` (a table), `row` (an id) and `column`. The SDK
  writes it as it applies the change, while syncing is on. Import mode (`runImport`) writes none.
- **Use `id`, not `timestamp`, as the cursor.** `id` is the order the backend *received* changes.
  The timestamp is the other device's clock: an edit made offline arrives later carrying an older
  timestamp. In the test, an offline edit stamped 13:24:06 arrived after a change stamped 13:24:11.
  It got `id` 77, after the cursor at 76, so a cursor on `id` caught it and one on the timestamp
  would have lost it.
- The log is per cache. A fresh download starts it empty (the downloaded file carries no history),
  and Actual's "Reset sync" empties it (`DELETE FROM messages_crdt`). It survives backend restarts,
  because the cache lives in `ACTUAL_DATA_DIR`.
- It's reached through the handle `init()` returns (`handle.db`, read-only `SELECT` only). That's
  Actual's internals, so it stays in `src/actual-adapter.ts` behind one `ActualPort` method, with a
  test that fails loudly if the table's shape changes in a new SDK version.
- Payees, categories and accounts change in their own tables, so the phone keeps payees as rows
  (`LedgerPayees`), not as text copied into each transaction.
- The budget's mode is the `budgetType` preference (`tracking`, or unset/`envelope`). Its amounts
  come from `zero_budgets` (envelope) or `reflect_budgets` (tracking).

**Decision: A, with C as the fallback.**

- The cursor is `{epoch, lastId}`. The backend keeps one `epoch` per budget (a random id, in a small
  file next to the category DB) and replaces it whenever the log can't be trusted: the cache was
  just created, `MAX(id)` went backwards, or the oldest row changed. A cursor with another epoch
  gets a full pull (C), which at this size costs the same as opening the budget.
- C is also the first pull, and the answer to any doubt. It's cheap: about 110 KB gzipped for
  3,000 transactions. Responses should be gzipped (Dio accepts it).
- B isn't used: it can't see payee renames, and it doubles the hashing rules on the phone.
- The backend's own pushes also land in the log, so a phone sees its uploaded rows come back once.
  That's harmless, because applying them is idempotent.

## Phase 1: Encrypted database

- Swap `drift_flutter`'s default sqlite for `sqlcipher_flutter_libs`, which can't be in the app
  alongside `sqlite3_flutter_libs`. Open the database with `PRAGMA key`, using a random 256-bit key
  that `SecretStore` creates once and keeps in `flutter_secure_storage`.
- Convert existing installs once: open the old plain file, `ATTACH` an encrypted one,
  `sqlcipher_export`, and swap the files. Test it from a schema 2 file with categories, memory and
  links.
- If the key is lost (secure storage cleared, or a restore to a new phone), the database can't be
  read. The app then starts with an empty one and says so. Recovery is the backup file or the next
  sync with Actual.
- Web keeps the unencrypted wasm database (SQLCipher isn't available there). This is noted in the
  Flutter-web Todo item.

## Phase 2: Ledger store and accounts

- `LedgerStore` (`lib/data/local/ledger_store.dart`) handles:
  - accounts: create, rename, close, reorder, opening balance;
  - transactions: add, insert a statement batch that skips known `importedId`s, edit, delete;
  - budget amounts: set, copy last month.
  Every write adds its outbox entry in the same database transaction.
- Stream providers for the rows, so the screens update as rows change.
- Settings → **Accounts**: a list with an add button, and a sheet for the name, on/off budget and
  opening balance.
- Tests: migration 2 → 3, dedupe on `importedId`, tombstones, and an outbox entry written with every
  change.

## Phase 3: Save reviewed statements on the phone

- Review always saves to the ledger: **Save** (no Actual), or **Import** (Actual connected: saved to
  the ledger and sent with the next sync, which runs straight away). CSV export moves to the menu.
- The account picker shows ledger accounts, suggested by `bankId` (the last one used for that bank),
  with "New account…".
- It teaches the category memory as now, and pops back with an `ImportResult`, so the inbox and
  import history are unchanged. It reports added and skipped (already on the phone).
- Removing an import (undo) becomes deleting its rows in the ledger. The sync turns that into
  `/import/undo`'s soft delete in Actual.

## Phase 4: Home, Budget and the account screen from the ledger

- Pure builders, ported and tested the same way as the backend's:
  - `buildDashboard`, from `backend_app/src/dashboard.ts`: balances from every row; flows from
    on-budget accounts only, without transfers or opening balances; splits read by their children.
  - `buildBudgetMonth`, in both styles, from `budget-month.ts` and Actual's own rules. Envelopes:
    `balance = budgeted − spent + last month's balance` (overspending carried only where
    `carryover`), and "To budget" from all income so far. Simple limits: no carry-over, and
    "To budget" = this month's income − budgeted. Check both against Actual's numbers for a sample
    budget, so the phone and Actual show the same totals.
- `dashboardProvider`, `budgetMonthProvider` and the account provider read the ledger. `RequiresActual`
  comes off Home and Budget, and the backend's `/dashboard`, `/budget-month` and
  `/accounts/:id/transactions` are no longer called by the app (kept for now, removed after a
  release).
- A quiet status line: "On this phone", "Synced 2 min ago", or "3 changes waiting to sync".
- First run with an empty ledger: Home shows one empty state with "Import a statement" and "Add a
  transaction".
- Budget: tapping a category edits its amount for the month. Account screen: tapping a row edits or
  deletes it. This covers the Todo item "Edit and remove transactions in the app".
- Tests: builder unit tests mirroring `dashboard.test.ts` and `budget-month.test.ts`; widget tests
  with Home and Budget filled and no backend at all.

## Phase 5: Sync with Actual

The backend gets routes for the ledger, each one budget turn:

- `GET /ledger/pull?budgetSyncId=&epoch=&lastId=`: when the epoch matches, only the rows the change
  log names since `lastId` (transactions with tombstones, payees, accounts, categories, budget
  amounts); otherwise everything. It always includes the budget's mode, and returns the new
  `{epoch, lastId}`. Gzipped.
- `POST /ledger/push`: a batch of outbox entries.
  - New statement rows go through the same path as `/import/confirm` (keeping `importedId`).
  - New manual rows go through `/transactions` (`app-<clientId>`).
  - Edits use `updateTransaction`, and deletes use the soft delete.
  - Budget amounts use `setBudgetAmount`.
  - New accounts use `createAccount`; opening balances become Actual's starting balance.
  - It answers per entry, so one bad row doesn't block the rest.

On the phone, `LedgerSync`, next to the existing `CategorySync` and triggered the same way (on
start, on connection changes, shortly after an edit, and pull-to-refresh):

1. Push the outbox in order. Entries that succeed are removed, and new rows get Actual's ids. An
   entry that fails stays, with its error code, and is shown in the status line.
2. Pull, and apply Actual's version, except for rows that still have a pending outbox entry.
3. **The first connection** with the phone's own rows (scope `''`): map each phone account to an
   Actual account (or create one), run "Match your categories" for the categories used, then move the
   rows to the budget's scope and push them. The ids make this safe to repeat after a failure.

Conflicts: the phone's pending change wins for that row; otherwise Actual's version wins. That's
"newest wins", the same as the category sync, because a pending change is newer than the last pull.

Tests: backend route tests against the fake `ActualAdapter`, and on the phone, sync against fake APIs
covering push order, a run that stops partway and continues, pending rows surviving a pull, and the
first-connection move.

## Phase 6: Quick add offline

- Quick add writes to the ledger (accounts and categories from the phone, `app-<clientId>`) and
  teaches the category memory. It works with no connection, and the sync sends it later. This covers
  the Todo item "Offline queue for quick add".
- The button shows on Home and Budget in every link state once an account exists; without one, it
  offers to create an account first.

## Phase 7: The budget style setting and the guide

- Settings → **Budget style**: Simple monthly limits / Envelopes. With Actual connected, it shows the
  budget's mode and explains it is set in Actual (changing Actual's mode is out of scope).
- The guide:
  - Setup's "How it works" gets a short page on the budget, with the Groceries example in both
    styles and the choice.
  - Settings → Help gets "How budgeting works", the same content, for later.
- Widget tests for both styles on the Budget tab at 320 dp with 2× text, in light and dark (as the
  Settings tests do).

## Phase 8: Backups include the ledger

- App-data file `schemaVersion` 2 adds the phone's own-scope ledger (accounts, transactions, budget
  amounts, settings). Budgets synced with Actual are backed up by Actual's own backup, not
  duplicated. An older app refuses a newer file with `BACKUP_TOO_NEW`, and a version 1 file still
  restores.
- Restoring writes the rows as new edits, as the categories do.

## Not in this plan

- Copying the ledger to a backend without Actual, for its scheduled backups and a second phone
  (in `backend_app/Docs/Todo.md`).
- Editing transfers and splits on the phone; changing Actual's budget mode from the app.
- Recurring or scheduled transactions; reports beyond Home's.

## Order and size

Phase 0 decides Phase 5's pull. Phases 1 → 2 → 3 → 4 give a working offline app without any sync
(the phone's own scope only); 5 then connects it to Actual; 6 – 8 can go in any order after 4. Each
phase is its own commit on this branch, with "As built" notes added here.
