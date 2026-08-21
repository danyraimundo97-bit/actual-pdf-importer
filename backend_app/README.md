# actual-pdf-importer — backend

A 100% offline, privacy-first mobile app and Node.js bridge to parse bank PDFs (ActivoBank, moey!, Trade Republic) directly into Actual Budget.

## Setup

```bash
npm install
cp .env.example .env   # fill in ACTUAL_* values (budgetSyncId is in Actual → Settings → Show advanced settings)
npm run dev
```

`GET /health` should return `{ "status": "ok" }` once it's running.

## Choosing a parsing strategy

`PARSER_MODE` in `.env` is the first switch (see `src/index.ts`):

| `PARSER_MODE` | Behavior |
| --- | --- |
| `regex` (default) | Only the local ActivoBank/moey!/Trade Republic regex parsers run. Fully offline — nothing is ever sent anywhere. |
| `ai` | Every statement's raw PDF bytes go straight to the AI provider, no local text extraction at all. |
| `both` | Regex parsers run first, on locally-extracted text; the AI parser is a fallback (also text-based) only for statements none of them recognized. |

The app fails fast at startup (not on the first upload) if `PARSER_MODE` needs an AI provider and none is configured.

## Choosing an AI provider

When `PARSER_MODE` is `ai` or `both`, `AI_PROVIDER` picks which vendor answers (see `src/parsers/ai-providers/`, a Strategy pattern — code outside that folder only ever talks to the `AiProvider` interface, never a specific SDK):

| `AI_PROVIDER` | Requires |
| --- | --- |
| `anthropic` (default) | `ANTHROPIC_API_KEY` (optionally `ANTHROPIC_MODEL`) |
| `gemini` | `GEMINI_API_KEY` (optionally `GEMINI_MODEL`) |

Adding a third vendor later means adding one new file under `src/parsers/ai-providers/` implementing `AiProvider`, plus one line in that folder's `index.ts` factory.

## Category memory

`src/categorydb.ts` keeps a small local SQLite file (`CATEGORY_DB_PATH`, default `./data/categories.db`) mapping a payee to the category you usually assign it, so imports land already-categorized instead of always landing uncategorized.

- `GET /categories` — list everything remembered.
- `POST /categories` with `{ "payee": "...", "categoryId": "...", "categoryName": "..." }` — teach a mapping directly.
- `DELETE /categories/:payee` — forget one.
- `POST /categories/learn-from-actual` with `{ "accountId": "...", "startDate": "YYYY-MM-DD", "endDate": "YYYY-MM-DD" }` — the easier path: categorize transactions normally in the Actual app, then call this to backfill the memory from whatever you've already categorized there.

Matching is exact on cleaned, normalized payee text — not fuzzy. It's a complement to Actual's own rules engine, not a replacement: Actual's rules are still the better tool for substring/fuzzy payee matching.

`POST /import` (multipart, fields `statement` = the PDF, `accountId` = the target Actual account) runs the extracted text through whichever parsers `PARSER_MODE`/`AI_PROVIDER` enable, and reports `categorized` (how many transactions matched something in the category memory) alongside `added`/`updated`. Kept for backwards compatibility — new clients should prefer the parse-then-confirm flow below, which lets you review transactions before anything touches Actual.

## Parse, review, then confirm

- `POST /parse` (multipart, fields `statement` = the PDF, optional `password` if it's encrypted, optional `budgetSyncId`) extracts transactions **without importing them**. Each transaction in the response carries an `importedId` (the dedupe id it would import with) and, if the payee is in category memory, `suggestedCategoryId`/`suggestedCategoryName`.
- `POST /import/confirm` (JSON: `accountId`, `transactions` — the array from `/parse`, optionally edited — plus optional `budgetSyncId`/`budgetPassword`) imports that list. Pass each transaction's `importedId` back unchanged even if you edited its date/amount/payee — those three fields are what the dedupe id is derived from, so an edit without the original id can create a duplicate on a future re-import of the same statement. Set a transaction's `categoryId` to override the suggested category.

A password-protected statement: if `/parse` returns `422` with `code: "PDF_PASSWORD_REQUIRED"`, retry the same request with the `password` field set. `code: "PDF_PASSWORD_INCORRECT"` means the password was wrong — every error response includes a stable `code` field so a client can branch on it instead of matching the English message. In `PARSER_MODE=ai`, a password-protected statement can't be sent to the AI provider as raw bytes (it has no way to decrypt it), so it's transparently downgraded to local text extraction + the text-based AI parser for that one statement.

## Accounts, categories, and budgets

- `GET /budgets` — every budget on the connected Actual server: `{ syncId, name, encrypted }`.
- `GET /accounts?budgetSyncId=...` — that budget's accounts (falls back to `ACTUAL_BUDGET_SYNC_ID` if omitted).
- `GET /actual/categories?budgetSyncId=...` — that budget's category groups, hidden ones filtered out. (Not to be confused with `GET /categories` below — that's the local payee memory, not Actual's own categories.)
- `GET /config` — `{ parserMode, aiProvider, aiConfigured, defaultBudgetSyncId }`, enough for a client to show an accurate "is this offline right now?" indicator.

Since `@actual-app/api` holds one connection to one downloaded budget at a time, switching budgets on a live server takes a moment (the new budget's data has to download) — concurrent requests for different budgets are queued rather than racing each other.

## Authentication

Every route except `GET /health` requires a header `X-Import-Token: <IMPORT_TOKEN>` matching the `.env` value, compared with a constant-time check. Leaving `IMPORT_TOKEN` unset runs the server with no authentication at all (logged loudly at startup) — fine for a quick local test, not recommended for anything reachable beyond your own machine.

## Category memory is per-budget

Mappings taught via `POST /categories` or learned via `learn-from-actual` are scoped to whichever `budgetSyncId` was in play (or the `.env` default). A category id from one budget means nothing in another, so mixing them would silently mis-categorize transactions. Mappings created before this scoping existed still work — they're treated as an "unscoped" fallback that any budget can fall back to if it has no budget-specific mapping of its own.
