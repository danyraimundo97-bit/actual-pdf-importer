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

`POST /import` (multipart, fields `statement` = the PDF, `accountId` = the target Actual account) runs the extracted text through whichever parsers `PARSER_MODE`/`AI_PROVIDER` enable, and reports `categorized` (how many transactions matched something in the category memory) alongside `added`/`updated`.
