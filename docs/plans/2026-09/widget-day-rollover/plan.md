# Plan — Widget day rollover

**Date**: 2026-09-11
**Status**: draft
**Research**: none — planned from
[issue #82](https://github.com/scastiel/kado/issues/82), whose analysis
was verified line by line against the code (see *Verified premises*).

## Summary

The Home Screen and Lock Screen widgets keep showing yesterday's ticks
and progress until the user logs a habit, because they render a
snapshot the app pre-computed for the day it was written on, and
nothing rebuilds that snapshot across the day boundary while the app is
asleep. The fix: the app already knows how to compute any day's state
(`WidgetSnapshotBuilder.build(asOf:)` is a pure function of the data
and a reference day), so it writes **today plus the next six days** —
each one "as of that morning, nothing further logged" — and the widget
hands WidgetKit **one timeline entry per day**, dated at that day's
rollover instant. WidgetKit flips the entry at the boundary in its own
render server, with neither process awake. The widget stays a pure
renderer; the custom "Day starts at" hour is honoured on both sides.

## Verified premises

Each claim in the issue, checked against `main` (32e79f9):

- `SnapshotTimelineProvider.getTimeline` and
  `PickedSnapshotProvider.timeline` each emit a single entry at `now`
  with `.after(now + 1h)`, on `Calendar.current`, and never consult
  `DayStartDefaults`. Confirmed.
- `KadoApp.advanceAtNextDayEdge` is a `Task.sleep` in-process. On
  foreground with a changed day, `.onChange(of: scenePhase)` bumps
  `clockMark`, which cancels that task (`Task.sleep` throws, the body
  returns before `WidgetReloader.reloadAll`) and restarts it for the
  *next* edge. No rebuild. Confirmed. The launch `.task` calls
  `rebuildAndWrite` without `reloadAllTimelines`, so a cold launch
  rewrites the file but leaves the widget on the old one for up to an
  hour.
- Every input to a day's state — `DefaultFrequencyEvaluator`,
  `DefaultHabitScoreCalculator`, `DefaultStreakCalculator`,
  `HabitRowState.resolve`, `OverviewMatrix.compute` — is driven by the
  `asOf:` / `on:` / `today:` argument. **No wall-clock reads** in any
  of them (grepped `.now` / `Date()`). So `build(asOf: tomorrow)` is
  well-defined and equals what the app itself would render tomorrow
  morning before anything is logged.
- The widget extension carries the App Group entitlement, so
  `DayStartDefaults.boundary()` resolves to the same hour in both
  processes. Confirmed (`KadoWidgetsExtension.entitlements`).
- Other readers of the snapshot file: `GetHabitStatsIntent` and
  `HabitEntity` (both read `.habits` only), plus the screenshot
  gallery, which calls `build` directly for one day and is unaffected.
- The day-start-hour compound already flagged this as "rollover-aware
  widget refresh", and `docs/ROADMAP.md` carries it under *To consider
  based on feedback*. That entry gets closed by this work.

## Decisions locked in

- **Pre-compute upcoming days app-side; the widget selects, never
  derives.** Three options were weighed:
  - *Reset stale rows in the widget* (clear ticks when the snapshot's
    day ≠ today) — cheap, but the *set* of due habits is still
    yesterday's: a `specificDays` habit due only today never appears,
    a `daysPerWeek` habit that met its quota yesterday keeps showing.
    Fails the issue's "today's due habits" expectation.
  - *Ship raw data and re-derive in the widget* — correct, but moves
    the calculators into the widget process, needs full history for
    scores, and breaks the "widgets never ask what day it is" rule
    the rest of the architecture leans on.
  - *Pre-compute N days in the app* ← chosen. Reuses `build(asOf:)`
    unchanged, exact for every frequency, zero new logic in the
    extension, and the switch is done by WidgetKit's timeline rather
    than by a reload iOS may throttle.
- **Horizon: 7 days** (today + 6). A user who doesn't open the app
  all week still sees the right due set each morning. Cost is 7×
  `build` per mutation — score and streak are O(history) per habit,
  so on the order of 10⁵ trivial ops for 20 habits with years of
  data; measured in Task 6 with the dev-mode seed before committing
  to the number.
- **A `logicalDay` on every `WidgetSnapshot`, and a
  `WidgetSnapshotSeries` as the on-disk shape.** The single-day
  `WidgetSnapshot` keeps its shape (views and previews untouched);
  the file becomes `{ generatedAt, days: [WidgetSnapshot] }`. A
  pre-upgrade file on disk (a bare `WidgetSnapshot` object) decodes
  as a one-day series whose `logicalDay` falls back to
  `matrixDays.last` — the same fallback `WidgetHabit` already uses
  for its stats fields.
- **Timeline planning is a pure, tested function** shared by both
  providers: `(series, now, boundary) → [(date, snapshot)] +
  reloadAfter`. Slot 0 is `now` with the current logical day's
  snapshot; each later slot sits at `boundary.nextRollover` of the
  previous one. The providers become one-liners over it.
- **Selection rule when the current day is not in the series**:
  greatest `logicalDay ≤ current day`, else the first, else `.empty`.
  Beyond the horizon that is the latest "nothing logged" state — it
  can still be wrong about the due set, but it can never show stale
  ticks.
- **Keep the hourly `.after` reload.** It remains the safety net for
  a write that wasn't paired with a `reloadAllTimelines` (none exist
  today, but the intents each call the pair by hand); the entries
  handle the boundary regardless of when the reload lands.
