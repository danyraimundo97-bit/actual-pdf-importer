# Feature plan: AI spending insights

## Context
The app already imports and categorizes transactions into Actual Budget. The next step is to answer "where am I spending too much?" over a month, a range of months or a year. The approach we agreed on:

- **Compute every number locally and deterministically**, using Actual's data: totals, averages, budget vs. actual and trends.
- **Send only that compact summary to the AI provider.** Raw transactions never leave the machine. The model interprets the numbers and writes suggestions. It never does the arithmetic.

This keeps the results accurate, because LLMs are unreliable at summing hundreds of rows. It also sends far less personal data, which matters on Gemini's free tier, where Google can use submitted data to improve its products. And it keeps the request small enough to fit easily within free-tier limits.

**Deliverable when implementing:** copy this plan into the repo as `docs/features/spending-insights.md`, then build it in the phases below.

---

## Phase 1: Local aggregation (backend, no AI)

**New file `backend_app/src/insights.ts`**, a pure function with no I/O, so it's easy to unit-test:
- `buildSpendingSummary(input): SpendingSummary`
- Input: a list of months, each with its categories (`name`, `group`, `budgeted`, `spent`, `isIncome`), plus the top payees per category.
- Output (all amounts in euros, rounded to 2 decimal places):
  ```ts
  interface SpendingSummary {
    period: { from: string; to: string; months: number };  // YYYY-MM
    income: { total: number; monthlyAvg: number };
    spending: { total: number; monthlyAvg: number; savingsRate: number };
    categories: Array<{
      name: string; group: string;
      monthly: number[];            // spent per month, aligned to period
      avg: number; budgetedAvg: number;
      overBudgetPct: number | null; // null if nothing budgeted
      trendPct: number;             // avg of the second half of the range vs. the first half
      shareOfSpending: number;      // 0..1
      topPayees: Array<{ name: string; total: number }>; // max 3
    }>;
  }
  ```
- Sort by total spent (highest first). Drop categories with zero spend. Exclude income categories and transfers from spending.

**In `backend_app/src/actual.ts`**, add `getSpendingData(config, fromMonth, toMonth)`:
- Call `ensureInitialized(config)` first, like the other exported functions do.
- For each month, call `actualApi.getBudgetMonth(month)`, which gives `budgeted`/`spent` per category in cents. Budget data is already categorized and excludes transfers, so it avoids re-implementing that logic.
- For top payees: call `actualApi.getAccounts()` (skipping closed and off-budget accounts), then `getTransactions(accountId, start, end)`, then group by category and payee. Look up payee and category names the same way `learnCategoriesFromActual` does (`getPayees` / `getCategories` maps).
- Convert cents to euros here, before calling `buildSpendingSummary`.

**Route in `backend_app/src/server.ts`:** `GET /insights/summary?from=YYYY-MM&to=YYYY-MM&budgetSyncId=`
- Follow the pattern of `/accounts`: `resolveActualConfig`, try/catch, `sendImporterError`.
- Validate the month format and require `from <= to`, with a maximum of 24 months. Return 400 with `code: 'MISSING_FIELD'` / `'INVALID_RANGE'`.
- This works without any AI configured. It's already useful on its own.

## Phase 2: AI interpretation

**`backend_app/src/parsers/ai-providers/types.ts`:** add a method to `AiProvider`:
```ts
generateSpendingInsights(summary: SpendingSummary): Promise<SpendingInsights>;
```
```ts
interface SpendingInsights {
  headline: string;                                  // one sentence
  overspending: Array<{ category: string; reason: string; monthlyExcess: number }>;
  trends: Array<{ category: string; observation: string }>;
  anomalies: Array<{ category: string; month: string; observation: string }>;
  suggestions: Array<{ action: string; estimatedMonthlySaving: number | null }>; // 3-5
}
```
- Put `SpendingSummary` / `SpendingInsights` in a shared types spot (`src/types.ts` or `insights.ts`), so `ai-providers/` doesn't import from app logic in a circular way.

**Prompt:** add a new `INSIGHTS_SYSTEM_PROMPT` in `ai-providers/prompt.ts`, next to `EXTRACTION_SYSTEM_PROMPT`. Key rules for the model:
- Use only the numbers provided. Never invent or recompute totals.
- Be concrete and reference categories by name.
- Keep the tone neutral and practical, not preachy.
- Respond in the user's language (make it configurable later, default Portuguese or English).

