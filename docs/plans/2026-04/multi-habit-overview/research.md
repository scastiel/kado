# Research — Multi-habit overview

**Date**: 2026-04-17
**Status**: draft
**Related**:
- `docs/ROADMAP.md` → v0.2 "Multi-habit overview" section (added this
  branch)
- `docs/habit-score.md` (EMA scoring that will drive cell tints)
- `docs/PRODUCT.md` (Kadō's "score is central" DNA)

## Problem

Kadō's v0.1 surfaces are **Today** (only today's habits) and per-habit
**Detail** (one habit at a time, with monthly calendar + score).
Neither lets the user see progress across all their habits at once
over time.

Competitor survey (see References) shows the pattern is common but not
universal:
- **Loop** and **Way of Life** build their main screen around a
  habits × days matrix.
- **HabitKit** stacks per-habit heatmaps on the home screen.
- Polished iOS-natives (**Streaks**, **Habitify**, **Productive**)
  push cross-habit history to a dedicated **Stats** tab.

Kadō's differentiator is the EMA-based habit score. A cross-habit view
that surfaces the **score** — not just binary done/not-done — turns
an abstract number into a lived visualization and keeps the score
central to the app rather than buried in Detail.

### What "done" looks like

The user opens a new **Overview** tab and sees every non-archived
habit as a row, with recent days as columns. Each cell is tinted by
that habit's EMA score on that day. Tapping a cell jumps to the
habit's Detail. Works on iPhone and iPad, light and dark, Dynamic
Type XXXL, VoiceOver.

## Current state of the codebase

### Navigation
- `ContentView` (Kado/App/ContentView.swift:9–19): TabView with two
  tabs, Today + Settings. Adding a third tab is a one-line change.
- `modelContainer` injection via `DevModeController` at
  `KadoApp.swift:16`. No special treatment needed for a new tab.

### Data
- `HabitRecord` (SwiftData `@Model`) → `.snapshot` produces value-type
  `Habit`. `TodayView` (Kado/Views/Today/TodayView.swift:11–15)
  already queries non-archived habits sorted by `createdAt` — same
  descriptor fits Overview.
- `CompletionRecord` → value-type `Completion(habitID, date, value)`.
  Lives on the habit relationship.
- **`Habit` has no color or icon field today.** The v0.1 ROADMAP
  scopes them, but they're unshipped. Matrix rows need visual
  identity — either land color/icon first, or ship v1 with
  app-accent-only rows. See Open questions.

### Services (the good news)
- `HabitScoreCalculating.scoreHistory(for:completions:from:to:)`
  already returns `[DailyScore]` — one score per day, carrying
  forward on non-due days. **Exact primitive the matrix needs. No
  new business logic required.**
- `FrequencyEvaluating.isDue(habit:on:completions:)` exists —
  distinguishes "not due" from "due-but-missed" cells.
- Env injection via hand-rolled `EnvironmentKey` pattern
  (`App/EnvironmentValues+Services.swift`); newer entries use
  `@Entry`. New services follow the existing pattern.

### Existing UI primitives
- `MonthlyCalendarView` (UIComponents/MonthlyCalendarView.swift, 241
  lines) has a per-day cell state enum
  `.future | .completed | .missed | .nonDue` and a secondary/tertiary
  fill system. Close cousin to what we need, but cells are
  month-anchored with day numbers; generalizing for a no-label,
  score-tinted day cell is plausible but more refactor than reuse.
- No existing `score → color` mapping function; would be new.

### Tests
- Swift Testing (`@Suite`, `@Test`). `TestCalendar` helper in
  `KadoTests/Helpers/` pins to UTC Gregorian, reference date
  2026-04-13 (a Monday).

### Dev mode
- `DevModeSeed` (Services/DevModeSeed.swift): 5 habits, ~7 completions
  each over 14–60 days. Adequate for initial preview; may want to
  enrich once the view lands.

## Proposed approach

**Add an "Overview" tab** between Today and Settings. It renders a
scrollable matrix of non-archived habits (rows) × recent days
(columns). Each cell is a score-tinted square computed from
`scoreHistory`. Tapping a cell navigates to that habit's Detail.

