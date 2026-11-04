# Plan: a prettier Settings tab

Branch `feature/settings-polish`, worktree `../actual-pdf-importer-settings`, cut from
`feature/dart-parser` at `f85bb1d`. Written 2026-11-03 with the `web-design-engineer` and
`emil-design-eng` skills.

Merge order: logging → core-app → dart-parser → backups → **settings-polish**. Rebase onto
`feature/backups` before Phase 2, since backups adds a "Backups" entry to Settings.

## What's wrong today (audit of `settings_screen.dart`)

| Today | Problem |
| --- | --- |
| One long `ListView` with 7 sections, each a `titleLarge` title and 40px gaps | Every section weighs the same; it reads like a form, not settings. Hard to scan. |
| The backend form (address, token, "Save and test") always open at the top | The thing you set once takes the most room, every time you open the tab. |
| Actual server card (filled `surfaceContainer`) next to a bordered budget list | Two card styles side by side. |
| Navigation as a `Wrap` of 52px `OutlinedButton`s ("Open category memory", "Edit categories", …) | Heavy buttons for plain navigation. They wrap unevenly, and "Match with Actual" appears and disappears in the middle of the row. |
| `SwitchListTile` with zero padding, then a separate outlined button | Mixed patterns in one section. |
| "Forget statement passwords" does it right away, with the same weight as everything else | A destructive action with no confirmation and no visual cue. |
| No overview | You can't see at a glance whether the backend, Actual and the budget are all fine. |

## Design read

```yaml
Design Read:
  artifact: mobile settings screen (Flutter, Material 3), plus 2 sub-screens and 1 sheet
  audience: one self-hoster managing their own budget, opening Settings a few times a week
  visual-language: quiet grouped list, iOS/Android-system-settings style, on the app's zinc neutrals with Actual's purple as the only accent
  mode: redesign · preserve (tokens, routes, copy tone, connection_controller logic stay)
  visual-variance: 3     # it's settings: familiar beats novel
  motion-intensity: 3    # feedback and state changes only; no entrance choreography
  information-density: 6 # many rows, short labels, values on the right
  asset-dependence: 1    # icons only (Material Symbols rounded, already used)
  brand-fidelity: 8      # keep Geist, the zinc ramp, the one-accent rule, Radii, Space
```

Four positioning questions:

- **Narrative role**: a control panel. Status first, then the things you change.
- **Viewing distance**: a phone at ~30 cm, one hand, thumb-reachable rows.
- **Temperature**: calm and trustworthy. It handles money credentials.
- **Capacity**: the overview card (3 rows) plus 4 small groups fit in about 1.5 screens, against
  about 4 screens today.

## Design decisions (to confirm before any code)

- **Anchor**: system settings (Android 15 / iOS grouped lists), no new style recipe. The app's
  tokens already define the look.
- **Color**: unchanged tokens. Rows sit on `surfaceContainerLowest` with a 1px `outlineVariant`
  border, on `surface`. The accent is used only for status "ok" and the selected budget.
  Destructive rows use `error`. No new hues.
- **Status dots**: `primary` = connected, `onSurfaceVariant` = not set up, `error` = failing. The
  dot always has a text label next to it, so meaning never depends on color alone.
- **Typography**: Geist. Group labels `labelLarge` in `onSurfaceVariant`, sentence case, not
  uppercase. Row titles `bodyLarge` w500, values and subtitles `bodyMedium` muted. Addresses
  and versions in `figures()` (Geist Mono).
- **Spacing**: `Space` (4pt grid). Rows at least 56px tall (64 with a subtitle) and 48dp touch
  targets. 24px between groups, 8px from a group label to its group, 20px gutter.
- **Radius**: groups use `Radii.control` (12). The budget sheet uses `Radii.sheet`. Nothing new.
- **Shadows**: none, as everywhere else in the app. Borders and surfaces give the depth.
- **Motion** (Emil's framework; Settings is opened often, so motion means feedback, never
  decoration):

  | Element | Animate? | How |
  | --- | --- | --- |
  | Opening the tab | No | No stagger or fade-in: it's seen tens of times. |
  | Row press | Yes, feedback | The existing InkSparkle plus a 0.98 scale on the row content, 120ms, `Cubic(0.23, 1, 0.32, 1)` (strong ease-out). |
  | Status change (testing → connected) | Yes, state | Dot color crossfades 180ms ease-out. The label swaps with `AnimatedSwitcher` (fade, plus 4px slide up). |
  | Budget picker | Yes, spatial | Bottom sheet with the drawer curve `Cubic(0.32, 0.72, 0, 1)`, about 300ms in and 200ms out (exit faster than enter). |
  | Switch toggle | Native | Material switch plus `HapticFeedback.selectionClick()`. |
  | Inline error under a form | Yes | Keep the existing `AnimatedSize` 200ms; swap its `easeOutCubic` for the strong ease-out. |
  | Reduced motion | — | `MediaQuery.disableAnimationsOf`: no scale and no slide; fades of 120ms or less stay. |

  The curves and durations go in `app_theme.dart` as a `Motion` token class, so other screens
  can use them later. Nothing animates from scale 0, and nothing uses ease-in.

