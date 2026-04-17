# Plan — Habit score calculator

**Date**: 2026-04-16
**Status**: ready to build
**Spec**: [docs/habit-score.md](../../../habit-score.md)
**Research**: skipped — `habit-score.md` already serves as the research
artifact (algorithm, edge cases, envisioned API, and required tests
are all spec'd).

## Summary

Build the `HabitScoreCalculating` service that computes Kadō's
signature habit-strength score (an EMA over per-day completion values,
α = 0.05). The calculator is pure logic, depends on no system APIs,
and operates on plain value types — no SwiftData yet. We'll also
introduce the supporting domain value types (`Frequency`, `Weekday`,
`HabitType`, lightweight `Habit` and `Completion`, `DailyScore`) and
the `FrequencyEvaluator` that decides whether a given day counts. By
the end, the calculator is registered in the DI container and ready
for v0.1 views to consume.

## Decisions locked in

- **Pure value types now, SwiftData later.** Define `Habit` and
  `Completion` as structs in `Models/`. When SwiftData `@Model` types
  land (next PR), they'll expose a `parameters: HabitParameters`
  projection or similar. Keeps the calculator unit-testable without
  spinning up a `ModelContainer`.
- **TDD strict**: every business-logic file gets its tests written
  first. Red → green → refactor per `CLAUDE.md`.
- **One service, one PR**: `FrequencyEvaluator` ships in this PR
  because the score calculator is meaningless without it. `StreakCalculator`
  stays out — different concern, different PR.
- **α = 0.05 hard-coded** as `DefaultHabitScoreCalculator(alpha: 0.05)`.
  Configurable via init for tests; not exposed to the user.
- **`Calendar.current` + `startOfDay(for:)`** for all day arithmetic.
  Tests inject a fixed calendar (UTC + a DST-crossing locale) to
  exercise timezone edge cases deterministically.
- **No score caching.** Spec explicitly says "to do when performance
  becomes a problem, not before." Recompute from `createdAt` every
  call.
- **Frequency is a single field on `Habit`.** No frequency-history
  model in MVP. The "change of frequency mid-history" test from the
  spec becomes "calculator uses the habit's current frequency for all
  past days" — see Open questions.
- **Negative habits are a `HabitType` case**, not a flag on `Habit`.
  Keeps the `value[n]` derivation co-located with type semantics.
- **Counter/timer target lives on `Habit`**, not per-`Completion`.
  Changing the target would mean recalculation; acceptable for MVP.
- **`.daysPerWeek(N)` = trailing 7-day rolling window.** Due if fewer
  than N completions in the prior 7 days. Locale-neutral, no ISO-week
  edge cases.
- **Off-schedule completions are ignored by the score.** A completion
  logged on a non-due day is preserved in history but contributes
  nothing to `value[n]`. Keeps "skipped day" semantics intact.
- **Frequency change applies retroactively.** The habit's *current*
  frequency is used to evaluate every past day. No frequency-history
  model in MVP.
- **Negative habit completion = presence, not value.** For
  `HabitType.negative`, the existence of a `Completion` on a due day
  means "I had it" (value = 0); absence means "I avoided it" (value =
  1). The `Completion.value` field is ignored for this type.

## Task list

### Task 1: Domain value types ✅

**Goal**: Land the lightweight value types the calculator and tests
will speak in.

**Changes**:
- `Kado/Models/Weekday.swift` — `enum Weekday: Int, CaseIterable, Codable`
  (sun=1 to sat=7, matching `Calendar.component(.weekday, from:)`).
- `Kado/Models/Frequency.swift` — `enum Frequency: Hashable, Codable`
  with cases `.daily`, `.daysPerWeek(Int)`,
  `.specificDays(Set<Weekday>)`, `.everyNDays(Int)`.
- `Kado/Models/HabitType.swift` — `enum HabitType: Hashable, Codable`
  with cases `.binary`, `.counter(target: Double)`,
  `.timer(targetSeconds: TimeInterval)`, `.negative`.
- `Kado/Models/Habit.swift` — `struct Habit: Identifiable, Hashable`
  with `id`, `name`, `frequency`, `type`, `createdAt`, `archivedAt`.
  (Icon/color come later with the SwiftData `@Model`.)
- `Kado/Models/Completion.swift` — `struct Completion: Identifiable,
  Hashable` with `id`, `habitID`, `date`, `value: Double`, optional
  `note`.
- `Kado/Models/DailyScore.swift` — `struct DailyScore: Hashable` with
  `date: Date`, `score: Double`.

**Tests / verification**:
- No tests for value types themselves (pure data).
- `build_sim` succeeds.

**Commit**: `feat(models): add Frequency, HabitType, Habit and Completion value types`

---

### Task 2: FrequencyEvaluator (TDD)

**Goal**: Decide whether a habit is "due" on a given calendar day.

**Changes**:
- `Kado/Services/FrequencyEvaluating.swift` — protocol with
  `func isDue(habit: Habit, on date: Date, completions: [Completion]) -> Bool`.
  (`completions` needed for `.daysPerWeek` rolling window logic.)
- `KadoTests/FrequencyEvaluatorTests.swift` — written first.
- `Kado/Services/DefaultFrequencyEvaluator.swift` — implementation.

**Tests / verification** (Swift Testing, written before impl):
- `.daily` → due every day.
- `.specificDays([.mon, .wed, .fri])` → due Mon/Wed/Fri only.
- `.everyNDays(3)` → due on `createdAt`, +3, +6, …
- `.daysPerWeek(3)` → due if fewer than 3 completions in the trailing
  7-day window; not due otherwise.
- A day before `createdAt` → never due.
- A day after `archivedAt` → never due.

**Commit**: `feat(frequency): implement FrequencyEvaluator with daily, specific-days, every-N, days-per-week`

---

### Task 3: HabitScoreCalculator — invariants and binary daily

**Goal**: First green calculator covering the common path: binary
daily habits.

**Changes**:
- `Kado/Services/HabitScoreCalculating.swift` — protocol from spec.
- `KadoTests/HabitScoreCalculatorTests.swift` — invariants + daily
  cases (written first).
- `Kado/Services/DefaultHabitScoreCalculator.swift` — implementation
  walking days from `createdAt` to `asOf`, applying EMA on
  due-and-completed = 1, due-and-missed = 0, not-due = skip.

**Tests / verification** (from spec § Critical tests):
- Score is always in `[0, 1]`.
- Score of empty history is 0.
- Score with no completions ever stays at 0.
- 30-day perfect daily streak → score > 0.75.
- 100-day perfect daily streak → score > 0.95.
- Single missed day after a perfect month barely dents the score
  (delta < 0.05).
- Ten consecutive missed days significantly reduce the score
  (delta > 0.25).
- Score recovers after completions resume.

**Commit**: `feat(score): implement EMA habit score for binary daily habits`

---

### Task 4: Non-daily frequency support

**Goal**: Score calculation correctly skips non-due days.

**Changes**:
- Extend `DefaultHabitScoreCalculator` to consult
  `FrequencyEvaluator` per day (already wired in Task 3 — this task
  exercises it with non-daily frequencies).
- New tests in `HabitScoreCalculatorTests.swift`.

**Tests / verification**:
- `.specificDays([.mon, .wed, .fri])` perfect adherence over 6 weeks
  → score > 0.75 (only 18 evaluated days).
- `.everyNDays(3)` perfect adherence → score climbs at expected rate.
- Off-schedule completions (logged on a non-due day) do **not**
  contribute to the score.

**Commit**: `feat(score): support non-daily frequencies via FrequencyEvaluator`

---

### Task 5: Counter, timer, negative habit types

**Goal**: Derive `value[n]` per `HabitType`.

**Changes**:
- Extend `DefaultHabitScoreCalculator`'s value derivation:
  - `.binary` → 1.0 if completion exists, else 0.0.
  - `.counter(target)` → `min(1.0, achieved / target)`.
  - `.timer(targetSeconds)` → `min(1.0, achievedSeconds / target)`.
  - `.negative` → 1.0 if no completion logged on a due day, 0.0 if a
    completion is logged. (`Completion` for a negative habit means
    "I had it.")
- Tests for each.

**Tests / verification**:
- Counter 6/8 → value 0.75 contributes partial credit.
- Counter 12/8 (over) → value caps at 1.0.
- Timer 20min/30min → value 0.667.
- Negative habit: missed days (no completion) raise the score, logged
  days drop it.

**Commit**: `feat(score): support counter, timer and negative habit types`

---

### Task 6: Archiving and timezone edge cases

**Goal**: Handle the boundary conditions from the spec.

**Changes**:
- Score calculation stops at `archivedAt` (no further days
  evaluated).
- All day arithmetic via `Calendar` + `startOfDay(for:)`. Inject the
  calendar into `DefaultHabitScoreCalculator` (`init(alpha:calendar:)`)
  with default `.current`.
- Tests use a fixed Gregorian calendar pinned to `Europe/Paris`
  (DST-crossing) to exercise spring-forward / fall-back days.

**Tests / verification**:
- Archived habit's score equals its score on the archive date,
  regardless of `asOf`.
- Score for a date crossing a DST boundary advances exactly one day
  (no double-count, no skip).
- Habit created today, completed today → score ≈ α (not 1.0).
- Backfilling a past completion produces the same result as building
  the history with that completion present from the start.

**Commit**: `feat(score): handle archiving and DST-correct day arithmetic`

---

### Task 7: Dependency injection wiring

**Goal**: Make the calculator discoverable from any SwiftUI view via
`@Environment`.

**Changes**:
- Edit `Kado/App/EnvironmentValues+Services.swift` — replace the
  commented scaffold with the live `HabitScoreCalculating` key.
- Default value: `DefaultHabitScoreCalculator()`.
- One smoke test: `EnvironmentValues().habitScoreCalculator` returns a
  `DefaultHabitScoreCalculator`.

**Tests / verification**:
- `build_sim` clean.
- `test_sim` all green.

**Commit**: `feat(di): register HabitScoreCalculating in EnvironmentValues`

## Risks and mitigation

- **Risk**: Off-by-one in day enumeration creates score divergence
  across timezones. → **Mitigation**: pin tests to a fixed
  `Calendar(identifier: .gregorian)` with `Europe/Paris` timeZone;
  assert exact day counts for known input.
- **Risk**: Value types now → SwiftData refactor later costs us
  duplicated definitions. → **Mitigation**: keep the value structs
  small enough that the `@Model` wrapping is mechanical; `Habit` and
  `Completion` get a `parameters` projection.
- **Risk**: Test data fixtures (`Completion(date: .daysAgo(n), …)`)
  need date helpers we haven't built. → **Mitigation**: add
  `Date+Testing.swift` in `KadoTests/` with `daysAgo(_:)` against the
  injected calendar.

## Open questions

None at plan time — all four resolved into the Decisions section
before build.

## Out of scope

- SwiftData `@Model` types — next PR.
- `StreakCalculator` — separate service, separate PR.
- Score caching / incremental recalculation — defer until performance
  is measured.
- UI presentation of the score (qualifier vs percentage, color
  thresholds) — UX phase of v0.1.
- iCloud sync — v0.1 infrastructure phase.
- Localization of any strings (calculator has none).