**Implement it in both providers:**
- `gemini-provider.ts`: reuse the existing `responseSchema` + `application/json` pattern, with a new `INSIGHTS_RESPONSE_SCHEMA`. Pull the JSON-parse and error handling out of `runExtraction` into a small shared helper.
- `anthropic-provider.ts`: use the same tool-use schema pattern it already uses for extraction.
- Default model: while you're there, bump `GEMINI_MODEL` in `.env.example` and the fallback in `gemini-provider.ts` from the retired `gemini-1.5-flash` to a current Flash model.

**Route:** `POST /insights` with body `{ from, to, budgetSyncId?, budgetPassword? }`
- The route builds the summary (Phase 1), calls `getAiProvider().generateSpendingInsights(summary)`, and returns `{ summary, insights }`, so the client can show real numbers next to the AI's interpretation.
- This must work even when `PARSER_MODE=regex`. Check `provider.isConfigured()` per request, and throw a new typed error `AiNotConfiguredError` (code `AI_NOT_CONFIGURED`) in `src/errors.ts` if it fails. Don't add a startup check, since insights are optional.
- Wrap provider failures in a typed `AiProviderError` (code `AI_PROVIDER_ERROR`), which covers rate limits and invalid JSON. Clients branch on `code`.
- Extend `GET /config` with `insightsAvailable: boolean`, so the app can hide the AI button.

**Privacy rule (put it in a comment near the route):** only the `SpendingSummary` is sent. It contains no dates of individual transactions, no account names or IBANs, and at most 3 payee names per category. Add an env flag `INSIGHTS_INCLUDE_PAYEES=true|false` (default `true`). Setting it to `false` drops `topPayees` before sending.

## Phase 3: Mobile app

- `mobile_app/lib/data/api/insights_api.dart`: a thin wrapper over `ApiClient`, like `categories_api.dart`, with `getSummary(from, to)` and `generateInsights(from, to)`.
- Models for `SpendingSummary` / `SpendingInsights` (fromJson).
- Register the providers in `lib/data/providers.dart`, keyed on the active budget from `appConfigProvider`.
- `lib/features/insights/screens/insights_screen.dart`:
  - A range picker: this month, last 3 months, this year, or custom.
  - The summary section, which needs no AI: a per-category list with total, average, % over budget and a trend arrow.
  - A "Analyze with AI" button, hidden when `/config.insightsAvailable` is false, that shows the headline, overspending, trends, anomalies and suggestion cards.
  - Error handling on `code` (`AI_NOT_CONFIGURED`, `AI_PROVIDER_ERROR`), never on the message.
- Add the route in `lib/core/router.dart` and an entry point from the home/import screen.

## Phase 4 (optional, later)
- Cache the insights per `(budgetSyncId, from, to)` in the existing SQLite DB (`categorydb.ts` location), so repeated views don't cost AI calls.
- Add a monthly auto-summary on the first day of each month.
- Compare against the same period last year.

---

## Critical files
- New: `backend_app/src/insights.ts`, `backend_app/src/__tests__/insights.test.ts`, `mobile_app/lib/features/insights/…`, `mobile_app/lib/data/api/insights_api.dart`
- Modified: `backend_app/src/actual.ts`, `server.ts`, `errors.ts`, `parsers/ai-providers/{types,prompt,gemini-provider,anthropic-provider}.ts`, `.env.example`, `mobile_app/lib/data/providers.dart`, `lib/core/router.dart`

## Existing code to reuse
- `ensureInitialized` / queue pattern: `src/actual.ts`
- Payee/category name maps: the `learnCategoriesFromActual` pattern in `src/actual.ts`
- `resolveActualConfig`, `sendImporterError`: `src/server.ts`
- Structured JSON output: `GeminiProvider.runExtraction` in `gemini-provider.ts`
- Provider factory: `getAiProvider()` in `ai-providers/index.ts`

## Verification
1. `cd backend_app && npm run build && npm test`. The new `insights.test.ts` checks `buildSpendingSummary` against a hand-built fixture: totals, averages, over-budget %, trend, transfers/income excluded, and zero-spend categories dropped.
2. `npm run dev`, then `curl -H "X-Import-Token: …" "localhost:PORT/insights/summary?from=2026-01&to=2026-08"`. Compare a few category totals against Actual's own "Spending" report.
3. With `AI_PROVIDER=gemini` and a key set, run `curl -X POST /insights …`. The response should have valid `insights` JSON that references real categories. Log the outgoing request body once and confirm it contains only the summary.
4. With `GEMINI_API_KEY` unset, `POST /insights` should return `AI_NOT_CONFIGURED`, and `/insights/summary` should still work.
5. Mobile: run `flutter analyze`, then `flutter run`. Open Insights, change the range, run the AI analysis, and check that the button is hidden when `insightsAvailable` is false.
