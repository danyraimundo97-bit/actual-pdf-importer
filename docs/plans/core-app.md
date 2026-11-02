# Plan: core of the app

Source: `backend_app/Docs/Todo.md` §1, "Core of the app". Branch `feature/core-app`.

Goal: turn the importer into an everyday Actual app. Four features, in the TODO's priority order:

1. Add a transaction in seconds (e.g. a cash purchase).
2. Balances and recent transactions (extend the existing dashboard).
3. This month's budget: how much is left in each category.
4. Statement import with category memory (already exists; only moves in the navigation).

Architecture stays Flutter → backend (gateway) → Actual via `@actual-app/api`. Every new Actual
call goes through `session.withBudget` and the narrow `ActualPort`; every new failure mode is a
typed `ImporterError` with a stable `code`.

**The backend and the Actual connection are both optional** (TODO §2): the app works on its own
(statements parsed and categorised on the phone, with predefined categories; see the
dart-parser plan), the backend runs without an Actual server, and both links are set up from the
app, not `.env`. Every feature below therefore has three states (*no backend*, *backend without
Actual*, *connected*), and Milestone 1 comes before anything that reads or writes Actual.

**The backend's role** narrows to: syncing with Actual (this plan), scheduled backups of the
Actual budget (`feature/backups`), the AI parser fallback, and the copy of the category memory
that refills a phone when it connects (dart-parser plan).

---

## Milestone 0 — Backend groundwork

- **Widen `ActualPort`** (`src/budget-session.ts`) with `getBudgetMonth` and `getAccountBalance`
  (if not already derivable from `getTransactions`). Add them to the fake adapter in
  `src/__tests__/budget-session.test.ts` / `fake-actual.ts`.
- **One endpoint per screen** (TODO §2 performance): each screen below gets a single call that
  returns everything it needs, built by a pure `build*` function that's unit-tested without the
  SDK (same pattern as `dashboard.ts`).
- **Sync throttling** (TODO §2): the session re-syncs at most every N seconds (e.g. 5 s,
  `SYNC_INTERVAL_MS` env) instead of on every turn. Writes force a sync afterwards. Unit-test the
  throttle in `budget-session.test.ts` with a fake clock.

## Milestone 1 — Optional Actual connection, set from the app

Today `server.ts` builds the budget session once at startup from `ACTUAL_*`, silently defaulting
to `http://localhost:5006`; with no Actual server the backend starts, but the first Actual call
fails with a connection error.

**Backend**

- **Connection store** `src/actual-connection.ts`: persists `{ serverUrl, password }` in a small
  file/SQLite next to the category DB (file mode 0600). Source of truth, in order: `.env`
  `ACTUAL_SERVER_URL` if set (then the connection is *locked*: shown in the app, not editable),
  otherwise the stored one, otherwise *not configured*. No more silent `localhost:5006` default.
- **Reconfigurable session**: `BudgetSession.reconfigure(serverConfig | null)` runs as a turn
  (so it waits for in-flight work): shuts the adapter down, forgets the loaded budget, swaps the
  config. With `null`, every `withBudget`/`withServer` throws a new typed
  `ActualNotConfiguredError` → `ACTUAL_NOT_CONFIGURED` (409) before touching the SDK. Unit tests
  with the fake adapter: reconfigure during a turn, unconfigured turn, failed reconfigure leaves
  nothing loaded.
- **Routes**
  - `GET /actual/connection` → `{ configured, locked, serverUrl, hasPassword, serverVersion? }`.
    Never returns the password.
  - `PUT /actual/connection` `{ serverUrl, password }` → tests first (`<server>/info` for the
    version — warn below 26.10 per TODO §2 — then a login), saves only if it works, then
    `reconfigure`. Errors: `ACTUAL_UNREACHABLE`, `ACTUAL_AUTH_FAILED`,
    `ACTUAL_VERSION_TOO_OLD`, `CONNECTION_LOCKED`.
  - `DELETE /actual/connection` → back to not configured (also forgets the cached budget dir).
  - Refuse `PUT`/`DELETE` with 403 `AUTH_REQUIRED` when `IMPORT_TOKEN` is unset: otherwise anyone
    on the LAN could point the backend at their own server.
- `GET /config` gains `actual: { configured, locked }` so the app learns the state in the call it
  already makes. `/health` stays Actual-free.
- `.env.example` and `INSTALL.md`: `ACTUAL_*` documented as optional overrides; `CLAUDE.md`
  architecture notes updated (session is no longer fixed at startup).

**App**

- Settings: a **Connection** section covering both links: the backend (URL + token, today's
  form) and, once the backend answers, the Actual server (URL, password, Test & save,
  Disconnect; read-only with a note when `locked`). The Actual password goes straight to the
  backend and is not kept on the phone.
