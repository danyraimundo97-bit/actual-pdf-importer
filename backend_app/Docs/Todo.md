# TODO

## Vision

The project stops being only a PDF importer and becomes **a native app for Actual Budget**. Actual
has no phone app, only the web version (it adapts to small screens and can be added to the home
screen, but it's still a web page). Statement import stays as a feature only a native app does
well: sharing the PDF straight from the bank's app.

Architecture: Flutter app → backend (gateway) → Actual server, through the official
`@actual-app/api` library. The backend is needed because the app can't run Actual's sync engine.

---

## 1. App features

- **Restore a removed import.** Removing an import is a soft delete (amount set to 0.00 + a note),
  and the original is kept in the backend's `removed-transactions.db`, but there's no way to put it
  back yet. Importing the same statement again does **not** restore it (the zeroed transaction
  still matches by `imported_id`).
- **PDF sharing on iOS.** `AndroidManifest.xml` has the PDF intent filters, but
  `ios/Runner/Info.plist` has no `CFBundleDocumentTypes` or share extension: on iOS only the file
  picker works.
- **Configurable parsers**, so other banks can be supported without writing code (today "add a
  bank" = a new Dart parser in `mobile_app/packages/statement_parser` + registering it).
- **Edit and remove transactions in the app** (not only imports). Needs the soft-delete rule below
  and better auth first. Planned in `docs/plans/local-ledger.md` (Phases 4–5). Done without Actual
  (Phase 4: the account screen edits and removes the phone's rows); with Actual it comes with the
  sync.
- **Share an account.** Let someone else see or use one account (for example a joint account), not
  only the whole budget. To be defined: who it's shared with, and whether they can edit.
- **Local ledger** (`docs/plans/local-ledger.md`): the phone keeps accounts, transactions and budget
  amounts in an encrypted database, so Home and Budget work without Actual, and syncs both ways with
  Actual once it's connected. Budget style is a setting (simple monthly limits or envelopes),
  explained in the guide.
- **Statistics page.** A new page with plenty of different dashboards, beyond what Home shows.
- **Make the Budget page easier to read.** It packs in too much information at once: show less per
  category and make it less intense to look at.

## 2. Backend as the Actual gateway

- **Security.** Today it's a single shared token (`X-Import-Token`) over plain HTTP: acceptable
  for importing statements on the LAN, not for an app that edits and removes transactions.
  - Real login, or at least per-device tokens that can be revoked.
  - HTTPS, especially for use away from home (VPN or a TLS reverse proxy — see `INSTALL.md`).
- **Keep up with Actual's version.** `@actual-app/api` must be at least as new as the Actual
  server (6.10 against a 26.10 server couldn't open budgets). Set up an upgrade routine: check the
  server's version at `<server>/info`, bump the library, run the tests. **Before pointing the
  backend at the real Actual server**, confirm it runs 26.10 or newer: the library upgrades the
  budget's file format, and an older server may no longer open it.
- **Soft delete as the rule.** No action in the app deletes data in Actual: amount set to 0.00 +
  a note, with the original kept on the backend (as removing an import already does).

## 3. Renaming

"PDF importer" is everywhere: the repository, the "Connect to your importer" screen, the
`X-Import-Token` header, the docs.

- **Give the app a name.** It still shows up on the phone as `mobile_app`.
- **Don't change the `pdfimport-` prefix** of `imported_id`s: every past import would come back as
  duplicates.
- Renaming the token header breaks existing installs unless the backend accepts both names during
  a transition.

## 4. Infrastructure and diagnostics

- **CORS support in the backend.** The Flutter app running in Chrome (`flutter run -d chrome`)
  can't talk to the backend: responses carry no `Access-Control-Allow-Origin`, the browser blocks
  them and the app shows "Could not reach the importer" (DevTools' console shows "blocked by CORS
  policy"). Android/desktop aren't affected; CORS only exists in browsers.
  - Allow the `X-Import-Token` header and let the `OPTIONS` (preflight) request through before the
    auth middleware in `src/server.ts`.
  - By default accept only `localhost` / `127.0.0.1` origins (Flutter web's port changes on every
    run), plus a `CORS_ORIGINS` setting in `.env` for anything else. Don't use `*`: with
    `IMPORT_TOKEN` empty, any website open in the browser could read the budget through the
    backend.
- **CI.** There is none: run `npm test` and `flutter analyze && flutter test` on every push.
- **Tests with real statements.** The fixtures are synthetic. The Dart package's
  `real_statements_test.dart` checks real statements, but only on a machine that has the gitignored
  `backend_app/Docs/tests/`, so a bank changing its layout isn't caught anywhere else.
- **Encrypted-PDF test fails on Node 26.** `pdf-password.test.ts` gets "bad XRef entry" from the
  old pdf.js inside `pdf-parse` (Node 26.13); it passed on older Node. Upgrade or replace
  `pdf-parse`, which the backend still needs to open password-protected statements for the AI.

## 5. Left over from the plans (`docs/plans/`)

- **Settings redesign, phase 4:** check it on the phone (no backend, connected, backend down; light
  and dark; the row press and the budget sheet with "Slow motion" on the dev page), then the
  critique score. Small follow-ups: a count on "Category memory", and the schedule ("Daily at
  03:00 · last today") on the Backups row.
- **Backups:**
  - Back up budgets other than the selected one without switching to each first (a budget picker
    in Settings → Backups).
  - Check on the phone: back up now, share a backup, restore app data, the encrypted-budget
    password prompt.
- **Logging:** on the phone, follow a failed import from the app's log to the backend's through
  its request id.
- **Categories on the phone:**
  - Reorder categories (the `sort` column exists; the screen has no drag handles).
  - The backend running `learn-from-actual` by itself when a budget's memory is empty (it needs an
    account and dates; the button is there).
  - A progress sheet for "Sync with the backend" (it runs in the background and only logs counts).
- **Database encryption** (`docs/plans/local-ledger.md`, Phase 1 as built):
  - **Method:** SQLite3MultipleCiphers (`sqlite3` build-hook option `source: sqlite3mc` in
    `pubspec.yaml`), with its default cipher (ChaCha20-Poly1305). Changing the cipher later means a
    `PRAGMA rekey` of every phone's file. Check `sqlite3mc`'s licence and the bundled SQLite version
    when bumping `sqlite3`.
  - **Key:** 32 random bytes, only in the phone's secure storage (`SecretStore.databaseKey()`). If it's
    lost (storage cleared, app data restored to a new phone by Android's Auto Backup), the database
    is set aside and the app starts empty. Anything that only lived on the phone is then gone.
    Decide whether to offer a recovery path: put the key in the app-data backup file, protected by a
    passphrase the user chooses, or show it once to write down.
  - **Check on the phone:** an existing install upgrades with its categories and memory intact, a
    fresh install works, and the file's first 16 bytes aren't `SQLite format 3`. No Android SDK on
    the dev machine, so the APK build wasn't checked there.
  - **Web** stays unencrypted (`open_connection_web.dart`). `sqlite3mc.wasm` exists if it's wanted.
- **`importedId` on Flutter web:** check the 32-bit hash when compiled to JS (`toSigned(32)`).
  Android and desktop are covered by the tests.
- **Budget tab:** tell tracking and envelope budgets apart (both render from the same
  `getBudgetMonth` fields today). Covered by the local ledger's budget style (Phases 4 and 7).
- **Changes Actual refused** (`docs/plans/local-ledger.md`, Phase 5b as built): a screen to see them and
  discard one. Today the status line counts them and the logs have the code.
- **Import into Actual offline:** Import still lists Actual's accounts from the backend; read them from
  the phone's copy of the budget, as quick add does.
- **Local ledger on a backend without Actual:** copy the phone's ledger to the backend when there's
  a backend but no Actual, so the backend's scheduled backups include it and a second phone gets it.
  Left for later (decided 2026-11-04): a phone with a backend normally connects Actual too, and one
  with neither backs up with its own export file.

## 6. Small items

- `ANTHROPIC_MODEL` and `GEMINI_MODEL` in `.env.example` default to old models
  (`claude-3-5-haiku-latest`, `gemini-1.5-flash`): update to current ones.

---

## Done

- Parsers validated against real statements and reconciled by balance: moey (113 movements),
  ActivoBank (6/6) and Trade Republic (56/56); the last two were rewritten, and `canParse` now
  requires a structural marker.
- Mobile app verified with `flutter analyze` and `flutter test`.
- Dockerfile + `docker-compose.yml` (see `INSTALL.md`).
- `@actual-app/api` upgraded to 26.10 (requires Node 22+).
- Removing an import (soft delete) and forgetting category-memory mappings.
- Core of the app: quick add, balances and recent transactions, this month's budget, one endpoint
  per screen and sync throttling (`docs/plans/core-app.md`).
- Optional Actual connection, set from the app's Settings; the backend starts without one.
- Logging in the backend and the app, with a log viewer and share (`docs/plans/logging.md`).
- Statements read on the phone: the parsers ported to Dart (`statement_parser`, shared fixtures and
  golden ids), PDFs opened on the device with `pdfrx` (passwords too), categories and category
  memory on the phone, matched to Actual and synced with the backend (`docs/plans/dart-parser.md`).
- Backend reads statements only with AI: regex parsers, `PARSER_MODE` and `POST /import` removed.
- Scheduled backups of the budget and the app data, plus export/import on the phone
  (`docs/plans/backups.md`).
- Settings redesigned as a grouped overview with Backend and Actual screens and a budget sheet
  (`docs/plans/settings-polish.md`).
