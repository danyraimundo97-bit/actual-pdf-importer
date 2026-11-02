# Plan: bring the PDF parser into the Flutter app

Source: `backend_app/Docs/Todo.md` §1, "Bring the PDF parser into the Flutter app". Branch
`feature/dart-parser`.

Goal: parse statements on the phone. The PDF never leaves the device, reading a statement works
offline and needs neither the backend nor Actual. Categories and the category memory live on the
phone too (Phase 4). The backend keeps the AI parser, the import into Actual, and a synced copy of
the category memory.

**The backend and the Actual connection are both optional** (TODO §2; the setup flow is in the
core-app plan). Parsing, reviewing and categorising must never need either; only the final import
into Actual does.

---

## Phase 0 — Spike: PDF text extraction (decides everything else)

The regex parsers depend on the exact text `pdf-parse` (pdf.js) produces: glued columns, wrapped
lines, page headers landing mid-movement. A Dart library will produce different text.

- Candidates:
  - **`pdfrx`** (PDFium, BSD-3; Android/iOS/desktop/web via wasm; has text extraction and opens
    password-protected PDFs). Recommended first try.
  - `syncfusion_flutter_pdf`: good text API, but the Community License has revenue/size
    conditions. Only if `pdfrx` text is unusable, and after checking the licence.
- Spike in the debug-only `/dev` screen: "Extract text" button that picks a PDF and shows/copies
  the extracted text. Run it on the real statements in `backend_app/Docs/tests/` (gitignored) and
  diff against `pdf-parse`'s output for the same file (small node script in the scratch area, not
  committed). Never commit real statement text.
- Check per bank: line order, how columns are joined (pdf.js glues them with no separator), NBSP
  in Trade Republic amounts, page header placement, encrypted moey/ActivoBank files.
- Outcome: a short note in this file — library chosen, and a list of differences the parsers must
  tolerate.

### Phase 0 result (2026-11-02)

Run on one real statement per bank (ActivoBank, moey, Trade Republic; 6 + 113 + 56 movements),
none password-protected. `pdfrx` couldn't be built here (its native hook needs a C compiler), so
the same PDFium build it bundles (`chromium/8125`, bblanchon/pdfium-binaries) was called through
`dart:ffi` with the exact calls `pdfrx_engine` 0.9.0 `PdfPage.loadText()` makes
(`FPDFText_GetUnicode` per character). Scratch scripts only; nothing committed.

**Library: `pdfrx`.** Every movement's payee is in its text, the characters are identical to
pdf.js's (same NBSPs in Trade Republic amounts, same stray header glyphs), page headers and footers
land in the same places.

**But the text has a different shape, so the parsers can't be a line-by-line port.** pdf.js splits
a table row over several lines and glues columns together with no separator; PDFium gives one line
per row with single spaces between columns. Examples (made up, same shape):

| Bank | pdf.js (`pdf-parse`) | PDFium |
|---|---|---|
| ActivoBank | `7.01  7.01` / `COMPRA 1234 SHOP CITY` / `34.99265.16` | `7.01 7.01 COMPRA 1234 SHOP CITY 34.99 265.16` |
| moey | `01-07-2026  /  01-07-2026COMPRA SHOP  9898237/51` / `  2,60  -53,16` | `01-07-2026 / 01-07-2026 COMPRA SHOP 9898237/51 2,60 - 53,16` |
| Trade Republic | `cartão` / `SHOP CITY 420,00 €3 551,98 €` | `cartão SHOP CITY 4 20,00 € 3 551,98 €` |

Differences the Dart parsers must handle:

- Line breaks are `\r\n`; pages are separate strings. Normalise to `\n` and join pages with `\n`.
- Columns on one line, separated by one space; runs of spaces collapsed to one. (The backend's
  payees are already whitespace-collapsed, so the `importedId` basis matches.)
- moey: the +/- sign is its own token between amount and balance (`2,60 - 53,16`,
  `5,66 + -9,77`). Long descriptions still wrap: name, continuation line, then `amount sign
  balance` on a third line.