- Onboarding: see "Setup guide: connecting is the optional last step" below.
- `appConfigProvider` exposes `actualConnected`; screens that need Actual show one shared
  "Connect your Actual server" empty state (new widget in `shared/widgets/`) with a button to
  Settings, instead of an error. Any `ACTUAL_NOT_CONFIGURED` response flips the state too.
- What works without Actual (and without a backend): reading, reviewing and categorising
  statements with the predefined categories, CSV export, category memory, settings. Review's
  import button becomes "Connect Actual to import".

### Setup guide: connecting is the optional last step

Today `features/setup/screens/setup_screen.dart` has four steps: Connect (backend) → Check →
Budget → Done, and the backend and the budget are both required. New flow, two steps, nothing
required:

1. **How it works**: the facts from today's Check step (how statements are read, privacy,
   categories), reworded for a phone-only app, plus a peek at the predefined categories
   ("you can rename or add your own"). No network.
2. **Bring your budget along**: the backend + Actual connection, optional and the last step.
   It replaces the Connect, Budget and Done steps, so the guide always ends here, connected or
   not.

`onboarded` becomes true when the guide is finished, either way. Installs that already have a
backend and budget count as onboarded and connected, unchanged.

**The "Bring your budget" page** (`features/setup/widgets/actual_step.dart`), a page that sells
the connection without forcing it, in the same visual language as Welcome (the product as the
illustration, motion that means something):

- **Hero, animated**: the reviewed statement rows from the Welcome animation slide into an
  "Actual" budget card, which fills up: a balance counts up, two category bars grow, a "To
  budget" chip pops in. About 1.5 s, once, using `figures()` for the numbers. Respects
  `MediaQuery.disableAnimations` (shows the end state).
- **Headline** "Bring your budget along", subtitle "Connect to Actual to import statements and
  see your money here. Everything else already works on this phone. You can also do this later."
- **Two short columns**, so the choice is honest:
  - *With Actual*: balances and recent transactions, this month's budget, quick add, import
    into your accounts.
  - *Already works without it*: reading statements on this phone, reviewing and categorising
    them, category memory, CSV export.
