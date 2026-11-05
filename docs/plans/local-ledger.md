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
4. **The database is encrypted** from the start, before it holds any amounts. It uses SQLite3MultipleCiphers in
   the end, not SQLCipher (see "Phase 1 as built").

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

### Phase 1 as built (2026-11-04)

- **SQLite3MultipleCiphers, not SQLCipher.** `package:sqlite3` 3.x (already in the app through
  drift) bundles both through its build hook, and `sqlcipher_flutter_libs` is obsolete for it. The
  package recommends `sqlite3mc`: a newer SQLite, no OpenSSL, and a wasm build for the web if that's
  wanted later. It's selected in `pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlite3mc`),
  and `sqlite3` is now a direct dependency.
- `lib/data/local/db/database_file.dart`:
  - `applyDatabaseKey` runs `PRAGMA hexkey` with a key checked to be 64 hex characters. It refuses
    to run on a SQLite without encryption, which is checked once on an in-memory database.
  - `prepareDatabaseFile` runs on a background isolate before drift opens the file. The outcome
    (`DatabaseOpening`) is one of:
    - `created`;
    - `opened`;
    - `encrypted`: a plain file was encrypted with `PRAGMA hexrekey`. A `.pre-encryption` copy is
      kept until the file has been read back, and put back on any failure;
    - `reset`: the key doesn't open the file. It's renamed to `app.sqlite.unreadable` (one copy
      kept, in case the key turns up) and the app starts empty.
- `open_connection_native.dart` keeps `drift_flutter`'s opener and its file
  (`<documents>/app.sqlite`, so existing installs are converted, not replaced), and passes the key
  in `DriftNativeOptions.setup`. The options are built in a top-level function, so the closures
  sent to drift's isolate only hold two strings. The web (`open_connection_web.dart`) keeps
  `driftDatabase(name: 'app')` unencrypted.
