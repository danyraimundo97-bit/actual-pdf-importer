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

- **Core of the app**, in likely priority order:
  - Add a transaction in seconds (e.g. a cash purchase).
  - Balances and recent transactions (the dashboard is a start).
  - This month's budget: how much is left in each category.
  - Statement import with category memory (already exists).
- **Bring the PDF parser into the Flutter app.** Parse on the phone instead of the backend: the PDF
  never leaves the device, it works offline, and reading a statement no longer needs the backend.
  - Port the three regex parsers (`activobank`, `moey`, `traderepublic`) to Dart.
  - **Text extraction:** the parsers depend on the exact text `pdf-parse` (pdf.js) produces: glued
    columns, wrapped lines, page headers landing mid-movement. A Dart library (e.g. `pdfrx`, or
    `syncfusion_flutter_pdf` — check its license) will produce different text, so each parser has
    to be re-validated against real statements with the balance reconciliation in `HowtoTest.md`.
  - **`importedId` must match the backend exactly:** same basis (`date|amount|payee`), same 32-bit
    hash (including the `| 0` overflow) and the same occurrence numbering. Use the golden ids in
    `actual.test.ts` as shared tests. A different id makes every statement already imported come
    back as duplicates.
  - Password-protected PDFs: confirm the Dart library opens them.
  - The AI parser stays on the backend (API keys can't ship in the app).
  - Category suggestions come from the backend (`categorydb`) during `/parse` today. With parsing
    in the app, it needs an endpoint that takes payees and returns suggestions.
  - Transition: keep the backend's `POST /parse` until the Dart version passes the same fixtures;
    ideally shared text fixtures, run by both test suites.
- **Restore a removed import.** Removing an import is a soft delete (amount set to 0.00 + a note),
  and the original is kept in the backend's `removed-transactions.db`, but there's no way to put it
  back yet. Importing the same statement again does **not** restore it (the zeroed transaction
  still matches by `imported_id`).
- **PDF sharing on iOS.** `AndroidManifest.xml` has the PDF intent filters, but
  `ios/Runner/Info.plist` has no `CFBundleDocumentTypes` or share extension: on iOS only the file
  picker works.
- **Configurable parsers**, so other banks can be supported without writing a new `.ts` file
  (today "add a bank" = a new parser + one line in `index.ts`). Revisit together with the Dart port.

## 2. Backend as the Actual gateway

- **Performance: one request at a time.** Actual's library keeps only one budget open, so the
  backend handles requests strictly in a queue, and each request syncs with Actual before
  answering. An app making many small reads (lists, balances, scrolling transactions) will feel
  slow.
  - Larger endpoints, one per screen, instead of many small ones.
  - Sync at most every few seconds instead of on every request.
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
- **Logging in the backend and the app.** Problems are hard to diagnose today: the app has no
  logging at all (handled errors such as "Could not reach the importer" only appear on screen and
  are never recorded), and the backend only logs startup, rejected uploads and errors.
  - **Backend:** one line per request (method, path, status, duration), to answer "does the
    request even reach the backend?". Never log the `X-Import-Token`, passwords, PDF contents or
    transactions (they're personal banking data).
  - **App — network requests:** a Dio interceptor that, in debug builds, logs every request to the
    backend (method, URL, status, duration, and the error type when it fails). Same care: no
    token, no PDF.
  - **App — uncaught errors:** `FlutterError.onError` + `PlatformDispatcher.instance.onError` to
    record every crash with its stack trace in one place.
  - **App — log file (optional):** keep recent logs in a small file on the device, with a "Copy
    logs" button in settings or the dev screen. It's the only way to see what happens in a build
    installed on the phone, with no terminal attached (needs `path_provider`).
- **CI.** There is none: run `npm test` and `flutter analyze && flutter test` on every push.
- **Tests with real statements.** The fixtures are synthetic; nothing in `npm test` catches a bank
  changing its layout (see "Known gaps" in `HowtoTest.md`).

## 5. Small items

- `ANTHROPIC_MODEL` and `GEMINI_MODEL` in `.env.example` default to old models
  (`claude-3-5-haiku-latest`, `gemini-1.5-flash`): update to current ones.
- `DropdownButtonFormField(value:)` is deprecated (`import_screen.dart`,
  `category_memory_screen.dart`): switch to `initialValue`.

---

## Done

- Parsers validated against real statements and reconciled by balance: moey (113 movements),
  ActivoBank (6/6) and Trade Republic (56/56); the last two were rewritten, and `canParse` now
  requires a structural marker.
- Mobile app verified with `flutter analyze` and `flutter test`.
- Dockerfile + `docker-compose.yml` (see `INSTALL.md`).
- `@actual-app/api` upgraded to 26.10 (requires Node 22+).
- Removing an import (soft delete) and forgetting category-memory mappings.
