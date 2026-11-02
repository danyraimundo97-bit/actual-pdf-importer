# Plan: logging in the backend and the app

Source: `backend_app/Docs/Todo.md` §4, "Logging in the backend and the app", plus these
requirements:

- Log everything, at three levels:
  - **debug**: the detail, written only when a debug flag is on;
  - **info**: what happened (requests, imports, connections), always written;
  - **error** ("bugs"): failures and crashes, always with a stack trace, always written.
- Info and error must survive: they go to a file, not only to the console.

Branch `feature/logging`. Merge it **before** `feature/core-app` and `feature/dart-parser`, so
both build on the same logger instead of adding `print`s now and replacing them later.

---

## Shared rules (backend and app)

**Levels**: `debug` < `info` < `warn` < `error`. `warn` is always written, like info. It covers
expected-but-notable cases, e.g. a typed `ImporterError` such as a 422 `NO_TRANSACTIONS`. `error`
is reserved for real bugs: unhandled exceptions, 500s, crashes.

**Debug flag**:
- Backend: `LOG_DEBUG=true` in `.env`.
- App: `--dart-define=LOG_DEBUG=true` sets the default (and `dev.json` turns it on), and a
  "Verbose logging" switch in Settings → Diagnostics overrides it at runtime, so a release build
  installed on the phone can be debugged.
- Turning it on or off is itself logged at info.

**Line format** (human-readable in the console, one JSON object per line in files):

```
2026-11-02T10:15:03.120Z INFO  http     POST /parse 200 812ms req=7f3a…
2026-11-02T10:15:03.118Z DEBUG parser   detected bank=moey lines=412 transactions=37
2026-11-02T10:15:09.441Z ERROR import   Unhandled error  req=91bc…  TypeError: …stack…
```

Each line has: time (UTC), level, **area** (`http`, `parser`, `session`, `import`, `categories`,
`actual`, `ai`, `ui`, `nav`, `app`, …), message, structured fields, and the **request id** when
there is one.

**Request ids join both logs**: the app generates `X-Request-Id` per request, the backend logs
it (or makes one if absent) and returns it in the response and in error JSON. A failure on the
phone can then be found in the backend log by id.

**Never logged, at any level, including debug**: `X-Import-Token`, any password (statement,
budget, Actual server), API keys, PDF bytes or extracted PDF text. Enforced in code, not by
convention: a redaction list in each logger (field names such as `token`, `password`,
`authorization`, `apiKey`), plus tests asserting these values never reach the output.

**Personal banking data** (decided 2026-11-02):

- **Amounts and balances: never, at any level.** Debug lines say `amount=<redacted>`, or just
  leave the field out.
- **Payees and descriptions: debug only**, never at info/warn/error. Useful for parser debugging
  (which line matched, was misparsed or skipped) and category lookups (the normalised
  `payee_key` that missed).
- **Ids: allowed at every level**: `importedId`, Actual transaction/account/category ids,
  budget sync id, request id. They're how a duplicate on re-import, an undo that skipped a row
  or a sync conflict is traced from the phone's log to the backend's.
- Dates and bank ids: allowed at every level.
- Enforced by field name in both loggers: `amount`, `amountCents`, `balance*`, `*Cents` are
  always stripped; `payee`, `payeeKey`, `description`, `rawLine` are stripped unless the debug
  flag is on. `rawLine` is the full statement line *including its amount*, so it's never logged
  whole: the parser logs it as `payee` + `date` + line number instead. Tests cover each field.
- Because debug logs can contain payees, "Share logs" says so when the files include debug
  lines ("These logs include payee names. Share only with someone you trust."), and turning the
  debug flag off offers to clear the debug lines already written.

---

## Backend

- **Library: `pino`** (fast, JSON lines, built-in `redact`). `pino-pretty` for the console in
  `npm run dev`; `pino-roll` for the file.
- `src/logger.ts`: one root logger and `logger.child({ area })` per module. Level is `debug` if
  `LOG_DEBUG`, else `info`.
- **Destinations**: stdout (Docker captures it) **and** `logs/backend.log` (`LOG_DIR`, default
  next to the category DB, mounted as a volume in `docker-compose.yml`). Rotated daily or at
  10 MB, keep 14 files.
