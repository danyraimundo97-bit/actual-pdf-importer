# How to run

The step-by-step for getting the whole thing running: Actual Budget, the backend, and the mobile
app. For testing, see `HowtoTest.md` next to this file. For leaving the backend running on a home
server, see `INSTALL.md` at the repo root.

The pieces, and the order to start them:

```
Actual Budget server (:5006)  ←  backend_app (:3000)  ←  mobile_app (phone / emulator)
```

1. **Actual Budget server** — where your budget lives. The backend imports into it.
2. **Backend** — parses statement PDFs and talks to Actual.
3. **Mobile app** — uploads a statement, lets you review the transactions, confirms the import.

## Quick start

Already have Actual running and Node + Flutter installed? This is everything:

```bash
# terminal 1
cd backend_app
npm install
cp .env.example .env        # then fill in ACTUAL_SERVER_URL, ACTUAL_PASSWORD, IMPORT_TOKEN
npm run dev

# terminal 2
cd mobile_app
flutter pub get
flutter run
```

In the app's Settings: backend URL + the same `IMPORT_TOKEN`, pick a budget, done. The sections
below explain each step.

## Prerequisites

| Need | For | Check |
| --- | --- | --- |
| Node.js 22+ and npm | backend (required by `@actual-app/api`) | `node --version` |
| Flutter SDK with Dart 3.13+ | mobile app | `flutter --version` (update with `flutter upgrade`) |
| An Actual Budget server | importing | open `http://localhost:5006` in a browser |
| Docker *(optional)* | running Actual and/or the backend in containers | `docker compose version` |
| Anthropic or Gemini API key *(optional)* | only for `PARSER_MODE=ai` or `both` | — |

> **Windows / PowerShell:** commands in this file are written for Git Bash. In PowerShell, use
> `Copy-Item .env.example .env` instead of `cp`, and `curl.exe` instead of `curl` (in Windows
> PowerShell 5.1 `curl` is an alias for `Invoke-WebRequest`, which takes different arguments).

## Step 1 — Actual Budget server

Skip this if you already run one.

The quickest local one is the official Docker image:

```bash
docker run -d --name actual -p 5006:5006 -v actual-data:/data actualbudget/actual-server:latest
```

Open `http://localhost:5006`, set a server password, and create (or import) a budget.

Then grab the budget's **sync id**: in Actual, *Settings → Show advanced settings → Sync ID*. It's
optional for the backend (the app can pick a budget at runtime), but setting it gives you a
default.

## Step 2 — Backend (`backend_app/`)

### Configure

```bash
cd backend_app
npm install
cp .env.example .env
```

Edit `.env`:

| Variable | Set it to | Required? |
| --- | --- | --- |
| `ACTUAL_SERVER_URL` | Your Actual server, e.g. `http://localhost:5006`. Setting it locks the connection | no — the app can connect instead |
| `ACTUAL_PASSWORD` | The Actual server password from step 1 | with `ACTUAL_SERVER_URL` |
| `ACTUAL_BUDGET_SYNC_ID` | The sync id from step 1 | no — the app can choose |
| `IMPORT_TOKEN` | A shared secret the app sends on every request | strongly recommended |
| `PARSER_MODE` | `regex` (default, fully offline), `ai`, or `both` | no |
| `AI_PROVIDER` + `ANTHROPIC_API_KEY` / `GEMINI_API_KEY` | Only if `PARSER_MODE` is `ai` or `both` | conditional |
| `PORT` | Defaults to `3000` | no |

Leave `ACTUAL_DATA_DIR` and `CATEGORY_DB_PATH` as they are; both are created automatically.

To generate a token:

```bash
openssl rand -hex 32
```

Leaving `IMPORT_TOKEN` empty turns authentication **off** — anything that can reach port 3000 can
read and write your budget. Fine for a five-minute local test, not otherwise.

### Start it

Pick one:

```bash
npm run dev                  # development — auto-restarts when you edit src/
npm run build && npm start   # compiled build from dist/, how it runs in production
docker compose up -d --build # from the repo root — see INSTALL.md
```

A healthy start prints:

```
[parsers] PARSER_MODE=regex — active parsers: activobank, moey, traderepublic
PDF importer backend listening on port 3000
```

If it exits immediately, read the last lines: a `PARSER_MODE` of `ai`/`both` without the matching
API key fails at startup on purpose, rather than on your first upload.

