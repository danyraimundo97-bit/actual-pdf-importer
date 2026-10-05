# Installing on a home server (Docker Compose)

For running the backend locally during development, see `RUNNING.md` instead. This document is
about leaving it running on a server.

Only `backend_app/` is deployed. The Flutter app is built and installed separately; it just needs
to reach this server over your LAN.

## What you need

- Docker Engine with the Compose plugin (`docker compose version` should print v2 or newer)
- A reachable **Actual Budget server** and its password
- ~500MB of disk for the image

Works on x86-64 and arm64 (Raspberry Pi 4/5). No Node.js needed on the host — it's in the image.

## 1. Get the code and configure it

```bash
git clone <your-repo-url> actual-pdf-importer
cd actual-pdf-importer/backend_app
cp .env.example .env
```

Edit `backend_app/.env`. The three that matter for a server:

| Variable | Set it to |
| --- | --- |
| `IMPORT_TOKEN` | **A long random secret.** Leave it empty and the server runs with *no authentication* — anything on your LAN can read and write your budget. Generate one with `openssl rand -hex 32`. |
| `ACTUAL_SERVER_URL` | Your Actual server, e.g. `http://192.168.1.50:5006`. Not `localhost` — see step 4. |
| `ACTUAL_PASSWORD` | Your Actual server password. |

`ACTUAL_BUDGET_SYNC_ID` is optional (the app can pick a budget at runtime). Leave `PARSER_MODE=regex`
unless you want the AI fallback, in which case also set `AI_PROVIDER` and the matching API key.

**Do not set `ACTUAL_DATA_DIR` or `CATEGORY_DB_PATH`** — `docker-compose.yml` sets those to paths
inside the container's data volume and they must stay that way.

## 2. Start it

From the repository root:

```bash
docker compose up -d --build
docker compose logs -f
```

A healthy start logs three lines:

```
[parsers] PARSER_MODE=regex — active parsers: activobank, moey, traderepublic
PDF importer backend listening on port 3000
```

If you also see this, stop and go back to step 1:

```
[auth] IMPORT_TOKEN is not set — running with NO authentication.
```

Check it answers:

```bash
curl http://localhost:3000/health          # {"status":"ok"}
```

`/health` is the only route without auth. Everything else needs `X-Import-Token`:

```bash
curl -H "X-Import-Token: <your token>" http://localhost:3000/budgets
```

That one round-trips to Actual, so it's the real test that steps 1 and 4 are right.

## 3. Point the app at it

In the mobile app's Settings, set the backend URL to `http://<server-lan-ip>:3000` and paste the
same `IMPORT_TOKEN`. Use the server's LAN IP, not `localhost` — that would mean the phone itself.

## 4. Reaching your Actual server

The container has its own network namespace, so `localhost` inside it is **the container**, not your
server. If `ACTUAL_SERVER_URL` points at `localhost:5006` the connection will be refused.

| Where Actual runs | Use |
| --- | --- |
| Another machine on the LAN | its IP, e.g. `http://192.168.1.50:5006` |
| Same host, outside Docker | `http://host.docker.internal:5006` (add `extra_hosts: ["host.docker.internal:host-gateway"]` on Linux), or the host's LAN IP |
| Same host, in Docker | put both on one network and use Actual's service name |

### If Actual uses HTTPS with a self-signed certificate

Node rejects it, and you'll see `SELF_SIGNED_CERT_IN_CHAIN` or `UNABLE_TO_VERIFY_LEAF_SIGNATURE`.
The right fix is to trust the CA rather than disable verification:

1. Put the CA certificate at `certs/ca.pem` next to `docker-compose.yml`
2. Uncomment the `./certs:/certs:ro` volume line
3. Add `NODE_EXTRA_CA_CERTS=/certs/ca.pem` to `backend_app/.env`
4. `docker compose up -d`

`NODE_TLS_REJECT_UNAUTHORIZED=0` also "works" but disables certificate checking for every outbound
connection the process makes, including the AI provider if you enable it. Avoid it.

## Your data

Everything persistent lives in one named volume, `actual-pdf-importer_importer-data`:

| Path in volume | What it is |
| --- | --- |
| `/data/categories.db` | **The payee → category memory. This is user data.** Lose it and you re-teach every mapping. |
| `/data/actual-cache/` | Actual's downloaded budget cache. Rebuildable — it just re-downloads. |

Uploaded PDFs are **never written to disk**, in the container or anywhere else — they're held in
memory only and discarded after parsing. That's a deliberate invariant of the code, so there is no
statement data to back up or shred.

Back up the category memory:

```bash
docker compose cp importer:/data/categories.db ./categories-backup.db
```

Restore it into a fresh deployment:

```bash
docker compose cp ./categories-backup.db importer:/data/categories.db
docker compose restart
```

If you'd rather have the data in a directory you can see, replace `- importer-data:/data` with
`- ./data:/data` and drop the `volumes:` block at the bottom. On Linux, `chown 1000:1000 ./data`
first — the container runs as the unprivileged `node` user (uid 1000).

## Updating

```bash
git pull
docker compose up -d --build
```

The container stops with `SIGTERM`, which the server handles by waiting for any in-flight Actual
work before closing the connection, so an import in progress is never cut in half.
`stop_grace_period` is set to 30s to give that time.

## Troubleshooting

**`docker compose config` prints your password and API keys.** It resolves everything, secrets
included. Fine for debugging, but don't paste the output anywhere.

**Don't switch the secrets to `env_file:`.** It looks tidier and it silently corrupts passwords:
Compose interpolates `${VAR}` and `$VAR` *inside* an env_file, so an `ACTUAL_PASSWORD` containing
a `$` arrives truncated at the first `$` and Actual rejects it with a confusing auth error. The
`.env` is bind-mounted and parsed by the app's own dotenv instead, which keeps it byte-exact. This
is why the compose file looks the way it does.

**Container can't read `/app/.env`.** The bind mount keeps the host file's permissions. If the file
is `0600` and owned by a user other than uid 1000, the `node` user can't read it:
`chmod 644 backend_app/.env`.

**Build fails compiling `better-sqlite3`.** It's a native module; the build stage installs
`python3 make g++` for platforms with no prebuilt binary. If it still fails you're likely low on
memory — a 1GB Raspberry Pi may need swap.

**`422` with `code: "BANK_UNRECOGNIZED"` or `"NO_TRANSACTIONS"`.** Not a deployment problem: the
statement's layout isn't one the parsers know, or it changed. See `backend_app/Docs/HowtoTest.md`.

**Everything returns `401`.** The `X-Import-Token` header doesn't match `IMPORT_TOKEN`. Note the
app stores the token in secure storage — re-enter it in Settings after changing it.

## A note on exposing this

This is a LAN service: plain HTTP, and a single shared secret rather than real accounts. Don't port
forward it to the internet as-is. If you need remote access, put it behind a VPN (WireGuard,
Tailscale) or a reverse proxy that terminates TLS.
