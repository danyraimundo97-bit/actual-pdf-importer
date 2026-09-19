# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This repo has two independent projects with no shared build/tooling:

- `backend_app/` — Node.js/TypeScript/Express bridge that parses bank statement PDFs and imports transactions into [Actual Budget](https://actualbudget.org) via `@actual-app/api`.
- `mobile_app/` — Flutter app (Riverpod + go_router) that is the client for that backend: upload a statement, review parsed transactions, confirm/ the import.

Everything below a project's own directory should be treated as that project's scope; there's no monorepo tooling tying them together.

## backend_app

### Commands

Run from `backend_app/`:

```bash
npm install
cp .env.example .env        # fill in ACTUAL_* values; see comments in the file
npm run dev                 # ts-node-dev, auto-restarts on change
npm run build                # tsc -> dist/
npm start                    # node dist/server.js (run build first)
npm test                     # node --test 'dist/**/*.test.js' — MUST run `npm run build` first, tests execute from dist/, not src/
```

There is no single-test-file npm script; run one compiled test directly, e.g. `node --test dist/__tests__/categorydb.test.js` (after `npm run build`).

`GET /health` returns `{ "status": "ok" }` once the server is running — no auth required on that one route.

### Architecture

**Parsing pipeline** (`src/index.ts` is the entry point, `processStatement()`):
- `PARSER_MODE` env var (`regex` | `ai` | `both`) picks the strategy at startup, not per-request. `regex` runs only the local bank-specific parsers; `ai` sends raw PDF bytes straight to the AI provider (no local text extraction, more layout fidelity); `both` runs regex parsers first and falls back to a text-based AI parser only for unrecognized statements.
- Each bank parser (`src/parsers/activobank.ts`, `moey.ts`, `traderepublic.ts`) implements the `BankParser` interface (`src/types.ts`): a cheap `canParse(text)` sniff plus `parse(text)`. Bank identification is done by content-sniffing the extracted text, never by filename — statements get renamed/forwarded.
- The AI parser (`src/parsers/aiparser.ts`) is a `BankParser` too (`bankId: 'ai'`), so it slots into the same chain used by `both`.
- AI vendors are behind a Strategy interface, `AiProvider` (`src/parsers/ai-providers/types.ts`); `src/parsers/ai-providers/index.ts` is the factory picking anthropic/gemini via `AI_PROVIDER`. Code outside `ai-providers/` never touches a vendor SDK directly. **Adding a new vendor**: one new file implementing `AiProvider`, plus one line in that folder's `index.ts` factory map.
- Startup fails fast (not on first upload) if `PARSER_MODE` needs an AI provider that isn't configured — see the `provider.isConfigured()` check in `src/index.ts`.
- Password-protected PDFs: `PARSER_MODE=ai` can't send encrypted bytes straight to a provider (no way to decrypt them), so that one statement transparently downgrades to local text extraction + the text-based AI parser. pdf.js password error codes map to `PdfPasswordRequiredError` (code 1) / `PdfPasswordIncorrectError` (code 2) in `src/errors.ts`.

**Two import flows**, both in `src/server.ts`:
- Recommended: `POST /parse` (extracts + returns transactions with a `suggestedCategoryId`/dedupe `importedId`, does *not* touch Actual) → client reviews/edits → `POST /import/confirm` (JSON, actually imports). Editing a transaction's date/amount/payee client-side and re-submitting must still pass back the original `importedId` unchanged, since that id is derived from those three fields (`deriveImportedId` in `src/actual.ts`) and re-deriving it after an edit breaks dedupe on re-import of the same statement.
- Legacy: `POST /import` (multipart, parse+import in one call, no review step). Kept for backwards compatibility only.

**`src/actual.ts`** wraps `@actual-app/api`, which holds exactly one global connection to one downloaded budget at a time. `ensureInitialized()`/`ensureServerInitialized()` serialize all init/budget-download calls through a single promise queue (`queue`) so concurrent requests for different budgets don't race into a half-swapped state, and a budget that's already loaded is never redundantly re-downloaded.

**`src/categorydb.ts`** is a local SQLite-backed payee→category memory (not Actual's own category data), scoped per `budgetSyncId` with an "unscoped" fallback for mappings created before scoping existed. It's a complement to Actual's fuzzy rules engine, not a replacement — matching here is exact on cleaned/normalized payee text. Populated either directly (`POST /categories`) or backfilled from already-categorized Actual transactions (`POST /categories/learn-from-actual`, implemented as `learnCategoriesFromActual` in `src/actual.ts`).

**Errors** (`src/errors.ts`): route handlers throw a typed `ImporterError` subclass (never a plain `Error`, for expected failure modes); `server.ts`'s `sendImporterError()` maps it straight to a JSON response with a stable machine-readable `code` field. Clients should branch on `code`, never on the English `error` message.

**Auth**: a single shared-secret header, `X-Import-Token`, checked with `crypto.timingSafeEqual` (`src/server.ts`). Every route requires it except `GET /health`. Leaving `IMPORT_TOKEN` unset in `.env` disables auth entirely (loudly logged at startup) — acceptable for local testing only.

**Privacy invariant**: uploaded PDFs are handled via `multer.memoryStorage()` only — never written to disk. Keep this in mind before changing upload handling.

### Environment variables

See `.env.example` for the full annotated list (`PARSER_MODE`, `AI_PROVIDER`, `ANTHROPIC_API_KEY`/`ANTHROPIC_MODEL`, `GEMINI_API_KEY`/`GEMINI_MODEL`, `ACTUAL_*`, `IMPORT_TOKEN`, `CATEGORY_DB_PATH`).

## mobile_app

Flutter app, no CLI-buildable commands verified in this environment beyond the standard `flutter pub get` / `flutter run` / `flutter analyze` / `flutter test`. `analysis_options.yaml` includes the standard `flutter_lints` set with no project-specific overrides.

### Architecture

- State management: Riverpod. All providers are centralized in `lib/data/providers.dart` — `appConfigProvider` (backend URL + active budget, kept atomic via `copyWith` so a budget switch never leaves syncId/name out of sync) drives `apiClientProvider`, which rebuilds a fresh `Dio` instance (`lib/data/api/api_client.dart`) whenever the backend URL changes, rather than mutating `baseUrl` on a shared instance in place.
- Routing: go_router (`lib/core/router.dart`), a single `GoRouter` built once via a `Provider`. A `redirect` callback (re-evaluated by go_router on every navigation) gates all routes behind `/settings` until a backend URL is configured — this is the "first run" flow, not a rebuilt router.
- Auth token and other secrets: `lib/data/local/secret_store.dart` (`flutter_secure_storage`), injected into `ApiClient` and attached to every request as `X-Import-Token` via a Dio interceptor. Non-secret settings (backend URL, budget syncId/name) live in `lib/data/local/settings_store.dart` (`shared_preferences`).
- API layer: `lib/data/api/importer_api.dart` and `categories_api.dart` are thin wrappers around `ApiClient`/Dio, mirroring the backend's `/parse`, `/import/confirm`, `/categories*` routes described above.
- Screens live under `lib/features/<feature>/screens/`, mirroring the backend's flow: `import` (pick/upload a statement) → `review` (edit parsed transactions, `review_screen_args.dart` carries the parse result across the route) → confirm import. `category_memory_screen.dart` manages the payee→category mappings.
- `receive_sharing_intent` is pinned to the 1.8.x API for Android share-sheet PDF intake — see the doc comment above that dependency in `pubspec.yaml` before bumping its major version.