## New layout

```
Settings
┌──────────────────────────────────────────┐
│ ● Backend      Connected · 192.168.1.10 › │   → /settings/backend
│ ● Actual       Connected · v26.10       › │   → /settings/actual
│ ● Budget       My Budget               › │   → budget sheet
└──────────────────────────────────────────┘
Categories
┌──────────────────────────────────────────┐
│ Category memory                     128 › │
│ Categories                              › │
│ Match with Actual               3 to do › │   (only when Actual is ready)
└──────────────────────────────────────────┘
Backups                                        (from feature/backups)
┌──────────────────────────────────────────┐
│ Backups         Daily · last 03:00 today › │
└──────────────────────────────────────────┘
Privacy
┌──────────────────────────────────────────┐
│ Read statements on this phone        [on] │
│   Statements stay on the phone…           │
│ Forget statement passwords                │   (error color, confirm dialog)
└──────────────────────────────────────────┘
Help
┌──────────────────────────────────────────┐
│ Logs and diagnostics                    › │
│ Run setup again                         › │
└──────────────────────────────────────────┘
        Actual PDF Importer 1.0.0 (1)
```

- **Backend sub-screen** (`/settings/backend`): today's `ConnectionFields`, "Save and test" and
  the result note, alone on a full page. "Save and test" is pinned to the bottom safe area, as on
  Review.
- **Actual sub-screen** (`/settings/actual`): today's `ActualServerCard`, unchanged, plus a short
  explanation. Without a backend it shows "Connect the backend first" with a button to the
  Backend screen.
- **Budget sheet**: `BudgetList` in a bottom sheet, with a "Reload" icon. It loads the budgets
  when it opens. Choosing one closes the sheet and shows the existing snackbar. Without Actual,
  the Budget row is disabled, with its subtitle saying why.
- **Overview row values** come from `connectionControllerProvider` / `appConfigProvider` /
  `linkStateProvider`. The tab still runs its silent `test()` on open, as today, so the dots
  show the real state.
- The dev page stays on a long-press of the title (debug builds only).
- `SetupScreen` keeps using `ConnectionFields` / `ActualServerCard` / `BudgetList`; they move but
  don't change.

## Phases

### Phase 0: v0 mockup (`web-design-engineer` checkpoint)

An HTML mockup at phone width (390×844), in light and dark, using the exact tokens above (Geist
from Google Fonts, the zinc hex values from `app_theme.dart`). It shows the overview, both
sub-screens and the budget sheet, with clickable rows, the press feedback and the sheet motion.
It's published as a private artifact for you to review. **Stop for your OK on the direction
before any Flutter code.**

### Phase 1: tokens and shared widgets

- `Motion` in `app_theme.dart`: `press` 120ms, `small` 180ms, `sheetIn` 300ms, `sheetOut`
  200ms, curves `easeOut` / `easeInOut` / `drawer`. Plus a helper that returns `Duration.zero`
  under reduced motion.
- `lib/shared/widgets/settings_group.dart`:
  - `SettingsGroup(label, children)`: the bordered group, with dividers inset to the text;
  - `SettingsRow(icon?, title, subtitle?, value?, trailing, onTap, destructive)`, which has the
    press scale and a `Semantics` button role whose label includes the value;
  - `SettingsSwitchRow`;
  - `StatusDot(status, label)`.
- Widget tests: row tap, disabled row, `SettingsSwitchRow` toggles, the status label is
  announced, no scale under reduced motion.

### Phase 2: Settings overview and sub-screens

- Rebase onto `feature/backups` first.
- Rewrite `settings_screen.dart` as the grouped overview.
- New `backend_settings_screen.dart`, `actual_settings_screen.dart` and the budget sheet. New
  routes `settings/backend` and `settings/actual` under `/settings` (root navigator, like the
  others).
