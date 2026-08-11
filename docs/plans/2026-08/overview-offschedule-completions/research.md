# Research — Off-schedule completions & the two meanings of `isDue`

**Date**: 2026-08-10
**Status**: ready for plan
**Related**: [issue #57](https://github.com/scastiel/kado/issues/57)

## Problem

A user with a `.daysPerWeek(5)` habit back-filled an earlier day from the
habit's monthly calendar. The calendar showed it completed; the Overview
grid showed the same day as neutral gray ("not scheduled"). Two surfaces,
one day, contradictory answers.

The issue body proposed a root cause from a read of the source. **It was
verified against running code** with a throwaway probe suite
(`TempIssue57Characterization`, deleted before merge). All of its claims
hold, and the probe surfaced two more defects with the same origin.

### Probe results (actual test output)

| Probe | Observed |
|---|---|
| Overview matrix, 5×/week with a back-filled day | `d-2*=notDue \| d-1*=notDue` — days carrying completions render `.notDue` |
| `isDue` self-cancellation | `due(4 prior)=true`, `due(4 prior + today)=false` |
| Score, perfect 5×/week user, 6 weeks | **0.185** — vs **0.884** for a perfect daily user |
| `.daysPerWeek` quota vs zero-value records | 3 "unchecked but noted" records (`value == 0`) saturate the quota |

The score result is the serious one and was not in the issue. A user who
hits their 5-days-a-week target every single week has their habit score
frozen at ~19% forever. `DefaultHabitScoreCalculator.scoreHistory` only
folds a day into the EMA when `isDue` is true; once the rolling window
saturates it never is, so the EMA stops advancing after the first four
days of the habit's life and never moves again.

## Root cause

`isDue` is one function answering two unrelated questions:

- **Q1 — schedule / retrospective**: "was this day part of what the habit
  asked for?" Consumers: Overview matrix, monthly calendar, score
  calculator, Today-list sectioning. This answer must be **monotonic** —
  logging a completion must never change whether the day was required.
- **Q2 — actionable / prospective**: "does this still need doing right
  now, counting what I've already logged today?" Consumer: reminder
  scheduling. Here the day's own completions *should* count — that is the
  whole point.

`DefaultFrequencyEvaluator.isDue` implements Q2 (`countInWindow < target`
over `[day-6, day]`, inclusive of `day`) and every Q1 consumer reads it.
Every symptom above follows from that single conflation.

The duplication noted in the issue is the second half of the story:
`MonthlyCalendarView.dayIsDue` and `DefaultStreakCalculator.isDueByDay`
each re-implement the frequency rules privately, which is what let the
surfaces drift apart unnoticed.

## Current state of the codebase

| File | Role | Defect |
|---|---|---|
| `Services/DefaultFrequencyEvaluator.swift` | sole `FrequencyEvaluating` conformance | Q2 semantics; quota ignores `value > 0` |
| `Services/OverviewMatrix.swift` | grid cell states | schedule checked before completions → `.notDue` shadows a real completion |
| `Services/DefaultHabitScoreCalculator.swift` | EMA score | gates the EMA on Q1-via-Q2 → score freeze |
| `Services/DefaultStreakCalculator.swift` | streaks | private `isDueByDay` duplicate; `.daysPerWeek` uses week buckets, so unaffected by the quota bug |
| `Widgets/WidgetSnapshotBuilder.swift` | App Group snapshot | Today rows drop a habit the moment its quota saturates, even when completed today |
| `Services/Notifications/DefaultNotificationScheduler.swift` | reminders | genuinely wants Q2 — currently correct by accident |
| `UIComponents/MonthlyCalendarView.swift` | month grid | private `dayIsDue`; treats `.daysPerWeek` as always due; ignores `archivedAt` |
| `Views/Today/TodayView.swift` | today list | already works around the bug with `isDue \|\| completedToday` |

`TodayView.isDueTodayOrCompletedToday` is the existing precedent: the
codebase already discovered that "due" alone is the wrong predicate for
display, and patched it in one place. This work generalizes that.

`DefaultFrequencyEvaluator` is the **only** conformance to
`FrequencyEvaluating` — no mocks or fakes to update when the protocol
grows.

## Proposed approach

### 1. Split the protocol into the two questions

```swift
public protocol FrequencyEvaluating: Sendable {
    /// Q1 — schedule. Monotonic: what is logged *on* `date` never
    /// changes the answer.
    func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool

    /// Q2 — still actionable, counting what is already logged on `date`.
    func isOutstanding(habit: Habit, on date: Date, completions: [Completion]) -> Bool
}
```

The two differ **only** for `.daysPerWeek`; `.daily`, `.specificDays` and
`.everyNDays` ignore completions entirely. `isDue` counts the trailing
window over `[day-6, day-1]`; `isOutstanding` keeps `[day-6, day]`. Both
now require `value > 0`, so a note-bearing zeroed record no longer
saturates the quota.

Consequence for the score, hand-checked: a perfect 5×/week user gets
five `.scored(1.0)` days and two skipped days each week, so the EMA
converges to ~1.0 instead of freezing at 0.185.

### 2. Completions before schedule, with an explicit off-schedule state

`DayCell` gains a case:

```swift
case offSchedule(Double)   // logged on a day the schedule did not ask for
```

`OverviewMatrix.compute` resolution order becomes: future → pre-start →
**scheduled** → **logged anyway** → not due. `.offSchedule` carries the
same `DailyValue`, so `colorOpacity` is unchanged.

### 3. One source of truth for the schedule rules

Delete `MonthlyCalendarView.dayIsDue` and
`DefaultStreakCalculator.isDueByDay`; both take the injected evaluator.
The streak calculator keeps its `.daysPerWeek` week-bucket path (which
never consulted the rolling quota and is not implicated here).

### 4. Consumer sweep

- `DefaultNotificationScheduler` → `isOutstanding`. Behavior byte-identical
  to today; the existing `daysPerWeekSaturated` test must still pass.
- `WidgetSnapshotBuilder` Today rows → `isDue || logged today`, mirroring
  `TodayView`. Fixes a habit vanishing from the widget the moment it is
  completed.
- `DefaultHabitScoreCalculator`, `OverviewMatrix` → `isDue` (unchanged call,
  fixed semantics).

## Product decisions

Both are called out for review in the PR rather than blocking the fix.

### D1 — Off-schedule completions get their own visual, in the grid only

**Decision**: the Overview grid (and the widget's weekly grid) render an
off-schedule completion **hollow** — habit color at full strength as a
2pt border, the same color at ~25% as the fill. The monthly calendar
keeps its existing solid "completed" look.

Visual language, one rule across surfaces:

| State | Rendering |
|---|---|
| scheduled & done | solid habit color |
| **done, off schedule** | **hollow: habit-color border, pale fill** |
| scheduled & missed | habit color at the 0.2 opacity floor |
| not scheduled | flat neutral gray |

Why distinguish at all: the grid is 30 columns of pure schedule shape, and
the gray `.notDue` cell *is* how the schedule is drawn. Flattening a bonus
day into a normal completion would make a `.specificDays([.mon,.wed,.fri])`
row claim Saturday was scheduled. The issue's own suggested direction asks
for this ("so the grid still communicates the schedule rather than
flattening it").

Why a border rather than opacity or a glyph: opacity is already spoken for
by `DailyValue`, and a glyph does not survive the widget's smaller cells.
A border is unambiguous in cells that carry no text, scales down, and is
derived from the habit color — so no new color literals, and it adapts to
dark mode and Increase Contrast for free.

Why not in the monthly calendar: its cells carry a day number and the
border channel is already owned by the accent-colored "today" ring —
two concentric rings at 32pt is noise. It is also the *editing* surface,
where "what did I log here" is the question being asked. The reported
expectation ("the calendar shows the day as completed") stays exactly
satisfied. The calendar's real fix is routing its uncompleted days
through the shared evaluator.

This does not reintroduce the disagreement: "completed" and "completed,
off schedule" are a refinement of the same answer, not a contradiction
like "completed" vs "not scheduled".

### D2 — A day's own completion does **not** count against its own due-check

**Decision**: `isDue` excludes the evaluated day's completions.

- Non-monotonic predicates are incoherent: performing a habit should never
  retroactively rewrite whether it was ever required.
- It is what freezes the score at 19% for a user meeting their goal
  perfectly. That is a defect, not a preference.
- It matches the user's mental model — "I've done 4 this week, so today
  counts" — rather than "doing it made it not count."
- The one place the inclusive reading is correct (reminders) keeps it
  under the explicit `isOutstanding` name.

## Alternatives considered

**A. Keep one `isDue`, exclusive everywhere.** Simpler protocol, but the
notification scheduler would nudge a `.daysPerWeek` user who already hit
their target this morning. Rejected: it trades a fixed bug for a new one.

**B. `isScheduled` returning `true` for every `.daysPerWeek` day.**
Conceptually tidy — a flexible habit has no specific scheduled days — but
it caps a perfect 5×/week user's score at 5/7 ≈ 71%, and paints Sat/Sun as
missed. Rejected.

**C. Week-bucket scoring for `.daysPerWeek`.** Score the week, not the day.
Probably the *right* long-term model, but it reshapes the EMA and belongs
in its own PR with `docs/habit-score.md` updated. Deferred.

## Risks and unknowns

- `DayCell` / `WidgetDayCell` are `public` and the latter is `Codable` into
  the App Group JSON. Adding a case is additive; older snapshots decode
  unchanged, and app + widget always ship together, so no version skew.
- Routing `DefaultStreakCalculator` through the shared evaluator adds
  `effectiveStart` / `archivedAt` checks that its loop bounds already
  enforce — expected to be a no-op, but the streak suite is the gate. Revert
  that one step if it moves any assertion.
- A shortfall week still marks *every* remaining day due (a 2-day shortfall
  costs 4 missed days), because the rolling quota stays unmet. Pre-existing,
  out of scope, noted as follow-up.

## Open questions

- [ ] D1 and D2 above — implemented as decided, flagged in the PR for review.
- [ ] Should `.daysPerWeek` scoring move to week buckets (alternative C)?
      Separate PR.

## References

- `docs/habit-score.md` — EMA definition and α rationale
- Probe suite output captured in this document's table; the suite itself is
  temporary and does not land.