- Trade Republic: amount and payee are separated, so a payee ending in digits (store numbers) is no
  longer ambiguous. Keep the running-balance check anyway; it's the safety net.
- Untested: a password-protected statement (none in the set; use
  `backend_app/src/__fixtures__/encrypted-statement.pdf` in Phase 3), and Android itself (same
  PDFium, so expected identical; check once on the phone after Phase 3).

**Consequences for Phases 1–2:**

- Phase 1 ports the *logic* (date and amount parsing, statement scanner, running balance,
  `importedId`), with the row matching rewritten for the PDFium shape. It's simpler than the pdf.js
  one.
- Phase 2's fixtures can't be shared as text: the backend's are pdf.js-shaped. Share the
  expectations instead: each synthetic case has a `.pdfjs.txt` and a `.pdfium.txt` rendering and
  one `.expected.json`.
- Golden check against the real statements, local only: `backend_app/Docs/tests/` (gitignored)
  holds `<name>.pdf`, `<name> Extraction.json` (the backend's output) and `<name>.pdfium.txt`. A
  Dart test parses each `.pdfium.txt` and must match the JSON exactly, `importedId` included; it
  skips when the folder is absent (CI, other clones).

## Phase 1 — Pure Dart package

New package `mobile_app/packages/statement_parser/` (pure Dart, no Flutter dependency, so
`dart test` runs fast and could later run in CI without a device). Ported 1:1 from
`backend_app/src`:

| TypeScript | Dart |
|---|---|
| `types.ts` (`RawTransaction`, `parsePtAmountToCents`, `normalizePtDate`) | `src/types.dart` |
| `parsers/statement-scanner.ts` | `src/statement_scanner.dart` |
| `parsers/activobank.ts`, `moey.ts`, `traderepublic.ts` | `src/parsers/*.dart` |
| `assignImportedIds` / `deriveImportedId` in `actual.ts` | `src/imported_id.dart` |
| bank detection loop in `index.ts` | `src/statement_parser.dart` (`parseStatementText`) |

**`importedId` must match the backend exactly** (a different id makes every past import come back
as duplicates):

- Same basis `"$date|$amountCents|$payee"`, same `|#n` suffix for occurrence n > 0, same
  `pdfimport-` prefix.
- Same hash: `hash = (hash * 31 + codeUnit).toSigned(32)` per UTF-16 code unit
  (`String.codeUnitAt` == JS `charCodeAt`). `toSigned(32)` reproduces `| 0`, and keeps the value
  small enough that it's also exact when compiled to JS for Flutter web.
- Numbering over the whole statement, never per transaction; an existing `importedId` is kept.

## Phase 2 — Shared fixtures

Move fixtures out of the inline TS strings into a shared folder both suites read:

```
fixtures/
  parsers/moey-basic.txt               # synthetic text, as pdf-parse extracts it
  parsers/moey-basic.expected.json     # [{date, payee, amountCents}]
  parsers/…                            # one pair per case now in *.test.ts
  imported-ids.json                    # golden ids from actual.test.ts, incl. occurrence > 0
```

- Backend: `moey.test.ts` etc. load the `.txt`/`.json` pairs (keep the test names). The golden
  ids in `actual.test.ts` stay as literals too — they're the compatibility pin.
- Dart: one test file iterates every fixture pair and `imported-ids.json`.
- Add Dart-only fixtures for the shape *pdfrx* produces (synthetic, built from the Phase 0
  differences), so the extraction differences are tested, not just the pdf.js shape.

### Phases 1–2 as built (2026-11-02)

- `mobile_app/packages/statement_parser/`: `parseStatementText(text)` → bank, transactions with
  `importedId`, and `ParseWarning`s (never thrown; no amounts in them; a payee kept apart so the
  app can log it at debug only). Bank detection order and every payee-cleaning rule as in the
  backend.
- One parser per bank reads **both** shapes, so the backend's cases carry over unchanged:
  - ActivoBank: the date line may carry the whole row; every split of the row's end into
    `amount balance` (glued or spaced, space thousands) is tried, and the running balance picks.
  - moey: optional space between the +/- sign and the balance.
  - Trade Republic: the year line may continue the row; the footer region also ends at
    "DINHEIRO SALDO".
- `fixtures/parsers/`: the backend's inline test statements moved to files — `activobank-basic`,
  `-year-rollover`, `-unresolvable`, `-no-period`, `moey-basic`, `-page-code-payee`,
  `traderepublic-basic`, `-no-opening`; the three `-basic` ones also have a `.pdfium.txt`. The
  backend reads the `.pdfjs.txt` ones (`parser-fixtures.test.ts`); the per-bank test files keep
  only the checks that aren't a movement list (detection, totals, savings, footer).
- `fixtures/imported-ids.json`: the backend's golden ids, plus a case with accents, € and an
  emoji (UTF-16 code units), computed by the backend.
- Real statements: all three (6 + 113 + 56 movements) match the backend's output exactly, ids
  included.
- Not done here: the Phase 1 hash check on Flutter web (`toSigned(32)` when compiled to JS).

## Phase 3 — Extraction layer in the app

- `lib/data/pdf/pdf_text_extractor.dart`: interface `Future<String> extractText(Uint8List bytes,
  {String? password})`, `pdfrx` implementation, and a normalisation step (NBSP, line joining)
  so the parsers see text as close to pdf.js as practical.
- Password errors map to the same two cases the backend has: "password required" vs. "password
  incorrect", so the existing password prompt in the inbox works unchanged.
- Run extraction + parsing in `Isolate.run` so a large statement doesn't jank the UI (check
  whether pdfrx needs the main isolate; if so, only the parse goes to the isolate).
