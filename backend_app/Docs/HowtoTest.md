# How to test

Everything here is run from `backend_app/` unless it says otherwise.

| What | Command |
| --- | --- |
| Full backend suite | `npm test` |
| One test file | `npm run build && node --test dist/__tests__/moey.test.js` |
| Type-check only | `npm run build` |
| Server for manual testing | `npm run dev` |
| Flutter analyzer + tests | `cd ../mobile_app && flutter analyze && flutter test` |

## Automated backend tests

```bash
npm test
```

The `pretest` hook runs `tsc` first, then `node --test "dist/**/*.test.js"` executes the
**compiled** tests out of `dist/`. That ordering is deliberate: a stale `dist/` can't report a
false pass. There's no watch mode and no single-test npm script — to iterate on one file, build
and point `node --test` at the compiled path:

```bash
npm run build && node --test dist/__tests__/moey.test.js
```

Runner is Node's built-in `node:test` with `node:assert/strict`. No Jest, no Vitest, no config
file.

### What's covered today

37 tests across eight files:

| File | Covers |
| --- | --- |
| `activobank.test.ts` | Three-line movements, year from the period header (incl. rollover), the balance-driven amount/balance split, payee prefixes, skip-and-resync on an unresolvable row, `canParse` rejection of a mere mention |
| `traderepublic.test.ts` | Two-line dates, wrapped types, direction from the balance delta, a description ending in a digit, mid-table page footer, missing-anchor degradation, `canParse` rejection of a truncated payee mention |
| `actual.test.ts` | `importToActual` payload mapping, `listAccounts`/`listBudgets`/`listCategoryGroups`, and the `assignImportedIds` dedupe rules — including **golden id literals** |
| `budget-session.test.ts` | Turn serialization, no re-download of an already-loaded budget, failed download isn't marked loaded, throwing callbacks free the queue, shutdown waits for in-flight work |
| `categorydb.test.ts` | Per-budget scoping with the unscoped fallback |
| `categorydb-migration.test.ts` | Migrating a pre-scoping table into the unscoped bucket |
| `moey.test.ts` | `canParse` accept/reject, date + cleaned payee + signed amount, the savings-section cutoff, and a page-code regression |
| `pdf-password.test.ts` | pdf.js password errors → `PdfPasswordRequiredError` / `PdfPasswordIncorrectError` |

Both Actual-facing suites drive a fake `ActualAdapter` (`src/__tests__/fake-actual.ts`), so
**no test needs a running Actual server**. The category-DB suites each `mkdtemp` their own
SQLite file under the OS temp dir, so running tests never touches your dev
`./data/categories.db`.

### Expected console noise

A clean run prints these. They are assertions about failure handling working, not failures:

```
[moey] skipping block with no amount/balance: "Trf imediata LOJA GRANDE"
[parsers] PARSER_MODE=regex — active parsers: activobank, moey, traderepublic
[traderepublic] no SALDO INICIAL in the summary block — the first movement will be skipped
```

Judge the run by the trailing `pass`/`fail` counts.

### Known gaps

- **No HTTP-level tests.** Nothing exercises `server.ts` routes, auth, or error mapping; those
  are only covered by the manual flow below.
- **No AI-provider tests.** `src/parsers/ai-providers/` is untested.
- **Fixtures are synthetic.** All three parsers are verified against real statements only by
  hand, via the reconciliation procedure below. Nothing in `npm test` reads `Docs/tests/`
  (those PDFs are gitignored personal statements), so a real-world layout change surfaces as a
  422 at upload time, not as a failing test.

## Writing a new test

Follow `moey.test.ts` — it's the reference for parser tests.

1. **Fixtures are inline synthetic strings**, built as an array of lines joined with `\n`.
   Never paste a real statement into a fixture: these are bank statements with real names,
   addresses, IBANs and account numbers. Invent the names and amounts, but *do* faithfully
   reproduce the layout quirks `pdf-parse` produces — glued columns, wrapped descriptions, a
   page header landing mid-movement, amount and balance on their own line.
2. **Feed the parser object directly** — `moeyParser.canParse(TEXT)` and
   `await moeyParser.parse(TEXT)`. Don't go through `processStatement()`; you'd need a real PDF.
   The `await` is needed because `BankParser.parse` is typed sync-or-`Promise`.
3. **Assert over the whole list at once** with one `assert.deepEqual`, projecting away
   `rawLine`:

   ```ts
   assert.deepEqual(
     txs.map(({ date, payee, amountCents }) => ({ date, payee, amountCents })),
     [{ date: '2026-07-01', payee: 'MERCADO TESTE', amountCents: -260 }, /* … */],
   );
   ```

4. **Test `canParse` both ways** — it must accept its own bank and reject the others. Parser
   dispatch is first-match-wins over `REGEX_PARSERS` (`src/index.ts`), so a sloppy sniff
   silently hijacks another bank's statements.
5. **Give each regression its own `test()`** with a short comment explaining the historical bug.

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

`POST /parse` extracts and returns transactions **without touching Actual** — no budget, no
reachable Actual server, no `ACTUAL_*` config needed. This is the fastest way to test a parser
against a real PDF.

```bash
curl -X POST http://localhost:3000/parse \
  -H "X-Import-Token: $IMPORT_TOKEN" \
  -F "statement=@Docs/tests/Moey - julho 2026.pdf"
```

The multipart field must be named `statement`. For an encrypted PDF add `-F "password=…"`.

Useful response codes:

| Code | Means |
| --- | --- |
| `MISSING_FIELD` | No file, or the field wasn't called `statement` |
| `UNRECOGNIZED_BANK` | No parser's `canParse` matched |
| `NO_TRANSACTIONS` | A parser claimed the statement but extracted zero rows — the layout changed |
| `PDF_PASSWORD_REQUIRED` / `PDF_PASSWORD_INCORRECT` | Encrypted PDF |

Branch on `code`, never on the English `error` text.

Real statements live in `Docs/tests/` and are **gitignored** — they're personal statements, so
they stay out of the repo and out of fixtures.

### 3. Verify the parse result by balance reconciliation

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

`POST /import` (multipart, parse + import in one call) is legacy and skips the review step.
Don't test new work through it.

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