### Resolved design decisions
- **Cell encoding: gradient tint.** `score ∈ [0, 1]` maps to opacity
  over the habit's accent color. Non-due days render as empty/faint
  placeholders; future days are empty. Surfaces Kadō's score DNA
  directly; accepts the trade-off that a dense gradient is harder to
  parse at a glance than discrete states.
- **Scope: bundle `Habit.color` + `Habit.icon` with the matrix.** A
  uniform-accent matrix is monotonous; per-habit color is load-bearing
  for the visual. One cohesive PR covers the schema change, form
  updates, and the matrix itself.

### Key components

**Schema (prerequisite, same branch):**
- `Habit.color: HabitColor` + `Habit.icon: String` (SF Symbol name).
  Extend `KadoSchemaV1` → `KadoSchemaV2`, append
  `.lightweight(KadoSchemaV2.self)` stage to `KadoMigrationPlan`.
- `HabitColor` enum (curated palette, ~8–10 semantic named colors
  that adapt to dark mode — not raw hex).
- New/Edit Habit forms: color swatch picker + SF Symbol icon picker.
- `HabitRowView` and `MonthlyCalendarView` updated to respect the
  new color.

**Overview matrix:**
- `OverviewView` (`Kado/Views/Overview/OverviewView.swift`) —
  `@Query` for habits; hosts the matrix UI.
- `OverviewMatrix` (free struct, `Kado/Services/OverviewMatrix.swift`)
  — pure function: `(habits, completions, dayRange, calendar) →
  [MatrixRow]` where `MatrixRow = (habit, [DayCell])` and `DayCell`
  is `.future | .notDue | .scored(Double)`. Uses
  `HabitScoreCalculating` + `FrequencyEvaluating`. **Tested in
  isolation.**
- `MatrixCell` (UIComponent) — one tinted square. Takes a `DayCell`
  + habit color. `.scored(s)` renders the habit color at opacity
  `s` (with a small floor so low-score cells stay perceptible).
  Accessibility label composed per cell.
- `DayColumnHeader` — weekday abbreviation + day number, respecting
  `Weekday.localizedShort` pattern.

### Layout sketch

```
┌──────────────────────────────────────────────────┐
│  Overview                                        │
├──────────────┬───────────────────────────────────┤
│ 📖 Read      │   M   T   W   T   F   S   S   M  │
│ 🏃 Exercise  │  ▓▓  ▓▓▓  ·  ▓▓▓ ▓▓▓ ▓▓▓  ·  ▓▓▓ │  ← scrolls to past
│ 💧 Water     │  ▓▓  ▓▓▓ ▓▓  ▓▓▓  ·  ▓▓▓  ·  ▓▓▓ │
│ 🧘 Meditate  │   ·   ·  ▓▓   ·   ·  ▓▓▓  ·  ▓▓▓ │
└──────────────┴───────────────────────────────────┘
     sticky                 scrollable →
```

Sticky left column (icon + name). Horizontally scrollable right
region (day columns). Newest-on-right, initial scroll position
anchored at today (Loop/Way of Life convention).

### Data model changes

- New fields on `HabitRecord`: `color: HabitColor` (default a neutral
  case, e.g. `.blue`), `icon: String` (default a neutral SF Symbol,
  e.g. `"circle"`). Both non-optional with defaults for CloudKit
  shape compliance.
- `KadoSchemaV2` adds these two fields; `KadoMigrationPlan` gets a
  lightweight stage. Existing habits inherit the defaults; the
  Edit Habit form lets the user set real values post-migration.
- Value-type `Habit` snapshot mirrors the new fields.
- Regression test: walk `Schema.entities` to confirm the new
  properties remain optional-or-defaulted and non-unique
  (CloudKit shape invariant — see `CloudKitShapeTests.swift`).

### UI changes

- New tab in `ContentView` → `OverviewView`.
- New view file + a small handful of UIComponents.
- Localization entries for "Overview" tab label, accessibility cell
  labels, state descriptors.

### Tests to write

**Schema / migration:**
- `@Test("KadoSchemaV2 migrates V1 habits with default color + icon")`
- CloudKit shape regression test covers the new fields.