- **Validate against real statements** with the balance reconciliation in
  `backend_app/Docs/HowtoTest.md`: moey (113 movements), ActivoBank (6/6), Trade Republic (56/56)
  must reconcile exactly as they do on the backend, and produce the same `importedId`s as the
  backend's `/parse` for the same file (compare both outputs in the dev screen).

### Phase 3 as built (2026-11-02)

- `pdfrx` ^2.11.0 (engine 0.9.0, PDFium `chromium/8125`: the build Phase 0 validated). It needs
  `intl` ^0.20.2, so the app's `intl` moved from ^0.19.0; nothing else changed. Its native build
  hook needs clang on Linux (gcc alone fails).
- The real `pdfrx` gives the Phase 0 FFI text exactly (only the page separator differs, which the
  parser normalises): all three real statements, 175 movements, match the backend, `importedId`
  included, with no warnings.
- `lib/data/pdf/pdf_text_extractor.dart`: `PdfTextExtractor` (interface) and `PdfrxTextExtractor`.
  Pages joined with `\n`; no other normalisation (the parser package does it, so both stay
  byte-identical to the backend's `importedId` basis). Failures are `PdfReadException` with the
  backend's codes: `PDF_PASSWORD_REQUIRED`, `PDF_PASSWORD_INCORRECT` (an empty password counts as
  none), `PDF_UNREADABLE`.