- **App side, belt and braces**: foregrounding on a new day calls
  `WidgetReloader.reloadAll` in addition to bumping `clockMark`.
  Three lines; covers beyond-horizon staleness and any data that
  landed while suspended.
- **No `BGAppRefreshTask`.** With the timeline entries the boundary
  switch no longer depends on the app running, so the task would only
  serve the beyond-horizon case and would cost a Background Modes
  capability plus an `Info.plist` identifier for a run iOS does not
  promise. Out of scope; revisit only if reports persist past the fix.

## Task list

### Task 1: Series and `logicalDay` — tests

**Goal**: Pin the on-disk shape and the day-selection rule before
touching the store.

**Changes**:
- New `KadoTests/WidgetSnapshotSeriesTests.swift`.

**Tests / verification**:
- A series round-trips through the store's encoder/decoder with
  `logicalDay` intact on every day.
- A pre-upgrade file — a bare `WidgetSnapshot` JSON object with no
  `logicalDay` and no `days` wrapper — decodes as a one-day series
  whose `logicalDay == matrixDays.last`. Build the fixture by
  encoding a current snapshot and deleting the key with
  `JSONSerialization`, per the "don't hand-type serialized strings"
  rule; a snapshot with empty `matrixDays` falls back to the calendar
  midnight of `generatedAt`.
- `snapshot(on:boundary:)` picks the greatest `logicalDay ≤` the
  current logical day; before the first day it returns the first;
  on an empty series it returns `.empty`. Under `startHour: 4`,
  02:00 on calendar day D1 resolves to D0's snapshot.
- Red at this point: the types don't exist.

**Commit message (suggested)**: `test(widgets): pin the snapshot series shape and day selection`

---

### Task 2: `WidgetSnapshot.logicalDay` + `WidgetSnapshotSeries` + store

**Goal**: The file carries a list of days; every reader still gets a
single-day snapshot.

**Changes**:
- `WidgetSnapshot.swift`: add `logicalDay: Date`; an `init(from:)`
  that falls back as Task 1 specifies; `init(...)` takes
  `logicalDay: Date? = nil` resolved in the body so `.empty`,
  `PreviewSnapshots`, and `DayProgressTests` keep compiling. New
  `WidgetSnapshotSeries: Codable, Sendable` (`generatedAt`,
  `days` ascending) with `snapshot(on:boundary:)`.
- `WidgetSnapshotStore.swift`: pure `encode(_:) -> Data` /
  `decode(_:) -> WidgetSnapshotSeries` statics (series first, legacy
  single-snapshot fallback) that the file IO calls; `write(_
  series:)`; `readSeries()`; `read()` becomes
  `readSeries().snapshot(on: .now, boundary: DayStartDefaults.boundary())`
  so `GetHabitStatsIntent` / `HabitEntity` are untouched.
- `WidgetSnapshotBuilder.build` sets `logicalDay` to the reference
  day; `rebuildAndWrite` writes a one-day series for now.
- Doc comment on `WidgetSnapshot` explains the day/series split.

**Tests / verification**:
- Task 1 green; `WidgetSnapshotBuilderTests` and
  `LogicalDaySurfacesTests` still green; `build_sim` clean.

**Commit message (suggested)**: `feat(widgets): store the snapshot as a series of logical days`

