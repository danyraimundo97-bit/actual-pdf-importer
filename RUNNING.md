# Running the project locally

This repo has two independent projects:

- `backend_app/` — Node.js/TypeScript bridge that parses bank statement PDFs and imports them into Actual Budget.
- `mobile_app/` — Flutter client that talks to that backend.

Start the backend first, then point the mobile app at it.

## Prerequisites

- **Node.js 20+** and npm (backend)
- **Flutter SDK 3.44+** with Dart `3.13+` (mobile app) — check with `flutter --version`, update with `flutter upgrade`, plus an Android emulator/device, iOS simulator, or desktop target
- A running **Actual Budget server** (self-hosted, default `http://localhost:5006`)
- *Optional:* an Anthropic or Gemini API key if you want the AI parser

## 1. Backend (`backend_app/`)

```bash
cd backend_app
npm install
cp .env.example .env
```

Edit `.env` — at minimum:

| Variable | What to set |
| --- | --- |
| `ACTUAL_SERVER_URL` | URL of your Actual server (e.g. `http://localhost:5006`) |
| `ACTUAL_PASSWORD` | Your Actual server password |
| `ACTUAL_BUDGET_SYNC_ID` | Default budget's sync id (Actual → Settings → Show advanced settings) |
| `IMPORT_TOKEN` | A shared secret the app must send. Leave empty only for quick local tests (no auth) |
| `PARSER_MODE` | `regex` (default, fully offline), `ai`, or `both` |
| `AI_PROVIDER` + `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` | Only needed when `PARSER_MODE` is `ai` or `both` |
| `PORT` | Defaults to `3000` |

See the comments in `.env.example` for the full list.

Run it:

```bash
npm run dev      # development, auto-restarts on change
# or
npm run build && npm start   # production build from dist/
```

Check it's up:

```bash
curl http://localhost:3000/health
# {"status":"ok"}
```

Run the tests:

```bash
npm test         # rebuilds, then runs the compiled tests in dist/
```

> The server fails at startup if `PARSER_MODE` needs an AI provider whose API key is missing — check the console output if it exits immediately.

## 2. Mobile app (`mobile_app/`)

```bash
cd mobile_app
flutter pub get
flutter devices          # list available targets
flutter run              # or: flutter run -d <device-id>
```

On first launch the app opens **Settings** — every other screen is locked until a backend URL is configured. Fill in:

- **Backend URL** — where the backend is reachable *from the device*:
  - Android emulator: `http://10.0.2.2:3000`
  - iOS simulator / desktop: `http://localhost:3000`
  - Physical phone: your computer's LAN IP, e.g. `http://192.168.1.10:3000` (phone and computer on the same network; allow port 3000 through your firewall)
- **API token (X-Import-Token)** — the same value as `IMPORT_TOKEN` in the backend's `.env` (leave empty if auth is disabled)
- Pick the **budget** to import into (and its budget password, if it has one)

Other useful commands:

```bash
flutter analyze
flutter test
```

## Typical flow

1. Start Actual Budget server.
2. `cd backend_app && npm run dev`
3. `cd mobile_app && flutter run`
4. In the app: Settings → Import (pick or share a statement PDF) → Review → Confirm import.
