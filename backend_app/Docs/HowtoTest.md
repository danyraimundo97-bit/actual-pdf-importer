# How to test

Everything here is run from `backend_app/` unless it says otherwise.

| What | Command |
| --- | --- |
| Full backend suite | `npm test` |
| One test file | `npm run build && node --test dist/__tests__/actual.test.js` |
| Type-check only | `npm run build` |
| Server for manual testing | `npm run dev` |
| Flutter analyzer + tests | `cd ../mobile_app && flutter analyze && flutter test` |
| Statement parsers (Dart) | `cd ../mobile_app/packages/statement_parser && dart test` |

## Automated backend tests

```bash
npm test
```

The `pretest` hook runs `tsc` first, then `node --test "dist/**/*.test.js"` executes the
**compiled** tests out of `dist/`. That ordering is deliberate: a stale `dist/` can't report a
false pass. There's no watch mode and no single-test npm script — to iterate on one file, build
and point `node --test` at the compiled path:

```bash
npm run build && node --test dist/__tests__/actual.test.js
```

Runner is Node's built-in `node:test` with `node:assert/strict`. No Jest, no Vitest, no config
file.

### What's covered today

The bank parsers live in the app now (`mobile_app/packages/statement_parser`, `dart test`), tested
against the shared `fixtures/` and, when `Docs/tests/` is present, the real statements. The backend
suite covers the rest:

| File | Covers |
| --- | --- |
| `imported-ids.test.ts` | The shared golden `importedId`s in `fixtures/imported-ids.json`, the same ones the Dart package checks |
| `actual.test.ts` | `importToActual` payload mapping, the Actual list functions, and the `assignImportedIds` dedupe rules, including **golden id literals** |
| `statement-batch.test.ts` | Per-file isolation of failures, `NO_TRANSACTIONS` keeping its `bankId`, no leaking of unexpected error text, sequential ordering, and the per-statement dedupe-id rule |
| `pdf-password.test.ts` | pdf.js password errors → `PdfPasswordRequiredError` / `PdfPasswordIncorrectError`, a non-PDF → `PDF_UNREADABLE`, and `AI_NOT_CONFIGURED` without an AI key |
| `upload.test.ts` | Upload limits over real HTTP: exact file count in `TOO_MANY_FILES`, `FILE_TOO_LARGE` vs `BATCH_TOO_LARGE`, wrong field name, the rejection log line |
| `budget-session.test.ts` | Turn serialization, no re-download of an already-loaded budget, failed download isn't marked loaded, throwing callbacks free the queue, shutdown waits for in-flight work |
| `categorydb*.test.ts` | Per-budget scoping with the unscoped fallback, the pre-scoping migration, and the phone sync |
| `removal-log.test.ts`, `transactions.test.ts`, `dashboard.test.ts`, `account-page.test.ts`, `budget-month.test.ts`, `actual-connection.test.ts`, `logger.test.ts` | The soft-delete log, quick add, the read-only screens, the optional Actual connection, and log redaction |

Both Actual-facing suites drive a fake `ActualAdapter` (`src/__tests__/fake-actual.ts`), so
**no test needs a running Actual server**. The category-DB suites each `mkdtemp` their own
SQLite file under the OS temp dir, so running tests never touches your dev
`./data/categories.db`.

Judge the run by the trailing `pass`/`fail` counts; warning lines in the output are assertions
about failure handling, not failures.

### Known gaps

- **Few HTTP-level tests.** Only the upload limits (`upload.test.ts`) are tested over HTTP; route
  wiring and auth are covered only by the manual flow below. Batch *orchestration* is unit-tested (`statement-batch.test.ts`) because
  it lives outside the route handler, but nothing asserts the handler calls it correctly.
- **No AI-provider tests.** `src/parsers/ai-providers/` is untested.
- **Real statements aren't in `npm test`.** The Dart package's `real_statements_test.dart` reads
  `Docs/tests/` (gitignored personal statements) and skips when it's absent.

## Writing a new test

Parser tests are in the Dart package now (`mobile_app/packages/statement_parser/test/`). A new
layout case goes in `fixtures/parsers/` as `<name>.pdfjs.txt` and/or `<name>.pdfium.txt` plus
`<name>.expected.json`, synthetic only: never paste a real statement, since these carry real
names, addresses, IBANs and account numbers.