---

### Task 3: Timeline plan — tests

**Goal**: Spec the entries the providers hand WidgetKit, across day
starts and DST shapes, before writing the planner.

**Changes**:
- New `KadoTests/WidgetTimelinePlanTests.swift`, on `TestCalendar`
  fixtures.

**Tests / verification**:
- Series D0…D6, now = D0 10:00 (UTC, `startHour: 0`): seven slots;
  slot 0 at `now` with D0; slot *k* at D*k* midnight with D*k*.
- now = D2 09:00: slot 0 is D2 at `now`; D0 and D1 are dropped;
  D3…D6 follow.
- now = D9: a single slot, D6's snapshot — never D0's ticks.
- Empty series: a single `.empty` slot at `now`.
- `startHour: 4`, now = D1 02:00: slot 0 is D0; slot 1 at D1 04:00.
- **Invariant sweep**, per CLAUDE.md, over `utc`, `paris`, `havana`
  around each zone's transition windows: slot dates are strictly
  ascending, every slot after the first equals
  `boundary.nextRollover(after:)` of the previous slot's date, and
  `boundary.startOfDay(for: slot.date) == slot.snapshot.logicalDay`.
- `reloadAfter` is one calendar hour after `now`.

**Commit message (suggested)**: `test(widgets): spec the day-aware widget timeline`

---

### Task 4: `WidgetTimelinePlan` and the two providers

**Goal**: Both providers emit one entry per pre-computed day, dated at
the day's rollover, using the user's day-start hour.

**Changes**:
- New `Widgets/WidgetTimelinePlan.swift` (`nonisolated`, `Sendable`):
  `Slot { date, snapshot }`, `slots`, `reloadAfter`,
  `static func make(series:now:boundary:calendar:)`.
- `SnapshotTimelineProvider`: `getTimeline` maps the plan into
  `SnapshotEntry`s with `.after(plan.reloadAfter)`; `getSnapshot`
  uses `series.snapshot(on:boundary:)`. Boundary from
  `DayStartDefaults.boundary()`.
- `PickedSnapshotProvider`: same, carrying `habitID` into each entry.
- Header comments on both providers rewritten: the hourly reload is
  the safety net, the entries are the rollover.

**Tests / verification**:
- Task 3 green. `build_sim` for the `KadoWidgets` scheme as well as
  `Kado` — `@preconcurrency import WidgetKit` stays; the planner must
  not import WidgetKit so it is testable without an entry type.
- Widget previews (`#Preview … timeline:`) unchanged and rendering.

**Commit message (suggested)**: `feat(widgets): plan one timeline entry per logical day`

---

### Task 5: Series builder — tests

**Goal**: Pin what "tomorrow morning, nothing logged" means for each
habit shape before the builder writes it.

**Changes**:
- `KadoTests/WidgetSnapshotBuilderTests.swift` additions.

**Tests / verification**:
- `buildSeries(horizonDays: 7)` yields seven days with consecutive
  `logicalDay`s, each equal to that day's `matrixDays.last`.
- A binary habit completed today: `days[0].completedToday == 1`;
  `days[1]` has the row at `.none`, `progress == 0`,
  `valueToday == nil`, `completedToday == 0`.
- `daysPerWeek(1)` completed today: present in `days[0].today` (the
  "or logged" arm) and absent from `days[1].today`.
- `specificDays([tomorrow's weekday])`: absent from `days[0].today`,
  present in `days[1].today` — the property the reset approach could
  not deliver.
- Daily habit done yesterday and today: `days[1]` streak is 2; done
  yesterday only: `days[1]` streak is 0 — documents that a future day
  is "the truth that morning", not a copy of today.
- A negative habit is counted done on `days[1]` (until it slips),
  matching Today.

**Commit message (suggested)**: `test(widgets): spec the pre-computed upcoming days`

---

### Task 6: `buildSeries` + `rebuildAndWrite` writes the horizon

**Goal**: Every mutation writes seven days. **This is the commit that
closes #82.**

**Changes**:
- `WidgetSnapshotBuilder.buildSeries(from:asOf:calendar:horizonDays:…)`
  — `(0..<horizon).map { build(asOf: day + $0) }` through
  `calendar.date(byAdding: .day, …)`, never raw seconds.
- `rebuildAndWrite` calls it; `DayCompletionCelebration.observe`
  reads `days[0]` only — tomorrow's progress must never feed the
  confetti.
