## Melhorias 
- Meter um config para ser adaptavel a outros bancos.



## Melhorias detetadas pelo o Claude 
Good news: the codebase is much further along than "needs finishing" usually implies. I built the backend from scratch (npm install && npm run build && npm test) and it compiles clean with all 3 tests passing. Both the backend pipeline and the Flutter client implement the entire flow described in CLAUDE.md — auth, parse/review/confirm, category memory, AI fallback, password-protected PDFs, budget switching — with no stubs, TODOs, or dead ends in the code I read (server routes, actual.ts, categorydb.ts, all 3 bank parsers, both AI providers, and the full mobile screen stack: import → review → confirm, settings, category memory).

What's actually left is verification and a few scoped decisions, not missing features:

1. ~~Validate the regex parsers against real, current statements.~~ **Done.** All three were run against the real PDFs in `Docs/tests/` and reconciled against each statement's own running balance and `SALDO INICIAL`/`SALDO FINAL`:
   - **moey** was already correct — 113 movements, chain intact, 55.76 → 208.01.
   - **ActivoBank** and **Trade Republic** both extracted **zero** (silent 422 `NO_TRANSACTIONS`); both layouts had been reverse-engineered wrongly. Rewritten: ActivoBank 6/6 (300.15 + 0.45 = 300.60), Trade Republic 56/56 (3564.16 − 428.69 = 3135.47, in/out matching the summary block). Both now recover direction from the balance delta, since neither layout carries a sign. Covered by `activobank.test.ts` / `traderepublic.test.ts`.
   - Also fixed: `canParse` for ActivoBank and Trade Republic were substring sniffs, so a moey statement (which lists "TRANSF SEPA -Trade Republic Ba" as a payee) was claimed by two parsers and routed correctly only by chain order. Both sniffs now require a structural marker, with regression tests.
   - Still open: fixtures are synthetic, so nothing in `npm test` catches a *future* layout change — see "Known gaps" in `Docs/HowtoTest.md`.
2. Mobile app was never build-verified here (no Flutter SDK in this environment). Two spots in the code flag their own version fragility: import_screen.dart:268 (DropdownButtonFormField's value vs initialValue, Flutter-version-dependent) and share_intent_service.dart (receive_sharing_intent API shape across major versions). Run flutter pub get && flutter analyze && flutter test on a machine with Flutter installed before calling it done.
3. iOS share-sheet intake isn't wired. AndroidManifest.xml has the PDF SEND/VIEW intent filters; ios/Runner/Info.plist has no matching CFBundleDocumentTypes/share-extension entries. Right now sharing a PDF into the app only works on Android — iOS falls back to the file picker. Decide if that's acceptable or needs building out.
4. backend_app/Docs/Todo.md's own open item: make the bank parser config-driven so a new bank doesn't require writing a new .ts file. Currently "add a bank" = new parser file + one line in index.ts, which CLAUDE.md documents as the intended pattern — so this is a nice-to-have, not a blocker.
5. Deployment hardening, only if this goes beyond your own LAN: no Dockerfile/CI, and IMPORT_TOKEN is a bearer secret with no TLS termination documented — fine for local use (as the README says), worth revisiting if you expose it further.
6. Minor: ANTHROPIC_MODEL defaults to claude-3-5-haiku-latest; bump if you want current-gen quality by default.

Want me to tackle any of these — e.g. actually testing a real statement PDF through the parser, or setting up Flutter to run analyze/test?