# Plan — Off-schedule completions & the two meanings of `isDue`

**Date**: 2026-08-10
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

`isDue` answers two different questions — "was this day part of the
schedule?" and "does this still need doing right now?" — and every caller
gets the second one. That single conflation makes the Overview grid hide
real completions ([#57](https://github.com/scastiel/kado/issues/57)),
freezes a perfect 5×/week user's habit score at 19%, and drops habits out
of the widget the moment they are completed. Split the protocol into
`isDue` (monotonic, schedule) and `isOutstanding` (actionable, reminders),
resolve grid cells from completions before the schedule, and collapse the
two private re-implementations of the frequency rules into the shared
evaluator.

## Decisions locked in

- **D2**: `isDue` excludes the evaluated day's own completions — logging a
  completion never rewrites whether the day was required.
- `isOutstanding` preserves the old inclusive semantics for reminders only,
  so notification behavior is unchanged.
- Both `.daysPerWeek` window counts require `value > 0`, so note-bearing
  zeroed records stop saturating the quota.
- **D1**: off-schedule completions render **hollow** (habit-color border,
  pale fill) in the Overview grid and the widget's weekly grid; the monthly
  calendar keeps its solid "completed" look.
- `DefaultStreakCalculator` keeps its `.daysPerWeek` week-bucket path; only
  the per-day path moves to the shared evaluator.
- Week-bucket scoring for `.daysPerWeek` (research alternative C) is
  deferred to its own PR.

## Task list

### Task 1: Pin the semantics with failing tests

**Goal**: Encode both bugs and the decided semantics as red tests before
touching any implementation.

**Changes**:
- `KadoTests/FrequencyEvaluatorTests.swift` — `isDue` exclusive-window
  cases, `isOutstanding` inclusive-window cases, `value > 0` filtering
- `KadoTests/OverviewMatrixTests.swift` — completion on a non-due day
- `KadoTests/HabitScoreCalculatorTests.swift` — perfect `.daysPerWeek` user
  scores comparably to a perfect daily user
- delete `KadoTests/TempIssue57Characterization.swift`

**Tests / verification**: `test_sim` — new tests fail, everything else passes.

**Commit message (suggested)**: `test(frequency): pin isDue/isOutstanding semantics for daysPerWeek`

---

### Task 2: Split `FrequencyEvaluating`

**Goal**: Two named questions, one implementation.

**Changes**:
- `Services/FrequencyEvaluating.swift` — add `isOutstanding`, document both
- `Services/DefaultFrequencyEvaluator.swift` — shared lifecycle guard,
  exclusive vs inclusive trailing window, `value > 0` filter

**Tests / verification**: Task 1's evaluator + score tests go green.
`DefaultFrequencyEvaluator` is the only conformance, so no mocks to update.

**Commit message (suggested)**: `fix(frequency): make isDue monotonic, add isOutstanding for reminders`

---

### Task 3: Resolve grid cells from completions first

**Goal**: A day with a completion never renders as "not scheduled".

**Changes**:
- `Services/OverviewMatrix.swift` — `DayCell.offSchedule(Double)`, new
  resolution order
- `Widgets/WidgetSnapshot.swift` — matching `WidgetDayCell.offSchedule`
- `Widgets/WidgetSnapshotBuilder.swift` — `mapDayCell`; Today rows use
  `isDue || logged today`

**Tests / verification**: Task 1's matrix test goes green; add a widget
snapshot test for the completed-today-but-saturated row.

**Commit message (suggested)**: `fix(overview): render off-schedule completions instead of hiding them`

---

### Task 4: Render the hollow off-schedule cell

**Goal**: The grid still communicates the schedule.

**Changes**:
- `Views/MatrixCell.swift` — hollow rendering + preview coverage
- `KadoWidgets/WeeklyGridLargeWidget.swift` — same treatment
- `Views/Overview/OverviewView.swift` — a11y label "completed, off schedule"
- `Views/Overview/CellPopoverContent.swift` — popover status line
- `Resources/Localizable.xcstrings` — EN + FR for the new strings

**Tests / verification**: previews (light + dark); `screenshot` before/after;
`LocalizationCoverageTests`.

**Commit message (suggested)**: `feat(overview): hollow cell treatment for off-schedule completions`

---

### Task 5: One source of truth for the schedule rules

**Goal**: Remove the duplication that let the surfaces drift.

**Changes**:
- `UIComponents/MonthlyCalendarView.swift` — delete `dayIsDue`, inject
  `@Environment(\.frequencyEvaluator)`
- `Services/DefaultStreakCalculator.swift` — delete `isDueByDay`, take an
  injected evaluator on the per-day path

**Tests / verification**: `StreakCalculatorTests` is the gate — expected to
be a no-op. Revert this task's streak half if any assertion moves.

**Commit message (suggested)**: `refactor(frequency): route calendar and streaks through the shared evaluator`

---

### Task 6: Point reminders at `isOutstanding`

**Goal**: Keep notification behavior identical under the new semantics.

**Changes**:
- `Services/Notifications/DefaultNotificationScheduler.swift`

**Tests / verification**: `DefaultNotificationSchedulerTests.daysPerWeekSaturated`
passes unchanged.

**Commit message (suggested)**: `fix(notifications): schedule from isOutstanding, not isDue`

---

### Task 7: Verify and ship

**Goal**: Meet the definition of done.

**Changes**: none (verification only).

**Tests / verification**:
- full `test_sim`, `build_sim` on iPhone 17 Pro **and** iPad
- `screenshot` of the Overview before/after with seeded off-schedule data
- Dynamic Type XXXL + dark mode previews
- PR with the four-section description, D1/D2 flagged for review

**Commit message (suggested)**: `docs(plans): compound off-schedule completions work`

## Risks and mitigation

| Risk | Mitigation |
|---|---|
| Streak behavior shifts when moving to the shared evaluator | `StreakCalculatorTests` gates it; revert that half and keep `isDueByDay` if anything moves |
| `WidgetDayCell` is `Codable` into the App Group JSON | Case is additive; app + widget ship together, so no version skew |
| New EN strings ship without FR | `LocalizationCoverageTests` fails the build; hand-author both |
| Hollow cell is illegible at widget size | Check the widget preview at `systemLarge`; fall back to a thicker border |

## Open questions

- [ ] D1 and D2 are implemented as decided and flagged in the PR for review.
- [ ] Week-bucket scoring for `.daysPerWeek` — separate PR.

## Out of scope

- Reshaping the EMA for flexible frequencies (research alternative C).
- The "2-day shortfall costs 4 missed days" over-penalty — pre-existing,
  falls out of the rolling-quota model, noted as follow-up.
- Suppressing same-day reminders for already-completed habits of *any*
  frequency. Real, but unrelated to #57 and a behavior change of its own.