- `SecretStore.databaseKey()` creates the key once (32 bytes from `Random.secure()`).
  `clearAll()` (the dev page's "Wipe everything") now keeps it, because the database isn't wiped
  there and couldn't be opened without it.
- On `reset`:
  - the category sync positions are cleared (`SettingsStore.clearCategorySync`), so a backend
    refills the categories and memory on the next sync instead of thinking the phone has them;
  - `AppShell` says once: "This phone's data was reset", pointing to the next sync and to
    Settings › Backups.
- **Android Auto Backup** (`allowBackup` is on by default) copies `app.sqlite` to the user's Google
  backup. It is now encrypted there. Restored on a new phone, it lands without its key, because
  Keystore-backed secure storage isn't restored, so it takes the `reset` path, as intended.
- Tests (`test/database_encryption_test.dart`, 7) use the real encrypted SQLite on the host:
  - a new file isn't plain and opens again;
  - a plain schema 2 file with a user category is encrypted and keeps it;
  - a wrong key sets the file aside, and the right key still opens the copy;
  - a malformed key is refused;
  - the drift options can be sent to an isolate;
  - the key is created once and survives "Wipe everything".
- App tests: 129 pass, 1 skipped. The analyzer shows the same 15 notes as before.
- **Not verified here:** an Android build. This machine has no Android SDK, so the first run on the
  phone is the check:
  - an existing install upgrades with its categories and memory intact;
  - a fresh install works;
  - `adb shell run-as … head -c 16 files/app.sqlite`, or the documents directory, shows no
    `SQLite format 3` header.

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

### Phase 2 as built (2026-11-04)

- **Tables** (`lib/data/local/db/ledger_tables.dart`, schema 3, migrated with `createTable` from 2):
  - `LedgerAccounts`, `LedgerPayees`, `LedgerTransactions`, `LedgerBudgets`, `LedgerOutbox`,
    `LedgerSyncState`, as in the data model.
  - `LedgerTransactions` has a unique `(accountId, importedId)` and indexes on `(accountId, date)`
    and `(scope, date)`. `categoryId` has no foreign key, because an Actual category can arrive after
    its transactions.
- **`LedgerStore`** (`lib/data/local/ledger_store.dart`):
  - accounts: create with an opening balance, update, reorder, close, set or remove the opening
    balance;
  - payees: found by name, ignoring case, or created;
  - transactions:
    - added one at a time or as a statement batch, skipping importedIds the account already has
      (removed ones included, as in Actual);
    - edited without ever touching `importedId`;
    - removed as a tombstone;
    - transfers and splits refuse edits on the phone;
  - budget amounts: set, read a month, copy last month.
  - Every write queues its row in `LedgerOutbox` in the same database transaction. There's one entry
    per row: a second change keeps its place, and a removal turns it into a `delete`.
  - `watchAccounts` gives live balances: the sum of each account's live top-level rows, so the
    opening balance is included.
- **Settings › Accounts** (`features/accounts/screens/accounts_settings_screen.dart`, sheet in
  `widgets/account_sheet.dart`):
  - open accounts, then a "Closed" group, each with its balance;
  - one sheet for the name, the balance (today's for a new account, the opening one when editing; a
    minus is money owed), "Off budget", and Close/Reopen.
  - The Settings overview shows the row while Actual isn't connected, with the number of accounts.
- `parseAmountInput` moved to `core/format/money.dart` (quick add re-exports it), next to the new
  `parseSignedAmountInput` and `centsToInput`.
- Logs carry account ids only: no names or amounts.
- Tests:
  - `ledger_store_test.dart` (13): balances and order, opening balances, scopes, the same statement
    twice, a removed row still counting as imported, payees by name, edits keeping `importedId`,
    budget amounts, the outbox order and ops, and the 2 → 3 migration;
  - `accounts_settings_test.dart` (4): adding from the empty state, validation, editing the opening
    balance and closing.
  - The Settings tests now give the accounts provider a fixed list, because a drift stream never
    settles in a widget test.
  - 146 pass, 1 skipped. The analyzer shows the same 15 notes as before.

## Phase 3: Save reviewed statements on the phone

- Review always saves to the ledger: **Save** (no Actual), or **Import** (Actual connected: saved to
  the ledger and sent with the next sync, which runs straight away). CSV export moves to the menu.
- The account picker shows ledger accounts, suggested by `bankId` (the last one used for that bank),
  with "New account…".
- It teaches the category memory as now, and pops back with an `ImportResult`, so the inbox and
  import history are unchanged. It reports added and skipped (already on the phone).
- Removing an import (undo) becomes deleting its rows in the ledger. The sync turns that into
  `/import/undo`'s soft delete in Actual.

### Phase 3 as built (2026-11-04)

- **Only the "no Actual" side is built here.** With Actual connected, Review still imports straight
  into Actual as before. Saving those lines into the ledger as well needs Actual's accounts in the
  ledger, and those arrive with the sync (Phase 5). That phase switches Import over to the ledger.
- **Review** (`ReviewScreenArgs.saveOnPhone`, set by the Import tab while Actual isn't connected):
  - a "Save into" picker under the header lists the phone's open accounts, with "New account…"
    (the account sheet from Phase 2, which also records the statement's bank on the new account);
  - the suggestion is `suggestLedgerAccount` (`features/review/phone_save.dart`): the account that
    bank's statements last went into (`SettingsStore.lastLedgerAccountFor`), else an account set up
    for that bank (`bankId`), else the only account. With a real choice it suggests nothing, so a
    statement never lands in the wrong account unseen;
  - **Save N transactions** (no confirmation dialog: it can be removed from Recent imports). CSV
    export moved to the app bar. The CSV-only screen stays for the one case with neither: Actual
    connected but no account to import into;
  - it remembers categories on the phone as the CSV path did, then shows the result sheet ("Saved on
    this phone": added, already on the phone, categorized) and pops with an `ImportResult` whose
    `phoneAccount` is set.
- **`LedgerStore.addStatement`** keeps the opening balance true. That balance is what the account
  held on its date ("Balance today" when it was added), so lines on or before that date were already
  in it. The opening balance gives them back and moves to the day before the earliest one. Example:
  an account is added on 4 November with 1.000,00, and October's statement is saved afterwards. The
  balance on 4 November is still 1.000,00.
- **Import tab:**
  - with Actual missing, the Account field explains that statements go into the phone's accounts,
    with links to Settings › Accounts and to connecting Actual;
  - a saved statement shows "Saved: N added, M already on the phone";
  - Recent imports keeps it with `onPhone`. Removing it tombstones its rows
    (`LedgerStore.deleteTransactions`), and saving the statement again doesn't bring them back, as in
    Actual.
- Logs: account ids and counts only.
- Tests:
  - `ledger_store_test.dart` (+3): the opening balance kept through a statement, no opening balance,
    removing a saved statement;
  - `review_save_on_phone_test.dart` (6): the suggestion rules, drafts keeping `importedId`, the
    history entry's `onPhone`, saving into the only account and then the same statement again,
    adding an account from the picker.
  - 155 pass, 1 skipped. The analyzer shows the same 15 notes as before.

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

### Phase 4 as built (2026-11-04)

- **Only without Actual, as in Phase 3.** `readsLedgerProvider` is true whenever the link state isn't
  `ready`. Home, Budget and the account screen then read the phone's ledger (scope `''`). With
  Actual connected they still call `/dashboard`, `/budget-month` and `/accounts/:id/transactions`,
  because the ledger holds no copy of an Actual budget until Phase 5. Phase 5 switches them over
  and stops calling those routes.
- **Pure builders** (`lib/data/local/ledger_builders.dart`), returning the same models as the
  backend, so the screens didn't change shape:
  - `buildLedgerDashboard` ports `buildDashboard` rule for rule. Its tests
    (`ledger_builders_test.dart`) are the backend's `dashboard.test.ts` cases. Removed rows and
    closed accounts are dropped.
  - `buildLedgerBudgetMonth` covers both styles (`BudgetStyle.tracking` / `envelope`, named as in
    Actual), with the rules written in its doc comment:
    - spent: on-budget flows by category, refunds counting back;
    - income: income categories only, as in Actual. Uncategorized money in isn't income yet;
    - envelopes: a positive leftover carries, and an overspent one carries only with `carryover`
      (otherwise it comes out of next month's To budget);
    - the month switcher runs from the first month with data to next month.
  - **Not yet checked against Actual's numbers.** The rules follow Actual's documented behaviour.
    The comparison with a real budget needs Actual's data in the ledger, so it moves to Phase 5.
  - Spending in a hidden category, or one the phone doesn't know, isn't shown in the budget. "Hold
    for next month" isn't modelled.
- **`LedgerReports`** (`lib/data/local/ledger_reports.dart`) loads the rows and calls the builders.
  The account page pages by offset, 50 at a time.
- **Live updates:** `ledgerChangesProvider` fires on any ledger table change (drift
  `tableUpdates`), and the Home, Budget and account providers watch it.
- **Budget style:** stored in `LedgerSyncState.budgetMode` for the phone's scope
  (`LedgerStore.budgetMode`), defaulting to simple limits. Choosing it in the app is Phase 7.
- **Screens:**
  - Home: `RequiresActual` is gone. With no accounts it says "Start with your accounts" and offers
    "Add an account" (Settings › Accounts). With accounts but no transactions it offers "Import a
    statement". "Add a transaction" waits for offline quick add (Phase 6). A quiet "Kept on this
    phone" line sits under net worth (`OnPhoneStatus`, which Phase 5 extends with the sync state).
  - Budget: `RequiresActual` is gone too. Tapping a category sets its amount for the month
    (`budget_amount_sheet.dart`), and "Copy last month" appears while nothing is budgeted. With
    Actual it stays read-only.
  - Account screen: tapping a row edits payee, amount, date, category and notes, or removes it
    (`ledger_transaction_sheet.dart`, removal is a tombstone). Transfers, splits and the opening
    balance aren't editable there; the opening balance is changed in Settings › Accounts.
- Quick add and Import only refresh Home's provider when Home is showing (`ref.exists`).
  Invalidating it otherwise starts it, and it then waits on the link state.
- Tests:
  - `ledger_builders_test.dart` (12): the dashboard cases, both budget styles, carryover, the month
    range;
  - `ledger_screens_test.dart` (4): Home empty and filled, setting a budget amount, editing and
    removing a row, all with no backend;
  - 171 pass, 1 skipped. The analyzer shows the same 15 notes as before.

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

### Home and Budget redesign (2026-11-05, between 5a and 5b)

A redesign that keeps the app's tokens, fonts, routes and data.

- **Home:** the order now follows the questions: net worth and the sync line, this month (in, out, net,
  share of the budget), accounts in a vertical list grouped On budget / Off budget, the latest 5
  transactions under day headers, where the money went as ranked bars (not a donut), six months of
  in and out with past months dimmed, then top payees.
- **Budget:** the month switcher stays fixed; a new month slides in 180 ms from the side you moved
  toward, and the old month stays on screen while the next is read, so the skeleton doesn't flash.
  Used categories show what's left, a bar, spent, and the budgeted amount (a chip on the phone's own
  budget). Unused ones are one quiet line. Folded groups stay folded across months and show one bar.
- **Motion:** the 900 ms count-up on opening is gone: figures appear at once and only ease (180 ms)
  when they change on screen. Rows answer a press (`Pressable`, scale 0.98).
- `formatBalance` (no plus) is for levels such as balances and what's left; `formatCents` stays for
  movements.
- Checked by rendering both screens in light and dark with synthetic data. Not yet seen on a phone.

### Phase 5 in three parts

Phase 5 is built and committed in three parts:

- **5a, mirror:** the pull. With Actual connected, the phone keeps a copy of the budget, and Home,
  Budget and the account screen read it, offline too. Read-only on the phone.
- **5b, push:** the phone's changes to that copy go up to Actual. Budget amounts and account rows
  become editable with Actual too, and Import and quick add write to the ledger first.
- **5c, first connection:** the phone's own accounts and rows (scope `''`) move into the budget.

### Phase 5a as built (2026-11-04)

- **Backend, `GET /ledger/pull`** (`src/ledger.ts`):
  - **One budget turn per pull.** The cursor is `{epoch, lastId}` on Actual's change log, as decided
    in Phase 0.
  - **Epochs:** they live in `ledger-epochs.json` (mode 0600) next to the category DB, one per
    budget. A new epoch starts when the log's first entry changes: a fresh cache or "Reset sync"
    starts the log again from id 1. An empty log that starts filling keeps its epoch.
  - **Full or changes:** another epoch, no cursor, or a cursor past the log's end gets a full pull.
    Otherwise the pull sends only the transactions and budget amounts the log names since `lastId`,
    removed ones included as tombstones. Accounts, category groups, payees and the budget's mode
    always come whole, because they're small.
  - **The app's own soft delete:** a transaction removed by this app (its note starts with
    `[Removed via PDF importer`) is sent as removed.
  - **Gzipped** when the client accepts it, using `zlib`, with no new dependency.
  - Reads Actual's internals, so `actual-adapter.ts` is the only file that does it. `init()`'s handle
    is kept there, behind `ActualPort.ledger` (`LedgerPort`), with SELECTs only: `messages_crdt`,
    the `budgetType` preference, and `zero_budgets`/`reflect_budgets`. Transactions come through
    `aqlQuery` (`splits: 'all'`, `withDead()` for changes).
  - Tests (`ledger.test.ts`, 7) cover full and delta pulls, the soft delete, a new epoch, a cursor
    past the end, and the epoch file.
- **Checked against the real SDK** (the Phase 0 scratch server, script in the session scratchpad):
  - a full pull of 3,002 transactions and 145 budget amounts in 300 ms, opening the budget included;
  - after one edit through the API, the next pull returned that transaction alone, in 9 ms.
- **Budget numbers checked against Actual** (the item Phase 4 left open). The scratch budget, an
  envelope budget, was pulled into the phone's database. For each of its 39 months, the phone's
  `buildLedgerBudgetMonth` gave the same values as Actual's own `getBudgetMonth`, as the backend
  shapes it: To budget, totals, income, and every category's budgeted, spent and left. **No
  differences.**
  - Cases covered: 144 overspent category-months, 11 carried leftovers, 36 months with a negative
    To budget, carryover flags (set on one category, which Actual carries into the next 15
    months), and an uncategorized income (Actual leaves it out of To budget, and so does the
    phone).
  - Not checked: a tracking ("simple limits") budget. The API can't switch a budget's type, so that
    needs a budget made as tracking in Actual's web app.
- **App:**
  - **Schema 4:** `LedgerCategories` holds an Actual budget's categories, with their group, order
    and hidden flags. `importedId` is no longer unique per account, because Actual doesn't enforce
    it and a pulled budget can repeat one; it's an index now. A version 3 file is rebuilt with
    `alterTable`, and the migration is tested.
  - **`LedgerSync.pull`** (`lib/data/local/ledger_sync.dart`) applies a pull in one database
    transaction:
    - accounts, payees and categories are replaced, and missing ones are marked removed (rows made
      on the phone, `acct:`/`payee:`, are left alone);
    - a full pull replaces the transactions and budget amounts, and a delta upserts them;
    - an account Actual deleted that old transactions still use gets a removed stand-in;
    - rows with a pending outbox entry keep the phone's version;
    - pulled rows never go into the outbox.
  - **`LedgerSyncController`** (`lib/data/ledger_sync_controller.dart`):
    - one run at a time;
    - triggered by AppShell on connection changes (next to the category sync), after an import, a
      removed import or a quick add, and by pull-to-refresh on Home and Budget;
    - `ensurePulled` makes a screen wait for the first copy, so an empty copy never reads as an
      empty budget.
  - **Screens:** `ledgerScopeProvider` picks the connected budget's sync id, or `''` without
    Actual. Home, Budget and the account screen now always read the ledger, so the app no longer
    calls `/dashboard`, `/budget-month` or `/accounts/:id/transactions`. The backend keeps them for
    now; remove them after a release. The status line (`LedgerStatus`) says "Synced 5 min ago",
    "Syncing with Actual…", or "Couldn't reach Actual · synced …".
  - **Still read-only with Actual:** editing there comes in 5b.
  - Tests (`ledger_sync_test.dart`, 6) cover a first pull then a delta, a full pull replacing rows
    with scopes kept apart, pending rows surviving a pull, a removed account, the budget mode, and
    the 3 → 4 migration.
  - 177 app tests pass, 1 skipped. The analyzer shows the same 15 notes as before. Backend: 110 of
    111 pass. The one failure is the known Node 26 "bad XRef entry" in `pdf-password.test.ts`
    (Todo).

### Phase 5b as built (2026-11-05)

- **Backend:** `POST /ledger/push` (`src/ledger-push.ts`), one budget turn, answered per entry with
  a code, never a message. A statement's lines go in one `importTransactions` call (separately, a second
  identical line would fuzzy-match the first) and are found again by `imported_id`, since Actual may
  match a line to a row it already had. Quick-add rows use `addTransactions` with `app-<clientId>`
  (or `app-<the row's uuid>`). Edits are whole-row `updateTransaction`s that never touch `imported_id`.
  Removals are the soft delete plus the removal log. Transfers and splits answer `READ_ONLY`.
- **Safe to resend:** transactions by `imported_id`; accounts and payees through
  `ledger-client-ids.json`, since nothing in Actual can carry a phone id; a new payee reuses one of
  the same name. Carryover flags and on/off budget aren't sent: the phone has no editor for carryover,
  and Actual doesn't offer changing on/off budget.
- **Phone:** `LedgerSync.push` sends payees, accounts, transactions, then budget amounts, 200 per
  request. Answered entries leave the outbox and rows take Actual's ids, along with what points at them.
  `ledger_id_aliases` (schema 5) keeps the old id working for an open screen or an import's undo. A
  change made while its entry was on the way bumps the entry's `revision`, so it goes in the next run.
- **Ledger first:** quick add and Import with Actual write to the ledger, and the sync sends them. Budget
  amounts and account rows are editable with Actual too. `AppShell` asks for a sync when the number
  of waiting changes grows. The status line shows "N changes waiting" or "N changes couldn't be sent".
- **Quick add** now reads its accounts, categories and recent payees from the ledger, so it opens
  without a backend or Actual, and offers to add an account when there is none. That's Phase 6.
- **A backend that can't be reached** no longer takes the budget off screen: `ledgerScopeProvider`
  stays on a budget that has a copy.
- **Checked** against a real Actual 26.10 server with synthetic rows: new payee, account, opening
  balance, quick add, two identical statement lines, budget amount, all sent twice without duplicates;
  then an edit, a soft delete, a rename, closing an account with money in it (refused), and a row gone
  from Actual; a following pull returned the changes.
- **Not yet:**
  - Import still lists Actual's accounts from the backend, so importing into Actual needs a connection.
  - A refused change stays until it's changed or Actual accepts it. There's no screen to see or
    discard it, only the status line and the logs.
  - A row removed on the phone before its first answer arrived comes back with the next pull if
    Actual did get it.

### Phase 5c as built (2026-11-05)

- **Offered, never automatic:** with Actual connected, Home says how many accounts are only on the phone
  ("Not now" is remembered per budget; Settings › Accounts keeps the way in). `/move-accounts` lists each
  account with where it goes: a new account, or one of the budget's (one with the same name is preselected).
  Categories with the same name link by themselves; the rest go through "Match your categories", and the
  screen says how many transactions would arrive without a category.
- **The move is local:** `LedgerMove.intoBudget` is one database transaction with no network. Rows join the
  budget's copy with their outbox entries and the normal sync sends them, so a failure can't leave it half
  done and it also works with the backend away.
- **What it decides:**
  - An account joining another leaves its opening balance behind, since that one has its own.
  - A payee joins the budget's payee of the same name; phone payees nothing uses aren't sent.
  - A local category id never goes: it's translated through `category_links` or dropped.
  - A budget amount only fills an empty spot, and amounts of unlinked categories stay on the phone.
  - Removed rows that were never sent are dropped.
- **Opening balances:** the push gives them Actual's "Starting Balance" payee and starting balances category.
- **Checked** with tests, and the opening balance against a real Actual 26.10 server with synthetic rows. The
  whole move hasn't run against a real server or on a phone.
- **Not yet:**
  - A closed account arrives open (the screen says so): the push never closes a new account while its
    rows are on their way.
  - A row that's already in Actual but wasn't imported from a statement (typed in both places) arrives
    as a second row. Statement lines are matched by `importedId`.

### Category emojis (2026-11-05)

- Presets have one by key (`PresetCategory.emoji`, Emoji 2 or older, for Android 6). `categories.emoji`
  (schema 6) holds the user's choice: null = not chosen, '' = none. It travels with the category sync and
  backups in the row's `data`, so the backend needed no change.
- Settings › Categories: tap the emoji to choose one or type your own.
- Actual has no field for it, so an Actual category uses an emoji at the start of its name (taken off the
  name on screen), then the linked phone category's, then one of the same name. Without any, its first
  letter holds the column. Names stay untouched in the database and in Actual.
- Shown in Budget, Home, the account screen, the pickers, quick add and Review. The column is the width of
  the group's chevron, so names didn't move. Quiet rows dim theirs; screen readers skip it; no motion.

## Phase 6: Quick add offline

Built with 5b (see "Phase 5b as built").

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