- `lib/data/pdf/local_statement_reader.dart`: extract, then `parseStatementText` via `compute`
  (PDFium already runs on pdfrx's own worker isolate; `compute` also works on web). Logs bank and
  counts at info, each parser warning at warn, a warning's payee at debug only.
- Providers: `pdfTextExtractorProvider`, `localStatementReaderProvider`.
- Tests: `test/pdf_text_extractor_test.dart` runs the real PDFium on the backend's encrypted
  fixture (all three password cases, a non-PDF) and, locally, on the real statements. `flutter
  test` doesn't pass the hook's native assets to host tests, so the test points
  `Pdfrx.pdfiumModulePath` at `build/native_assets/<os>/` and skips if it isn't built.
  `test/local_statement_reader_test.dart` uses a fake extractor.
- Still to do: run once on an Android phone (needs the Android SDK on this machine, or a build
  elsewhere). The dev-screen comparison with `/parse` moves to Phase 5, where the inbox can run
  both.

## Phase 4 — Categories on the device: predefined set + category memory

With the backend optional, the app needs its own categories and its own payee → category memory.
When Actual is connected, Actual's categories take over; the predefined set is what the app uses
before that (or forever, for a user who never connects).

### Storage: `drift` (SQLite)

Typed SQLite that runs on Android, iOS, desktop and Flutter web (wasm); `sqflite` has no web.
New `lib/data/local/db/app_database.dart`, four tables:

```
category_groups  id TEXT PK, name, sort, is_income BOOL, source ('preset'|'user'),
                 preset_key TEXT?, hidden BOOL, updated_at
categories       id TEXT PK, group_id FK, name, sort, source ('preset'|'user'),
                 preset_key TEXT?, hidden BOOL, updated_at
category_links   category_id FK, budget_sync_id, actual_category_id   -- per connected budget
                 PK (category_id, budget_sync_id)
payee_categories budget_sync_id ('' = unscoped), payee_key, payee_label, category_id FK,
                 updated_at, deleted BOOL                              -- tombstone for sync
                 PK (budget_sync_id, payee_key)
```

- Local ids are UUIDs, so they never clash with Actual's. `category_links` ties a local
  category to an Actual category in one budget, so one phone can serve several budgets.
- `payee_key` uses exactly the backend's normalisation (`trim().toLowerCase()`, collapse
  whitespace); a shared fixture pins it, like the `importedId` hash.
- Lookup keeps the backend's order: this budget's scope first, then unscoped.

### The predefined set

Seeded by the first drift migration, from `lib/data/local/db/preset_categories.dart`. Each preset
has a stable `preset_key` (`food.groceries`), so a later app version can add presets without
duplicating or overwriting ones the user renamed or hid. Names are in English (decided; no
Portuguese variant), like the rest of the UI. The list below is final (reviewed 2026-11-02):

| Group | Categories |
|---|---|
| Home | Rent / mortgage · Utilities · Internet & phone · Home & furniture |
| Food | Groceries · Restaurants & cafés |
| Transport | Fuel · Public transport · Car (maintenance, insurance, tolls, parking) · Taxi & ride-hailing |
| Health | Health & pharmacy · Insurance |
| Personal | Shopping & clothing · Subscriptions · Entertainment · Sports & fitness · Education · Gifts & donations · Personal care |
| Travel | Travel & holidays |
| Money | Bank fees · Taxes · Savings & investments · Transfers |
| Income *(is_income)* | Salary · Refunds · Other income |

- Users can rename, hide, reorder, add their own (`source: 'user'`) and restore hidden presets.
  "Reset to defaults" brings back hidden presets but never touches user categories or mappings.
