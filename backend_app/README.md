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

`PARSER_MODE` in `.env` is the switch (see `src/index.ts`):

| `PARSER_MODE` | Behavior |
| --- | --- |
| `regex` (default) | Only the local ActivoBank/moey!/Trade Republic regex parsers run. Fully offline — nothing is ever sent anywhere. |
| `ai` | Only the AI parser runs, for every statement. Requires `ANTHROPIC_API_KEY`. |
| `both` | Regex parsers run first; the AI parser is a fallback only for statements none of them recognized. Requires `ANTHROPIC_API_KEY`. |

The app fails fast at startup (not on the first upload) if `PARSER_MODE` needs `ANTHROPIC_API_KEY` and it isn't set.

`POST /import` (multipart, fields `statement` = the PDF, `accountId` = the target Actual account) runs the extracted text through whichever parsers `PARSER_MODE` enables.
