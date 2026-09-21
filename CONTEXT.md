# Domain glossary

Terms used across `backend_app/` and `mobile_app/`. Code, docs and architecture discussions should use these names.

## Budget session

The backend's single, exclusive hold on Actual Budget. `@actual-app/api` keeps one global connection with one budget loaded at a time, so every piece of Actual work (importing, listing accounts, learning categories, reading spending data) runs as one **turn** of the budget session:

- a turn names the budget it needs (`syncId`, optional budget password); the session downloads/swaps it in only if it isn't already loaded;
- the whole callback runs inside the turn, so no other request can swap the budget mid-operation;
- turns are strictly serialized, never run concurrently, even for the same budget;
- a failed budget swap leaves the session with **no** budget loaded, so the next turn always re-downloads.

Server credentials (Actual server URL, server password, cache dir) are fixed when the session is created; only the budget choice varies per request. Not to be confused with a user/login session. The backend has none (auth is a shared `X-Import-Token`).

## Budget password vs. statement password

Two unrelated secrets. The **budget password** decrypts an end-to-end-encrypted Actual budget file. The **statement password** opens a password-protected bank statement PDF. They are never the same secret and must never be conflated in the API or UI.