### Check it

```bash
curl http://localhost:3000/health
# {"status":"ok"}

curl -H "X-Import-Token: <your token>" http://localhost:3000/budgets
# a list of your budgets
```

`/health` only proves the backend is up. `/budgets` goes all the way to Actual, so if it returns
your budgets, the `ACTUAL_*` settings are right.

### Try a statement without the app *(optional)*

`POST /parse` reads a PDF and returns the transactions **without touching Actual**, so it's the
fastest way to see whether a statement is recognized:

```bash
curl -X POST http://localhost:3000/parse \
  -H "X-Import-Token: <your token>" \
  -F "statement=@Docs/tests/Moey - julho 2026.pdf"
```

Supported banks with the default `regex` mode: **ActivoBank, moey!, Trade Republic**. Anything else
returns `BANK_UNRECOGNIZED` unless you switch `PARSER_MODE` to `both` or `ai`.

## Step 3 — Mobile app (`mobile_app/`)

```bash
cd mobile_app
flutter pub get
flutter devices              # list emulators / phones / desktop targets
flutter run                  # or: flutter run -d <device-id>
```

On first launch the app opens **Settings** and every other screen stays locked until a backend
URL is saved. Fill in:

**Backend URL** — where the backend is reachable *from the device running the app*:

| App runs on | Backend URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:3000` |
| iOS simulator or desktop | `http://localhost:3000` |
| Physical phone | your computer's LAN IP, e.g. `http://192.168.1.10:3000` |

For a physical phone: phone and computer must be on the same Wi-Fi, and Windows Firewall must allow
inbound TCP 3000 (Windows prompts the first time Node listens — allow it on *Private* networks).
Find your IP with `ipconfig` (the *IPv4 Address* of your Wi-Fi adapter).

**API token (X-Import-Token)** — exactly the `IMPORT_TOKEN` from `backend_app/.env`. Leave empty
only if auth is off.

**Budget** — pick the one to import into, and enter its budget password if it has one.

## Step 4 — Import a statement

1. **Import** screen: choose the Actual account to import into, then pick a statement PDF — or, on
   Android, share one to the app from another app. If the PDF is password-protected, the app asks
   for the password.
2. **Review** screen: check the parsed transactions and edit the payee, amount, date or category.
3. **Confirm**: the transactions land in Actual.

The app sends one statement at a time. To parse several in one go, send several files
to the backend's `POST /parse` directly (see `HowtoTest.md`).

Importing the same statement twice is safe — Actual de-duplicates it, so the second import adds
nothing.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| App can't connect at all | Wrong backend URL for the device (see the table in step 3), backend not running, or firewall blocking port 3000. Try `http://<url>/health` in the phone's browser. |
| Every request returns `401` | Token in the app doesn't match `IMPORT_TOKEN`. Re-enter it in Settings after changing `.env`, and restart the backend. |
| `/health` works but `/budgets` fails | Backend can't reach or log into Actual — check `ACTUAL_SERVER_URL` and `ACTUAL_PASSWORD`. In Docker, `localhost` means the container itself; see `INSTALL.md`. |
| `NO_BUDGET_SELECTED` | No budget picked in the app and no `ACTUAL_BUDGET_SYNC_ID` in `.env`. |
| `BANK_UNRECOGNIZED` | Not ActivoBank / moey! / Trade Republic, and `PARSER_MODE=regex`. |
| `NO_TRANSACTIONS` | The parser recognized the bank but found no rows — the bank probably changed its layout. See `HowtoTest.md`. |
| `TOO_MANY_FILES` | More than 20 files sent to `/parse` (or more than 1 to the legacy `/import`). |
| `FILE_TOO_LARGE` / `BATCH_TOO_LARGE` | One file over 20MB / all files together over 50MB. The backend log has an `[upload]` line with the count and total size. |
| `PDF_PASSWORD_REQUIRED` / `PDF_PASSWORD_INCORRECT` | The statement is encrypted. The app prompts for the password; with `curl`, add `-F "password=…"`. |
| `SELF_SIGNED_CERT_IN_CHAIN` | Actual uses HTTPS with a self-signed cert. Set `NODE_EXTRA_CA_CERTS` to its CA — see `INSTALL.md`. |
| Backend exits right after starting | `PARSER_MODE` is `ai`/`both` but the API key for `AI_PROVIDER` is missing. |