- Measure: in dev mode with the seeded dataset, time
  `rebuildAndWrite` before/after on a toggle. If it is visibly slow,
  hoist the `context.fetch` and `snapshot` mapping out of the per-day
  loop (the stats must stay per-day). Record the numbers in the
  compound.

**Tests / verification**:
- Task 5 green; full `test_sim` green.
- **Manual flip check on the simulator**: with the widget placed,
  set the Mac clock (System Settings → General → Date & Time, "set
  automatically" off) to 23:59, reload the widget, watch it switch
  to the fresh day at 00:00 with the app killed. Restore the clock.
  Repeat once with "Day starts at" = 04:00 and the clock at 03:59.
- Screenshot both widget families after the flip; the empty state
  and the "0 / N" copy must read correctly (this is the state the
  reporter sees every morning from now on).

**Commit message (suggested)**: `fix(widgets): pre-compute the upcoming days so the widget rolls over on its own`

---

### Task 7: Foreground on a new day reloads; ROADMAP

**Goal**: The app side of the issue, and the docs that pointed at it.

**Changes**:
- `KadoApp.onChange(of: scenePhase)`: when the day changed, bump
  `clockMark` **and** `WidgetReloader.reloadAll(using:)` (which
  already includes `RemindersSync.rescheduleAll`, so the existing
  call moves into the unchanged-day branch rather than running
  twice).
- `docs/ROADMAP.md`: drop the "Rollover-aware widget refresh" entry
  or mark it done with a pointer here.

**Tests / verification**:
- No unit seam for `scenePhase`; verify by hand: background the app
  with the clock before midnight, advance the clock, foreground —
  the widget updates within a second without logging anything.
- `test_sim` and `LocalizationCoverageTests` green (no new strings
  expected).

**Commit message (suggested)**: `fix(app): rebuild the widget snapshot when foregrounding on a new day`

---

### Task 8: Definition of done

**Goal**: Close out per CLAUDE.md before review.

**Tests / verification**:
- `build_sim` iPhone 17 Pro and iPad Air (M4), no new warnings — the
  planner and series are `nonisolated`; the Swift 6 isolation
  warnings from a `@MainActor`-defaulted type used in the extension
  are the likely trip-wire.
- `test_sim` green.
- Widget gallery still renders (`-uiTestWidgetGallery`) — it builds
  one day directly and wraps it in a `SnapshotEntry`, so nothing
  should change; confirm with one screenshot.
- Overnight on-device check before marking the PR ready: complete a
  habit in the evening, do not open the app, confirm the widget shows
  the new day in the morning. This is the reporter's exact scenario
  and the only end-to-end proof.

## Risks and mitigation

- **7× build cost on MainActor per mutation.** Measured in Task 6;
  fallback is hoisting the fetch, then lowering the horizon to 3.
- **Legacy file decode.** The first launch after the update reads a
  bare-snapshot file and immediately rewrites it as a series; the
  window is one launch. Pinned by Task 1's fixture test.
- **Time-zone travel between write and read.** `logicalDay` is an
  instant; after a zone change the widget's midnight differs from the
  stored one and the selection rule degrades to "greatest day ≤ now"
  until the next mutation. Acceptable; noted, not handled.
- **WidgetKit entry semantics.** Entries must be ascending and slot 0
  must not be in the future, or WidgetKit shows the placeholder until
  it is. The planner pins slot 0 to `now`; the sweep test guards
  ordering.
- **The `.active` race with the sleeping edge task** (the task can
  resume before or after `scenePhase` fires). With Task 7 both paths
  reload; a double reload is idempotent.

## Open questions

- [ ] Confirm the approach — pre-computed days + timeline entries —
  over shipping raw data to the widget.
- [ ] Confirm the 7-day horizon (vs. 2–3 days if the Task 6
  measurement is unkind).
- [ ] Confirm `BGAppRefreshTask` stays out of scope.
- [ ] Open a draft PR on `feature/widget-day-rollover` now?

## Out of scope

- `BGAppRefreshTask` (see *Decisions*).
- CloudKit changes that land while the app is suspended are not
  reflected in the widget until the next foreground — a separate,
  pre-existing gap; the Task 7 reload narrows it to "next foreground"
  rather than "next mutation".
- Re-deriving anything inside the widget process; iCloud-syncing the
  day-start hour (still on the ROADMAP).