- **What gets logged**:
  - info:
    - one line per request: method, path (no query string values), status, duration, request id;
    - startup: parser mode, AI provider, Actual connection state (never the password);
    - import/undo summaries: counts and account id;
    - connection changes.
  - warn: every `sendImporterError` with its `code`; auth rejections (source IP, never the
    token sent); a budget download that's retried.
  - error: unhandled route errors (the global error handler), `unhandledRejection`,
    `uncaughtException` (logged, flushed, then exit as now), and failed Actual syncs.
  - debug:
    - budget session turns: wait time, run time, whether the budget was swapped or reused, sync
      duration;
    - parser chain: which `canParse` matched, line and transaction counts, and per transaction
      its line number, date, payee and `importedId` (never the amount);
    - AI calls: provider, model, latency, token counts;
    - category lookups: payee, normalised `payee_key`, scope, hit/miss and the category id.
- Replace the existing 21 `console.*` calls.
- **`GET /logs?tail=500&level=info`** (auth required; refused with 403 when `IMPORT_TOKEN` is
  unset): returns recent lines so the app can attach backend logs to a report.
- Tests (`logger.test.ts`): redaction of every secret field and of amounts at every level,
  payees only with the debug flag, the debug lines are absent without
  the flag, request id round-trip, `/logs` refused without auth.

## App

- **Library: `package:logging`** (Dart team, tiny) behind our own `lib/core/log/log.dart`:
  `final log = AppLog('parser'); log.debug(...)`, `info`, `warn`, `error(msg, error, stack)`.
  Code never calls `print`/`debugPrint` directly (a lint: `avoid_print` is already in
  `flutter_lints`).
- **Sinks**:
  - Console: `dart:developer` `log()` in debug builds.
  - **File, always on** (`path_provider`): `<app support dir>/logs/app-YYYY-MM-DD.log`, JSON
    lines, kept 7 days or 5 MB in total, whichever is smaller. Writes are buffered and flushed
    every second and immediately on `error`.
  - In-memory ring buffer (last ~2000 lines), so the log viewer works on web, where there's no
    file system; on web this buffer is the only store.
- **What gets logged**:
  - info:
    - app start: version, build mode, platform;
    - connection tests and their result;
    - every backend request via a Dio interceptor: method, path, status, duration, request id;
    - statement queued / parsed / imported (counts only);
    - settings changes (names, never values of secrets).
  - warn: API errors with their backend `code`; offline / unreachable.
  - error, with stack traces:
    - `FlutterError.onError` (framework errors);
    - `PlatformDispatcher.instance.onError` (uncaught async errors);
    - `Isolate` errors from the parser isolate;
    - a Riverpod `ProviderObserver.providerDidFail`.
  - debug: navigation (a `NavigatorObserver` on go_router), provider rebuilds of interest,
    request query parameters (with secrets redacted), parser steps (bank, counts, timings),
    extraction timings.
- **Settings → Diagnostics** (new section):
  - "Verbose logging" switch (the runtime debug flag);
  - "View logs": a filterable list by level and area;
  - "Share logs": a zip of the app log files plus the backend's `/logs` tail if reachable,
    via `share_plus`;
  - "Clear logs".
  - The dev screen links to the same viewer.
- Tests: redaction, the debug lines are dropped without the flag and kept with it, retention
  pruning, the Dio interceptor puts `X-Request-Id` on every request and never logs the token.

## Order

1. Backend: `logger.ts`, request logging + request id, the error/warn paths, replace
   `console.*`, then the debug lines, then `/logs`.
2. App: `AppLog` + console and buffer sinks, global error hooks, Dio interceptor, the file sink,
   then the Diagnostics UI and share.
3. Docs: `.env.example` (`LOG_DEBUG`, `LOG_DIR`), `docker-compose.yml` volume, `CLAUDE.md`
   (area names, the never-log list), mark the TODO item done.

## Done criteria

- With no flag: only info/warn/error lines, in both the console and the file, on both sides.
- With the flag: debug lines appear too, with no restart needed in the app.
- A failed import on the phone can be followed to the backend log through its request id.
- `npm test` and `flutter analyze && flutter test` green, including the redaction tests.