- "Forget statement passwords" gets a confirmation dialog.
- "Match with Actual" shows the count from `pendingCategoryMatchesProvider`. "Category memory"
  shows the number of mappings when it's cheap to get (the local store; backend list length
  when Actual is ready). Otherwise no value.
- `connection_controller.dart` is not changed.
- Tests:
  - the overview in each link state (`noBackend`, `noActual`, `noBudget`, `ready`);
  - each row navigates to its route;
  - the budget sheet selects;
  - the forget confirmation;
  - existing tests stay green.

### Phase 3: polish pass (`emil-design-eng` review)

- Go over every new widget with Emil's checklist. The findings go into the PR as a
  Before / After / Why table.
- Check with 200% text scale, TalkBack labels, dark mode, a 320dp-wide screen (no overflow),
  and reduced motion.
- Look at the press and sheet motion in slow motion (`timeDilation = 5` in a debug toggle on
  `/dev`), and again the next day on the phone.
- Format only the files this branch creates or rewrites, by path (no bulk `dart format`).

### Phase 4: verification

- `flutter analyze` (no new issues) and `flutter test`.
- Run it on your Android phone: all four link states, light and dark.
- A five-dimension critique score (philosophy, hierarchy, craft, function, originality) in the
  PR description.

## Not in this plan

- Restyling other tabs. The new `SettingsGroup` / `SettingsRow` / `Motion` can be reused there
  later.
- New settings. Backups content is in `feature/backups`. This branch only gives it a row.
- Changing the setup guide.

## As built (Phases 0–2, 2026-11-04)

- **Phase 0**: mockup approved (private artifact "Settings redesign v0"). One change from the
  decisions above: in dark mode the groups sit on `surfaceContainerLow`, since
  `surfaceContainerLowest` is darker than the background and looked sunk in
  (`settingsGroupColor`).
- **Phase 1**: `Motion` in `app_theme.dart` (`press`, `small`, `sheetIn`/`sheetOut`, `easeOut`,
  `easeInOut`, `drawer`, `pressScale`, `Motion.of`, `Motion.sheet`).
  `lib/shared/widgets/settings_group.dart`: `SettingsGroup`, `SettingsRow` (with `enabled`,
  `destructive`), `SettingsSwitchRow` (haptic tick), `StatusDot` (`SettingsStatus` ok / off
  (hollow) / failing / busy).
- **Phase 2**: the overview, `BackendSettingsScreen` (`/settings/backend`),
  `ActualSettingsScreen` (`/settings/actual`), `showBudgetSheet` (drawer curve, loads on open).
  "Forget statement passwords" asks first.
  - The Backups group has no label: its one row already says "Backups".
  - "Category memory" shows no count yet: there's no cheap source that works both with and
    without Actual. A later change can add one.
  - The status logic is in `backendStatus` / `actualStatus` in `settings_screen.dart`.
- Tests: `test/settings_test.dart` (10). App total: 119 pass, 1 skipped.
- Left for Phase 3/4: Emil's review table, 200% text, TalkBack, 320dp width, slow motion and the
  phone check.

### Phase 3 (done in code; the by-eye part is on the phone)

Review of the new widgets against Emil's checklist:

| Before | After | Why |
| --- | --- | --- |
| Settings buttons with Material's default press only | `SettingsRow` content scales to 0.98 over 120ms with `Motion.easeOut`; ink stays full-size | Feedback that the row heard the tap, without moving the hit area |
| Sheets with Material's default curve and timing | Budget sheet: `Motion.drawer`, 300ms in and 200ms out | Exit faster than entry; the drawer curve feels native |
| Status shown as text only, swapped instantly | `StatusDot`: color crossfade 180ms; label fades with a ~4px rise; "off" is hollow | It's a state change, so it animates; meaning never depends on color alone |
| `AnimatedSize` with `Curves.easeOutCubic` 200ms | `Motion.small` with `Motion.easeOut`, zero under reduced motion | One curve and duration set across the app |
| No entrance animation | Still none | The tab is opened many times a day |
| Reduced motion only partly respected | No scale, no slide, sheet without animation; short fades kept | Movement is what reduced motion asks to stop |

Checks:
- 320dp width at 200% text, in light and dark, across the overview, both sub-screens and the
  sheet: no overflow (a test in `settings_test.dart`).
- The status is read out as words with the row's title (a semantics test).
- `/dev` has a "Slow motion (5×)" switch (`timeDilation`) for looking at the press and the
  sheet on the phone.