Backend tests use Node's `node:test` with `node:assert/strict`; assert over a whole list at once
with one `assert.deepEqual`, and give each regression its own `test()` with a short comment.

### Binary fixtures

`src/__fixtures__/encrypted-statement.pdf` is the only one. `tsc` does **not** copy non-`.ts`
files into `dist/`, so load fixtures with a `process.cwd()`-relative path, as
`pdf-password.test.ts` does:

```ts
fs.readFileSync(path.join(process.cwd(), 'src/__fixtures__/encrypted-statement.pdf'));
```

A `__dirname`-relative read breaks, because at runtime `__dirname` is `dist/__tests__`.

### Don't break dedupe

`actual.test.ts` pins `importedId` values as **literals**. They are a hash of
`date|amountCents|payee` (plus an occurrence suffix for repeats). If you change `basisOf`, the
hash, or the occurrence scheme, those tests fail — and that failure is the point: new ids mean
every previously imported statement would re-import as duplicates. Fix your change, not the
expected values.

## Manual end-to-end testing

### 1. Start the server

```bash
npm run dev          # http://localhost:3000, restarts on change
```

Only `GET /health` is unauthenticated:

```bash
curl http://localhost:3000/health            # {"status":"ok"}
```

Every other route needs `X-Import-Token` matching `IMPORT_TOKEN` in `.env`. If `IMPORT_TOKEN`
is unset, auth is disabled entirely and the server says so loudly at startup — local testing
only.

> **PowerShell:** `curl` is an alias for `Invoke-WebRequest` in Windows PowerShell 5.1, which
> takes different arguments. Use `curl.exe` explicitly, or run these from Git Bash.

### 2. Parse a statement

`POST /parse` reads a statement with the AI provider and returns transactions **without
touching Actual** — no budget, no reachable Actual server, no `ACTUAL_*` config needed. It needs
`AI_PROVIDER` and its API key; without them it answers `AI_NOT_CONFIGURED`. (The bank parsers run
on the phone; the Dart package's tests cover them.)

```bash
curl -X POST http://localhost:3000/parse \
  -H "X-Import-Token: $IMPORT_TOKEN" \
  -F "statement=@Docs/tests/Moey - julho 2026.pdf"
```

The multipart field must be named `statement`. For an encrypted PDF add `-F "password=…"`.

Useful response codes:

| Code | Means |
| --- | --- |
| `MISSING_FIELD` | No file, or the field wasn't called `statement` / `statements` |
| `AI_NOT_CONFIGURED` | The backend has no AI key, so it doesn't read statements |
| `NO_TRANSACTIONS` | The AI provider found no rows |
| `PDF_PASSWORD_REQUIRED` / `PDF_PASSWORD_INCORRECT` | Encrypted PDF |
| `PDF_UNREADABLE` | Not a PDF, or corrupt |
| `TOO_MANY_FILES` | More than 20 files to `/parse` |
| `FILE_TOO_LARGE` | One file is over the 20MB per-file limit |
| `BATCH_TOO_LARGE` | Every file is under 20MB, but the request is over 50MB in total |

Every upload rejection also logs a `[upload] … rejected with <code>` line on the server, giving
the number of files received and the total request size.

Branch on `code`, never on the English `error` text.

### 2b. Parse several statements in one call

The same `POST /parse` takes up to 20 files — a month of exports, or one per account. Repeat the
field (`statement` or `statements`, either works). **The number of files picks the response
shape:** one file gets the single-statement response above, two or more get the per-file
response below.

```bash
curl -X POST http://localhost:3000/parse \
  -H "X-Import-Token: $IMPORT_TOKEN" \
  -F "statements=@Docs/tests/Moey - julho 2026.pdf" \
  -F "statements=@Docs/tests/Activo bank  - Maio 2026.pdf" \
  -F "statements=@Docs/tests/Trade Republic - Agosto 2026.pdf"
```

```json
{ "files": [ { "filename": "...", "status": "parsed", "bankId": "moey", "transactions": [...] },
             { "filename": "...", "status": "failed", "code": "PDF_UNREADABLE", "error": "..." } ],
  "parsed": 2, "failed": 1, "transactions": 175 }
```

Things to check when testing it:

- **Partial success returns 200.** One bad file must not cost the others, so per-file failures are
  data (`status` + `code`), not an HTTP error. Only a request-level problem — no files, too many,
  too large, wrong field name — is a 4xx.
- **`importedId`s must be identical to parsing the same file alone.** This is the one thing that
  can silently corrupt a budget: ids are stamped per *statement*, so a movement appearing in two
  overlapping exports keeps one id and Actual dedupes it. Stamping across the batch instead would
  give it two ids and import it twice. Verify by diffing a file's ids in a multi-file response against the same file sent alone.
- **One `password` applies to every file.** Statements needing a different one come back as
  `PDF_PASSWORD_REQUIRED`/`INCORRECT`; re-send those alone with their own password.
- Parsing is sequential on purpose — each file is an AI provider call.

`POST /import/confirm` needs no changes to accept a batch: concatenate the reviewed transactions
from every file into one `transactions` array. Ids already on the rows are preserved.

Real statements live in `Docs/tests/` and are **gitignored** — they're personal statements, so
they stay out of the repo and out of fixtures.

### 3. Verify the parse result by balance reconciliation

This applies to the phone's parsers (the Dart package's `real_statements_test.dart` checks the
real statements in `Docs/tests/`) and to an AI result from `/parse`.