- **Two actions pinned at the bottom**: primary "Connect Actual", secondary text button
  "Not now". "Not now" finishes the guide (with a one-line note: "You can connect any time in
  Settings → Connection") and lands on Import.
- **Connect expands in place** (`AnimatedSize`, no new route), in two parts, because the app
  reaches Actual through the backend (it can't run Actual's sync engine):
  1. *Your bridge*: backend URL and token (today's Connect form and its checks, moved here),
     with a one-line explanation and a link to `INSTALL.md`'s Docker setup.
  2. *Your Actual server*, shown once the backend answers: server URL (hint
     `http://192.168.1.x:5006`) and server password, then "Test & connect". Skipped when the
     backend's `.env` already sets it (see Locked).

  The states are shown inline on the card:
  - testing → a spinner on the button;
  - errors by `code` (`ACTUAL_UNREACHABLE`, `ACTUAL_AUTH_FAILED`, `ACTUAL_VERSION_TOO_OLD` with
    the version found, `AUTH_REQUIRED` explaining that the backend needs `IMPORT_TOKEN` set
    first), each with what to check;
  - success → a check-mark animation with the server version, and the budget list slides in
    below (the current `_BudgetStep` list, moved here). Picking a budget enables "Finish",
    which lands on Home.
- **Locked** (`.env` sets the server): no form, the card just shows "Connected to <url> (set
  on the backend)", straight to the budget list.
- Back from this step goes to How it works; the form keeps what was typed.
- After a budget is picked, the "Match your categories" sheet (dart-parser plan, Phase 4) opens
  if the predefined/local categories are already in use.

Code changes: `_stepCount` 4 → 2, `_ConnectStep`, `_BudgetStep` and `_DoneStep` folded into the
new widget, `/setup?step=` clamp in `router.dart` and the dev page's "Setup n" jump buttons go to 0–1,
`setup_flow_test.dart` updated, plus new widget tests: "Not now" finishes un-connected, the
success path with a fake API, an error `code` shown inline, and the locked variant.

Settings' "Connection" section reuses the same form widget, without the hero.

## Milestone 2 — Quick add

**Backend: `POST /transactions`**

```jsonc
// request
{ "budgetSyncId": "…", "accountId": "…", "date": "2026-11-01",
  "amountCents": -450, "payeeName": "Café", "categoryId": "…", "notes": "",
  "clientId": "uuid-v4" }
// response
{ "id": "…", "created": true }
```

- New module `src/transactions.ts` with `addManualTransaction(session, budgetRef, input)`.
- Implemented with `importTransactions` and `imported_id: "app-<clientId>"`: a retry after a
  dropped response is a no-op instead of a duplicate, and Actual's rules still run on the payee.
  The `app-` prefix keeps it out of the PDF undo path (which only touches `pdfimport-`).
- Validation → `INVALID_FIELD` / `MISSING_FIELD` (400); unknown account → typed error (404).
- On success, `recordMapping(payee, category, scope)` in `categorydb` so the memory learns from
  manual entries too.

**Backend: `GET /quick-add/options?budgetSyncId=`** — one call for the screen: on-budget
accounts, category groups, recent payees (last ~50 distinct, with their last category). Pure
`buildQuickAddOptions` + tests.

**App**

- Full-screen route `/add` (root navigator, like `/review`), opened from a FAB in `AppShell`
  visible on Home and Budget.
- Layout, top to bottom: big amount field with expense/income toggle (expense default) and the
  numeric keyboard open on entry; payee field with autocomplete from recent payees; category
  (prefilled from the payee's last category or the category memory, picked with the existing
  `category_picker_sheet.dart`); account (remembers the last one in `settings_store`); date
  (today); optional note. Save is enabled once amount + account are set.
- `features/quick_add/quick_add_controller.dart` (Riverpod `Notifier`) owns the form and
  generates `clientId` once per form, so a retried save reuses it.
- After save: pop back with a confirmation snackbar and invalidate the dashboard/budget
  providers. No "Undo" button yet, since editing and removing are out of scope (see "Not in this
  plan").
- Tests: controller unit tests (validation, clientId reuse on retry, sign handling), widget test
  for the happy path with a fake `ImporterApi`.

- Not connected: the FAB is still shown and opens the "Connect your Actual server" state.

## Milestone 3 — Balances and recent transactions

The dashboard (`GET /dashboard`) already returns balances, net worth and recent transactions.

- **Account detail**: `GET /accounts/:id/transactions?budgetSyncId=&before=&limit=50` —
  cursor-paged by `(date, id)`, newest first, with payee/category names resolved server-side and
  split children folded under their parent. Pure `buildAccountPage` + tests.
- **App**: tapping an account on the dashboard opens `/accounts/:id` (inside the Home branch)
  with the balance header and an infinitely scrolling list; pull-to-refresh on both screens.
- Dashboard tweaks: recent-transactions rows tap through to their account.

## Milestone 4 — This month's budget

**Backend: `GET /budget-month?budgetSyncId=&month=2026-11`**

- New `src/budget-month.ts`: `getBudgetMonth` turn + pure `buildBudgetMonth` returning
  `{ month, toBudgetCents, groups: [{ id, name, categories: [{ id, name, budgetedCents,
  spentCents, balanceCents, carryover }] }] }`. Hidden categories and income groups excluded
  from the "left to spend" view (income shown separately).
- Unknown/out-of-range month → typed error. Tests with recorded `getBudgetMonth` shapes.
- Note: tracking budgets vs. envelope budgets return different shapes; detect and handle both, or
  return `BUDGET_TYPE_UNSUPPORTED` for tracking budgets in v1.

**App**

- New **Budget** tab: month switcher (‹ Nov 2026 ›), "To budget" header, groups as collapsible
  sections, each category a row with remaining amount and a thin progress bar (overspent in the
  error color). Uses `figures()` and `Space`/`Radii` tokens.
- Read-only in this plan (no moving money between categories).

## Milestone 5 — Navigation

Tabs become: **Home** (dashboard) · **Budget** · **Import** · **Settings**. Without Actual, Home
and Budget show the connect state, and the app opens on Import instead of Home. Category memory moves
from its own tab to a row in Settings (and a link from the Import screen). Share-sheet intake stays
in `AppShell`, so it keeps working from any tab. Update `router.dart` and the onboarding redirect
tests.

## Testing / done criteria

- `npm test` green, with unit tests for every new `build*` function, the sync throttle and
  `addManualTransaction` against the fake adapter (including the idempotent retry).
- `flutter analyze && flutter test` green.
- Backend started with no `ACTUAL_*` at all: starts, `/parse` works, Actual routes answer
  `ACTUAL_NOT_CONFIGURED`; connecting from the app's Settings then works without a restart.
- Manual run against a copy of a real budget (never the real server first — see TODO §2 on
  versions): add a cash expense, see it on the dashboard and in the budget month, retry a save
  with the network cut mid-request and confirm no duplicate.

## Not in this plan

- Editing or removing transactions (needs the TODO §2 soft-delete rule and better auth first).
- Moving money between budget categories.
- Offline queue for quick add (the `clientId` design makes it possible later).
- Per-device tokens / HTTPS (TODO §2), but don't expose the new write endpoint beyond the LAN
  until that lands.

## Overlap with `feature/dart-parser`

Both branches touch `features/import/` and `data/providers.dart`. This branch only moves Import in
the navigation; keep its changes to `inbox_controller.dart` at zero so the parser branch can merge
cleanly. Merge this one first.