- **Starter hints for Portuguese merchants** (`preset_hints.dart`, optional, lowest priority after
  the user's own memory): `CONTINENTE|PINGO DOCE|LIDL|ALDI|MERCADONA|INTERMARCHE|MINIPRECO` →
  Groceries; `GALP|REPSOL|BP|PRIO|CEPSA` → Fuel; `UBER|BOLT|FREE NOW` → Taxi; `VIA VERDE` → Car;
  `NETFLIX|SPOTIFY|DISNEY|HBO` → Subscriptions; `FARMACIA` → Health & pharmacy;
  `EDP|GALP ENERGIA|EPAL|ENDESA|GOLDENERGY` → Utilities; `MEO|NOS|VODAFONE|DIGI` → Internet &
  phone; `COMISSAO|IMPOSTO DO SELO` → Bank fees. Shown as a suggestion with a "hint" badge, so
  the user can tell it apart from what they taught the app; accepting it records a real mapping.

### Picker and screens

- `CategoryPickerSheet` stops taking `List<ActualCategoryGroup>` and takes a source-neutral
  `List<CategoryGroupOption>` from one provider, `categoriesProvider`:
  - Actual not connected → local groups/categories (not hidden);
  - connected → Actual's groups from `/actual/categories`, as today.
- Category memory screen reads the local table; a "Categories" screen in Settings edits the
  predefined/user set.

### When Actual gets connected: "Match your categories"

Shown once after a budget is chosen (from the setup guide's last step or Settings), and again if
new local categories appear later:

- Auto-match by name, case- and accent-insensitive ("Restaurantes" ≠ "Restaurants & cafés", so
  only exact-after-normalisation matches are automatic).
- Every other local category that's in use (has mappings) gets a row: pick an Actual category,
  **create it in Actual** (same group name, created if missing), or skip. Unused presets are
  just skipped, never created, so a user's Actual budget doesn't fill up with empty categories.
- Results go to `category_links`; mappings then resolve to Actual ids for that budget.
- Backend: `POST /actual/categories` `{ budgetSyncId, groupName, name }` → `{ id }`, using
  `createCategoryGroup` / `createCategory` (added to `ActualPort` and the fake adapter);
  idempotent by name, so a retry never creates a duplicate. Typed errors as usual.

### Sync with the backend's category DB (when a backend is connected)

- `POST /categories/sync` `{ budgetSyncId, since, changes: [...] }` →
  `{ changes: [...], now }`. Newest `updated_at` wins per `(budget, payee_key)`; tombstones carry
  "forget mapping" both ways. Mappings learned on the backend (`learn-from-actual`) reach the phone
  this way.
- Rows are sent with the *Actual* category id (resolved through `category_links`); mappings to
  an unlinked local category stay on the phone until it's matched.
- Backend: `deleted` column via the existing migration path (`categorydb-migration.test.ts`).
- Replaces the `/categories/suggest` idea: the phone answers suggestions from its own copy.
- The same sync also carries `category_groups` and `categories` (renames, hidden presets, user
  categories, order), so the backend holds the whole categorisation for the app-data backups
  (backups plan, Phase 1a).

### Repopulate on connect

When a phone connects to a backend (first install, new phone, reinstall, or "Clear app data"),
its local database is refilled from the backend, so nothing taught to the app is lost with the
phone:

1. Categories: Actual's groups and categories for the chosen budget are pulled, and local
   categories are linked to them ("Match your categories" only asks about local ones in use that
   don't match).
2. Category memory: a full pull (`POST /categories/sync` with `since: null`). If the backend's
   copy for that budget is empty, the backend first runs `learn-from-actual`, so the memory is
   rebuilt from transactions already categorised in Actual. This is also how a restored Actual
   backup brings the memory back.
3. Anything already on the phone is merged, not replaced (newer wins), so connecting never loses
   mappings made offline. Local categories (renames, hidden, user ones) come back the same way.
   The one exception is restoring an app-data backup, which runs this in *replace* mode.

A progress sheet shows the steps ("Loading categories… Restoring 214 payee mappings…"), and the
result is logged at info. Tests: empty phone + filled backend, filled phone + empty backend
(pushes up), both filled (merge), backend empty + Actual has categorised transactions (rebuilt).

Tests: seed + re-seed (rename survives an app update that adds a preset), lookup order, the
`payee_key` fixture, hint matching, auto-match normalisation, sync merge (newer wins, tombstones,
unlinked rows held back), the picker with both sources.

### Phase 4a as built (2026-11-02)

Built in steps: 4a (this), 4b management screens, 4c "Match your categories", 4d sync and
repopulate.

- `drift` 2.35 (+ `drift_flutter`, generated `app_database.g.dart` committed).
  `lib/data/local/db/app_database.dart` has the four tables as planned. Times are epoch ms.
  Presets are seeded on every open by `presetKey`, so renames and hidden presets survive updates
  and new presets get added. Preset ids are `preset:<key>`; user categories will be `local:<uuid>`.
- `LocalCategoryStore`: visible groups (Income last, empty groups left out) in the picker's shape;
  `suggest` = this budget's mapping, then unscoped, then a merchant hint; `remember`; `forget`
  (tombstone); `mappings`.
- `preset_hints.dart`: whole-word, case- and accent-insensitive (so `BPI` isn't `BP`).
- Inbox: with Actual connected (`linkStateProvider` ready), suggestions come from the backend's
  memory as before. Otherwise they come from the phone, and `ParseResult.localCategories` is true.
- Review: no account → the picker lists the app's categories; a hint shows a "hint" badge; CSV
  export remembers each picked or accepted-hint category on the phone. With an account, local
  suggestions are dropped: Actual can't resolve local ids until 4c links them.
- Not yet: web. `drift_flutter` on web needs `sqlite3.wasm` and `drift_worker.js` in `web/`; until
  they're added the database won't open in a web build. Android, iOS and desktop bundle SQLite
  through the sqlite3 build hook.

### Phase 4b as built (2026-11-02)

- `CategoryMemorySource` (`lib/data/category_memory_source.dart`): the Category memory screen
  uses the backend's memory (`BackendCategoryMemory`) while Actual is connected with a budget, and
  the phone's (`LocalCategoryMemory`) otherwise, including when the backend doesn't answer. It
  switches when the link state changes. "Learn from Actual" shows only with the backend; the
  phone's empty state explains that exporting from Review teaches it.
- Settings → Categories → "Edit categories" (`/settings/category-list`, `CategoriesScreen`):
  rename groups and categories, hide and show, add a category to a group or a new group, and
  "Show hidden predefined categories" (renames and the user's own choices stay). Nothing is
  deleted: a hidden category keeps its mappings, isn't suggested, and comes back when shown. User
  ids are `local:<uuid v4>`.
- Not done: reordering (the `sort` column is there; the screen has no drag handles yet).

### Phase 4c as built (2026-11-02)

- Backend: `POST /actual/categories` `{ budgetSyncId, groupName, name, isIncome? }` →
  `{ id, created }` (201 when created). `ensureCategory` (`actual.ts`) reuses a category with the
  same name anywhere in the budget (`categoryNameKey`: case, accents, spacing), then a group with
  that name, and creates only what's missing; an income category goes into the budget's income
  group. `createCategoryGroup`/`createCategory` added to `ActualPort`.
- App: `/match-categories` ("Match your categories"). Every visible local category whose name
  matches exactly one Actual category is linked automatically, unused presets included (hints
  point at presets). Local categories the memory uses get a row: create in Actual (default), pick
  an Actual category, or skip (remembered per budget in `SettingsStore`). Links are saved as they
  succeed, so a failure half-way keeps them.
- Where it shows: a note with "Match your categories" on the Import tab while
  `pendingCategoryMatchesProvider` > 0 (Actual ready, local categories in use that are unlinked
  and not skipped; so it comes back when new ones appear), and "Match with Actual" in Settings.
  Not pushed as a modal after choosing a budget.
- Using the links: with Actual connected, the inbox fills lines the backend's memory doesn't know
  from the phone's memory or hints when their category is linked (`toActualCategories`); Review
  maps a statement read before connecting the same way once Actual's categories load. Unlinked
  local suggestions are still dropped on import.

## Phase 5 — App integration

In `features/import/inbox_controller.dart`, per queued PDF:

1. Extract text on device → `parseStatementText` (detect bank, parse, assign ids).
2. Suggest categories from the on-device memory, then the starter hints (Phase 4). No network.
3. Open Review with the same `ParseResult` shape `/parse` returns today, so `ReviewScreen` and
   `/import/confirm` don't change.
4. **No local parser recognises it** (or zero transactions): offer "Send to the backend's AI
   parser" — explicit, because the PDF then leaves the device. That uses today's `/parse`.

Three levels of connectivity, each a test case:

| Backend | Actual | What the user can do |
|---|---|---|
| none / unreachable | — | parse, review and categorise on device with the predefined categories; export CSV; no AI fallback, no import |
| reachable | not connected | + AI fallback, category memory synced; Review shows "Connect Actual to import" instead of the account picker |
| reachable | connected | everything, with Actual's categories |

**Export** (the no-Actual way out): "Export CSV" on Review writes `date, payee, amount, category,
notes` (category = the local category name) and hands it to the share sheet. Actual's web app
imports CSV and lets the user map those columns. Generated in memory and shared directly; no copy
is kept on the device.

A parsed statement stays in the inbox (in memory only, as today) so the user can connect Actual
and come back to import it without parsing again.

Settings: "Parse statements on this device" toggle, default **on** once Phase 3 validation
passes; off = today's behaviour. Lets the user fall back if a bank changes layout.

Tests: inbox controller with a fake extractor (local success, unrecognised → AI offer, backend
down → still categorised from local memory), CSV export, parser package tests, existing `inbox_controller_test.dart` kept green.

### Phase 5 as built (2026-11-02)

Phase 4 (on-device categories) isn't built yet, so suggestions come from the backend's category
memory when there is a backend, and otherwise there are none.

- Inbox (`inbox_controller.dart`): with "Read statements on this phone" on (default), each PDF is
  read by `LocalStatementReader`. Recognised with movements → `ready`, marked `parsedOnDevice`.
  Password failures → `needsPassword` as before; a non-PDF → `failed`. Not recognised (or
  recognised with zero movements) → new `InboxStatus.unrecognized`, with `recognizedBank` when a
  parser claimed it. The PDF is uploaded only from there, by `sendToBackend`, after a dialog that
  names the AI provider when the backend uses one. The password that opened it is kept on the
  item (memory only) for that upload. Setting off → the old `/parse` path, unchanged.
- Suggestions: `GET /categories` for the budget and the unscoped bucket, matched with
  `categoryMemoryKey` (the backend's `normalizeKey`): budget mapping first, then unscoped. A failed
  fetch logs a warning and leaves the lines uncategorised.
- Without a backend, the import screen doesn't ask for accounts; it shows the "Connect Actual"
  note. Review opens whenever accounts aren't loading. With no account it shows "Export N as CSV"
  and a note; with one, export is an app-bar action next to import.
- CSV (`features/review/csv_export.dart`): `date,payee,amount,category`, CRLF, RFC 4180 quoting,
  UTF-8 with BOM, amounts as `-12.30` from integer cents. No `notes` column (nothing to put in it
  yet). Shared through `share_plus` from memory; the share sheet may stage the file in the app's
  cache to hand it over, and the app keeps no copy.
- The privacy banner about the AI provider shows only when parsing on the backend; on the device,
  the send dialog says it instead.
- Tests: inbox on the device (no backend, suggestions, backend down, unrecognised then sent,
  passwords, non-PDF, setting off), suggestion matching, CSV, Review without an account.
- Not done: the dev-screen comparison of device vs `/parse` (the real-statement tests cover it),
  and running on an Android phone.

## Phase 6 — Transition

- The backend's job narrows to syncing with Actual, backups (backups plan) and the AI parser.
  Keep `POST /parse` as the AI fallback. Its regex parsers stay only until the Dart port has
  passed the shared fixtures and real-statement reconciliation for a while; then remove them
  (and `PARSER_MODE` `regex`/`both`), the legacy `POST /import`, and `pdf-parse` itself if the
  AI path no longer needs local text extraction (it does today for password-protected PDFs, so
  check that first).
- Update `CLAUDE.md`, `HowtoTest.md` (Dart side of the reconciliation), and the Todo.
- iOS share sheet (TODO §1) is separate, but this branch makes it more valuable.

## Done criteria

- `dart test` in the package and `npm test` both run the shared fixtures green.
- Golden `importedId`s identical in both suites.
- Real statements for all three banks reconcile on device and produce the same ids as `/parse`.
- Encrypted statements open on device with the right password and give the right error otherwise.
- `flutter analyze && flutter test` green.

## Out of scope

- Configurable (data-driven) parsers — revisit after this lands, as the TODO says.
- Moving the AI parser to the app (API keys can't ship in the app).

## Overlap with `feature/core-app`

That branch changes navigation (tabs) and `providers.dart`, and adds the optional Actual
connection (`actualConnected`, `ACTUAL_NOT_CONFIGURED`, the shared connect state) that Phase 5
relies on; this one owns `inbox_controller.dart`, `import_screen.dart` and the dev screen. Merge
`feature/core-app` first (at least its Milestone 1), then rebase this one. Phases 0–4 don't
depend on it and can start now. The setup guide's backend-optional flow is specified in the
core-app plan.