**`OverviewMatrix` (free struct):**
- `@Test("Matrix emits one row per non-archived habit, sorted by createdAt")`
- `@Test("Archived habits are excluded")`
- `@Test("Cell is .future for dates beyond today")`
- `@Test("Cell is .notDue when FrequencyEvaluator says not due")`
- `@Test("Cell is .scored(s) where s matches scoreHistory on due days")`
- `@Test("Empty habit list yields empty matrix")`

**Color helper:**
- `@Test("Score 0 maps to transparent, score 1 maps to full habit color")`
- `@Test("Score-0 cells respect a minimum opacity floor for perceptibility")`

View-level previews cover the visual axes (single habit, many
habits, iPad width, dark mode, Dynamic Type XXXL), plus one preview
showing the full color palette.

## Alternatives considered

### Alternative A: segmented control on Today (Today / Overview toggle)
- **Idea**: avoid a third tab; stay with the two-tab shell.
- **Why not**: Overview is not "today's data in a different shape"
  — it's cross-time, cross-habit. Conflating the two surfaces
  obscures Today's role. Adding a tab matches Streaks, Habitify,
  HabitKit and iOS users' mental model.

### Alternative B: stacked per-habit heatmaps (HabitKit-style)
- **Idea**: vertical list where each row is a full
  GitHub-contribution grid for one habit.
- **Why not**: doesn't support the cross-habit comparison the user
  asked about — you can't easily see "did I hit everything on
  Tuesday?" across habits. The matrix pattern answers that
  directly.

### Alternative C: aggregate stats dashboard (Streaks-style)
- **Idea**: charts like "perfect days this month", "average score
  across all habits", streak leaderboard.
- **Why not**: valuable but distinct. A future Stats tab can layer
  on top of the matrix later; matrix is the foundation.

## Risks and unknowns

- **Scroll performance** with many habits × wide day ranges: use
  `LazyHStack`/`LazyHGrid` so cells materialize on demand. 50 habits
  × 365 days eagerly is 18k views — unacceptable; 50 × 30 is fine.
- **Score computation cost**: `scoreHistory` walks day-by-day. 50
  habits × 30 days = 1,500 evaluations. Cheap, but memoize per view
  render; don't recompute on every scroll offset change.
- **Scope growth from bundling**: one PR now covers a schema
  migration, form updates, and a new top-level tab. Higher review
  load; mitigate by landing as a single branch with clearly
  separated commits (schema → forms → matrix) so it's still
  reviewable in sequence.
- **Migration rollback**: v0.1 is still pre-release, so CloudKit
  data loss on schema change is a non-issue. Verify locally on a
  real device before merging anyway.
- **iPad vs iPhone**: iPad easily fits 20+ day columns, iPhone ~7-10.
  Lazy grid handles most of this; may want slightly larger cells
  on iPad.
- **Score-tint semantics at glance**: a dense gradient can be harder
  to read than discrete states. Needs a visual test against users.

## Open questions

Resolved (2026-04-17):
- [x] **Score encoding**: gradient tint.
- [x] **Habit color prerequisite**: bundle `Habit.color` +
      `Habit.icon` in the same PR as the matrix.

Carried forward to plan stage:
- [ ] **Default day window**: ~30 days (fills iPhone screen with
      scroll), or ~7 days (simpler, current-week focus), or auto-fit
      to available width?
- [ ] **Tap behavior**: navigate to habit Detail (at that date), or
      show an inline popover with the completion, or read-only?
- [ ] **Day order**: newest-on-right scrolling into past (Loop
      convention), or newest-on-left like a feed?
- [ ] **Color palette shape**: how many colors, and what's the naming
      convention? (e.g. `.blue | .mint | .red | ...` à la Apple
      Reminders, or something more distinctive?)
- [ ] **Icon picker**: SF Symbol search via Apple's built-in picker
      (iOS 18 has no public API for this — custom grid needed), or
      a curated shortlist of ~30 common habit icons?

## References

- Competitor landscape:
  [Loop](https://loophabits.org/) · [Way of Life](https://wayoflifeapp.com/)
  · [HabitKit](https://www.habitkit.app/) ·
  [Sweet Setup review](https://thesweetsetup.com/apps/best-habit-tracking-app-ios/)
- Kadō ROADMAP v0.2 entry: `docs/ROADMAP.md`
- Kadō habit score spec: `docs/habit-score.md`
