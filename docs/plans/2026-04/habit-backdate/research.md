# Research — Habit Backdate

**Date**: 2026-04-29
**Status**: ready for plan
**Related**: [Issue #42](https://github.com/scastiel/kado/issues/42)

## Problem

When a user creates a habit, they often want to log completions for
the past few days ("I started running on Monday but only installed
the app today, Wednesday"). Currently `createdAt` is set to `.now`
on creation and acts as a hard boundary — score, streak, frequency,
calendar, and overview matrix all refuse to acknowledge days before
it. The user's Monday and Tuesday runs are impossible to record.

A related frustration: if a user creates a habit on Monday but
doesn't complete it until Wednesday, the two missed Mon/Tue days
drag the score down. The issue author suggests the score should
start at the first completion, not at creation.

## Current state of the codebase

### `createdAt` is a hard boundary in 6 places

| Component | File | How it uses `createdAt` |
|---|---|---|
| `DefaultFrequencyEvaluator` | `DefaultFrequencyEvaluator.swift:13` | `guard day >= createdDay else { return false }` — days before creation are never due |
| `DefaultHabitScoreCalculator` | `DefaultHabitScoreCalculator.swift:39` | `let firstDay = max(startDate, createdDay)` — score history starts at creation |
| `DefaultStreakCalculator` | `DefaultStreakCalculator.swift:13,51,82` | Streak loops stop/start at `createdDay` |
| `OverviewMatrix` | `OverviewMatrix.swift:71` | `if day < habitCreatedStart { return .notDue }` |
| `MonthlyCalendarView` | `MonthlyCalendarView.swift:176` | `isDueByDay` for `everyNDays` uses `createdDay` as cycle anchor |
| `DefaultFrequencyEvaluator` | `DefaultFrequencyEvaluator.swift:30` | `everyNDays` modular arithmetic anchored to `createdDay` |

### `createdAt` is immutable after creation

- `NewHabitFormModel.save()` never touches `createdAt` on the edit
  path (`HabitDetailView.swift:173-180`).
- No UI exists to modify it.
- Defaults to `.now` on creation (`HabitRecord.swift:35`).

### No guard in the UI against pre-creation edits

- `DayEditPopover` accepts any date — no validation against
  `createdAt`.
- `CompletionToggler` and `CompletionLogger` accept any date.
- The calendar lets you navigate to pre-creation months; cells just
  show as `.nonDue` or `.missed`.

So the persistence layer already handles pre-creation completions —
only the calculators and display logic block them.

## Proposed approach

**Introduce an "effective start date" computed as
`min(createdAt, earliestCompletionDate)`.** When the first completion
is after `createdAt`, use that instead (addressing the "grace period"
ask). When a completion is backdated before `createdAt`, the
effective start shifts back automatically.

This is a pure computation — no schema change, no migration, no new
stored field. The effective start is derived from existing data.

### Key components

- **`Habit.effectiveStart(given:calendar:)` method**: computes the
  effective start from the habit's `createdAt` and its completions.
  If there are completions, returns `min(createdAt, earliestDate)`.
  If no completions, returns `createdAt`. For the "score starts at
  first completion" behavior: returns `firstCompletionDate` when it's
  after `createdAt`. This means an empty habit has no due days until
  the first completion — which matches the user's expectation
  ("I haven't started yet").

  Actually, this needs careful thought. Two sub-behaviors:

  **Option 1 — Effective start = min(createdAt, firstCompletion)**:
  - Backdated completions shift the window back. Good.
  - But a habit with no completions still starts at `createdAt`,
    meaning missed days accumulate. The issue author's complaint
    about "score starts at first completion" isn't fully addressed.

  **Option 2 — Effective start = firstCompletionDate (or createdAt
  if none)**:
  - Score/streak only start once you first do the habit. No penalty
    for creating it early.
  - Backdated completions automatically anchor the start.
  - A habit with zero completions has `effectiveStart = createdAt`,
    but since there are no completions the score is 0 anyway —
    harmless.
  - Risk: for negative habits, "no completions = success." Moving
    the start to the first completion would erase the early
    successful days. Need to handle negative habits separately
    (keep `createdAt` as start for negative habits).

  **Recommendation: Option 2** — it matches the issue request most
  closely. Negative habits use `createdAt` as before.

- **`DefaultFrequencyEvaluator`**: replace `createdDay` guard with
  `effectiveStart`. For `everyNDays`, the modular anchor stays
  `createdAt` (the cycle definition doesn't change — only the
  boundary does).

- **`DefaultHabitScoreCalculator`**: replace `habit.createdAt` with
  effective start in `scoreHistory`.

- **`DefaultStreakCalculator`**: replace `createdDay` boundaries with
  effective start in all four loop methods.

- **`OverviewMatrix`**: replace `habitCreatedStart` with effective
  start.

- **`MonthlyCalendarView.isDueByDay`**: remove `delta >= 0` guard
  for `everyNDays` (or use effective start). Other frequency types
  don't use `createdAt` in the calendar.

### Data model changes

None. `createdAt` keeps its current meaning ("when the record was
added to the app"). The effective start is computed, not stored.

### UI changes

- **MonthlyCalendarView**: days before `createdAt` but after the
  effective start should render as due (`.missed` or `.completed`),
  not `.nonDue`. Currently the calendar only shows the current month
  — pre-creation days in the current month will "light up" once
  backdated completions exist.
- **Optional**: show the effective start date somewhere in the
  habit detail (e.g., "Tracking since Apr 25" below the habit
  name). This makes the behavior explicit as the issue suggests.
- **Overview matrix**: same — pre-creation cells with completions
  should show as scored, not `.notDue`.

### Tests to write

- Score calculator: habit created day 0, completion on day -3 →
  score history starts at day -3.
- Score calculator: habit created day 0, first completion on day 5 →
  score history starts at day 5, days 0-4 are not penalized.
- Streak calculator: backdated completion extends streak past
  `createdAt`.
- Frequency evaluator: day before `createdAt` with a completion is
  considered due.
- Negative habit: effective start stays at `createdAt` regardless of
  completions.
- `everyNDays`: cycle anchor stays at `createdAt` even when effective
  start is earlier (modular arithmetic consistency).
- Overview matrix: pre-creation day with completion renders as
  `.scored`, not `.notDue`.

## Alternatives considered

### Alternative A: Move `createdAt` back when backdating

- Idea: when a completion is logged before `createdAt`,
  automatically move `createdAt` to that date.
- Why not: loses the original creation timestamp. Couples a mutation
  side-effect to completion logging. The `everyNDays` cycle would
  shift unpredictably. And it doesn't solve the "first completion
  after creation" case.

### Alternative B: Add a `startDate` field to `HabitRecord`

- Idea: new stored `startDate: Date?` field, user-editable, defaults
  to `createdAt`. Schema migration V3 → V4.
- Why not: heavier than needed. A computed effective start achieves
  the same result without a migration or extra UI for editing the
  field. Could revisit if users want explicit control over the start
  date independent of completions.

### Alternative C: Only change the score, not the streak/frequency

- Idea: anchor score to first completion but keep streak/frequency
  boundaries at `createdAt`.
- Why not: inconsistent. If the score says "tracking since Wednesday"
  but the streak counts from Monday, the user sees contradictory
  numbers.

## Risks and unknowns

- **Performance of `effectiveStart`**: requires finding the earliest
  completion. On a habit with thousands of completions, this is a
  linear scan. Mitigation: cache the min date, or compute it once
  per render cycle and pass it through. Alternatively, maintain a
  `firstCompletionDate` computed property on `HabitRecord` that
  scans the relationship — SwiftData relationships are lazy-loaded.
- **`everyNDays` cycle anchor**: the modular arithmetic
  `delta % n == 0` is anchored to `createdAt`. If we allow days
  before `createdAt`, `delta` becomes negative, and `% n` behaves
  differently for negative dividends in Swift (result has the sign
  of the dividend). Need to use `((delta % n) + n) % n == 0` or
  equivalent. This is a subtle bug waiting to happen — test it.
- **Negative habits**: "no completion = success" means the effective
  start must stay at `createdAt` for negative habits, otherwise
  backdating a slip would erase prior "successful" days from the
  score. Need clear documentation of this exception.
- **CloudKit sync**: two devices could have different completion
  sets mid-sync, causing the effective start to differ temporarily.
  This is acceptable — it self-resolves once sync completes.

## Open questions

- [ ] Should the UI show "Tracking since <date>" in the habit detail
      to make the effective start explicit?
- [ ] For negative habits, should the effective start still be
      `createdAt`, or should it be the first completion (slip) date?
      The research recommends `createdAt` but this is debatable.
- [ ] Should there be a limit on how far back a user can backdate?
      (e.g., max 1 year to prevent accidental taps on ancient dates)

## References

- [Issue #42](https://github.com/scastiel/kado/issues/42)
- `DefaultFrequencyEvaluator.swift` — the `createdDay` guard is the
  root blocker
- `docs/habit-score.md` — EMA score algorithm documentation