A parser can return plausible-looking rows that are quietly wrong — most often the **sign**,
since the Portuguese statements here carry direction in a separate column, a marker glued to
the balance, or nothing at all. Don't eyeball it: each parser keeps the bank's own running
balance in `rawLine`, so the statement can be checked against itself.

For each row in order, assert `previous_balance + amountCents == balance_on_this_row`. If the
chain holds end to end, then no movement was dropped, duplicated, mis-signed or mis-scaled
anywhere between the first and last row — one broken link reveals all four. Finish by checking
the first row against the statement's `SALDO INICIAL` and the last against `SALDO FINAL`; the
chain alone can't prove the *ends* are right.

Sum of all `amountCents` should equal `SALDO FINAL − SALDO INICIAL`.

Each bank hides the balance differently in `rawLine`, so a reconciler needs a per-bank reader:

| Bank | Where the balance is | Trap |
| --- | --- | --- |
| moey | after the direction marker: `… 2,60 -53,16` | the `-`/`+` is the *direction*, the number after it is the balance (`--15,43` = debit, balance −15,43) |
| ActivoBank | glued to the amount: `34.99265.16` | thousands separator is a **space** (`1 386.35`), so you cannot find the pair by splitting on whitespace |
| Trade Republic | last `€`-terminated number | amount and balance both end in `€`; the amount is glued to the description, which may itself end in a digit |

For Trade Republic and ActivoBank the amount is not independently recoverable from the text —
it is derived from the balance delta. So reconciling those two checks the parser's arithmetic
against the statement's, which is exactly the point.

### 4. Import for real

`POST /import/confirm` (JSON) is the second half of the recommended flow. It needs a reachable
Actual server and a selected budget; an unset budget returns `NO_BUDGET_SELECTED` (400).

Pass each transaction's `importedId` back **unchanged**, even if you edited its date, amount or
payee — the id is derived from those three fields, and re-deriving it after an edit breaks
dedupe when the same statement is re-imported.

Re-running the same import is the test that matters: the second run must add **zero**
transactions. If it adds duplicates, dedupe is broken.

## Mobile app

From `mobile_app/`:

```bash
flutter pub get
flutter analyze        # standard flutter_lints, no project overrides
flutter test           # test/widget_test.dart — boots the app, asserts the first-run gate
flutter run
```

`widget_test.dart` is a smoke test: with no backend URL configured, `core/router.dart`'s
`redirect` must land on Settings rather than Import. It injects a mock `SharedPreferences`
through a `ProviderScope` override — the pattern to copy for any further widget test.

For end-to-end testing, point the app's Settings screen at your `npm run dev` server. On a
physical Android device that's your machine's LAN IP, not `localhost`.
