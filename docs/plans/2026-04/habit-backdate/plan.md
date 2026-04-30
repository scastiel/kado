# Plan — Habit Backdate

**Date**: 2026-04-29
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Allow users to log completions before a habit's creation date and
anchor score/streak calculations to the first completion date instead
of `createdAt`. Six code paths currently use `createdAt` as a hard
boundary — all need to use a computed "effective start" instead. No
schema migration. The habit detail view gains a "Tracking since"
label. Negative habits keep `createdAt` as their start.

## Decisions locked in

- Effective start = first completion date (or `createdAt` if none)
- Negative habits: effective start always = `createdAt`
- No backdate limit — users can go as far back as they want
- "Tracking since <date>" shown in the habit detail header
- No new stored field — effective start is computed
- `everyNDays` cycle anchor stays at `createdAt` (only the boundary
  shifts, not the modular arithmetic)

## Task list

### Task 1: Add `effectiveStart` to Habit domain type

**Goal**: Pure function that computes the effective start from a
habit and its completions.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Models/Habit.swift` — add
  `effectiveStart(completions:calendar:) -> Date` method. For
  negative habits, returns `createdAt`. For others, returns
  `min(createdAt, earliestCompletionDate)` — or `createdAt` if no
  completions.

**Tests / verification**:
- No completions → returns `createdAt`
- First completion before `createdAt` → returns completion date
- First completion after `createdAt` → returns first completion date
- Negative habit with pre-creation completion → returns `createdAt`
- Multiple completions → returns the earliest

**Commit message**: `feat(habit-backdate): add effectiveStart to Habit`

---

### Task 2: Update DefaultFrequencyEvaluator

**Goal**: Days before effective start are not due; days between
effective start and `createdAt` are due. `everyNDays` modular
arithmetic stays anchored to `createdAt`.

**Changes**:
- `DefaultFrequencyEvaluator.swift` — the `isDue` method needs
  access to completions (already has them) and calendar to compute
  effective start. Replace `guard day >= createdDay` with
  `guard day >= effectiveStartDay`. For `everyNDays`, keep
  `createdDay` as the modular anchor but allow negative deltas:
  use `((delta % n) + n) % n == 0` instead of `delta >= 0 && delta % n == 0`.

**Tests / verification**:
- Daily habit, day before `createdAt` with completion → `isDue` returns true
- Daily habit, day before effective start → `isDue` returns false
- `everyNDays(3)`, 6 days before creation (cycle-aligned) → `isDue` true
- `everyNDays(3)`, 5 days before creation (not aligned) → `isDue` false
- Negative habit, day before `createdAt` → `isDue` false (keeps `createdAt`)
- Existing tests still pass

**Commit message**: `feat(habit-backdate): allow pre-creation days in FrequencyEvaluator`

---

### Task 3: Update DefaultHabitScoreCalculator

**Goal**: Score history starts at effective start, not `createdAt`.

**Changes**:
- `DefaultHabitScoreCalculator.swift` — `currentScore` passes
  effective start instead of `habit.createdAt` to `scoreHistory`.
  `scoreHistory` already accepts a `from:` parameter — just need
  to compute effective start from the completions. Add completions
  parameter awareness for effective start calculation.

**Tests / verification**:
- Habit created day 0, completion on day -3 → score starts at day -3
- Habit created day 0, first completion on day 5 → score starts at
  day 5, days 0-4 not penalized (score on day 5 = alpha, not
  alpha * (1-alpha)^5)
- Negative habit: score starts at `createdAt` regardless
- Existing score tests still pass

**Commit message**: `feat(habit-backdate): anchor score to effective start`

---

### Task 4: Update DefaultStreakCalculator

**Goal**: Streak calculation boundaries use effective start.

**Changes**:
- `DefaultStreakCalculator.swift` — replace `createdDay` with
  effective start in all four loop methods (`currentByDay`,
  `bestByDay`, `currentDaysPerWeek`, `bestDaysPerWeek`). The
  `isDueByDay` private method also needs the same `everyNDays` fix
  as the frequency evaluator (negative delta modular arithmetic).

**Tests / verification**:
- Backdated completion extends streak past `createdAt`
- Best streak includes pre-creation completions
- `daysPerWeek` counts pre-creation week completions
- Existing streak tests still pass

**Commit message**: `feat(habit-backdate): extend streak past createdAt`

---

### Task 5: Update OverviewMatrix and MonthlyCalendarView

**Goal**: Pre-creation days with completions render correctly.

**Changes**:
- `OverviewMatrix.swift` — replace `habitCreatedStart` with
  effective start. Days before effective start are `.notDue`;
  days between effective start and `createdAt` follow normal
  due/completed logic.
- `MonthlyCalendarView.swift` — `isDueByDay` for `everyNDays`
  needs the same negative-delta fix. The `state(for:)` method
  already delegates to `isDueByDay` / checks completions, so
  it should work once the frequency logic is fixed.

**Tests / verification**:
- Overview matrix: pre-creation day with completion → `.scored`
- Calendar: pre-creation day shows as `.completed` or `.missed`,
  not `.nonDue`
- Existing overview matrix tests updated

**Commit message**: `feat(habit-backdate): update calendar and matrix for pre-creation days`

---

### Task 6: "Tracking since" label in HabitDetailView

**Goal**: Show the effective start date in the habit detail header.

**Changes**:
- `HabitDetailView.swift` — add a "Tracking since <date>" label
  below the frequency/type labels in the header. Only show when
  effective start differs from `createdAt` (to avoid noise on
  habits where they match).

**Tests / verification**:
- Preview: habit with backdated completions shows "Tracking since"
- Preview: habit with no backdated completions doesn't show it
- Localization: add EN + FR strings

**Commit message**: `feat(habit-backdate): show "Tracking since" in habit detail`

---

### Task 7: Localization and accessibility

**Goal**: New strings localized EN + FR, VoiceOver updated.

**Changes**:
- `Localizable.xcstrings` — add "Tracking since %@" / "Suivi
  depuis le %@" (or similar FR phrasing)
- Calendar accessibility labels: pre-creation days should be
  described accurately

**Tests / verification**:
- `LocalizationCoverageTests` passes
- VoiceOver reads "Tracking since" label correctly

**Commit message**: `feat(habit-backdate): localization and accessibility`

## Risks and mitigation

- **`everyNDays` negative modular arithmetic**: Swift's `%` gives
  negative results for negative dividends. The fix
  `((delta % n) + n) % n == 0` is standard but needs careful testing.
  Covered in Task 2 and Task 4/5.
- **Performance of effective start**: finding the earliest completion
  is O(N). For habits with thousands of completions this could be
  noticeable if called per-cell. Mitigation: compute once per render
  in the view/calculator, not per-day.
- **Interaction with habit-notes (PR #43)**: zero-value note-only
  records should not shift the effective start. The `effectiveStart`
  method should filter `value > 0` when finding the earliest
  completion, consistent with how all other code paths treat
  zero-value records.

## Open questions

- (All resolved during planning — none remaining.)

## Out of scope

- User-editable `startDate` field on `HabitRecord` (Alternative B
  from research — revisit if users want explicit control)
- Backdate limit enforcement
- Month navigation in the calendar (currently shows only the current
  month — adding month navigation is a separate feature)
