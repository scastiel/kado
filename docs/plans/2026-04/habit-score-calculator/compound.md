# Compound — Habit score calculator

**Date**: 2026-04-16
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/habit-score-calculator](https://github.com/scastiel/kado/pull/2)

## Summary

Built Kadō's signature `HabitScoreCalculator` (EMA, α = 0.05) plus
the supporting domain layer (`Frequency`, `HabitType`, lightweight
`Habit`/`Completion` value types) and `FrequencyEvaluator`. All seven
planned tasks shipped in order with no scope cuts and no plan
revisions. The headline lesson: **doing the calendar work properly
upfront made archiving and DST handling fall out for free** —
Tasks 6's "edge cases" turned into pure regression tests.

## Decisions made

- **Pure value types now, SwiftData later**: `Habit` and `Completion`
  are plain structs in `Models/`. The calculator stays unit-testable
  with no `ModelContainer`. SwiftData `@Model` wrappers will project
  to/from these in the next PR.
- **One service, one PR**: `FrequencyEvaluator` shipped alongside the
  score calculator (the score is meaningless without it).
  `StreakCalculator` was held back for its own PR.
- **Calendar injected on every service**: both
  `DefaultFrequencyEvaluator` and `DefaultHabitScoreCalculator` accept
  a `Calendar` parameter (default `.current`). Tests pin to
  UTC/Gregorian or Europe/Paris for determinism.
- **Trailing 7-day rolling window for `.daysPerWeek(N)`**: due if
  fewer than N completions in the prior 7 days (inclusive).
  Locale-neutral, no ISO-week edge cases.
- **Off-schedule completions are ignored by the score**: a completion
  on a non-due day stays in the history but contributes nothing.
- **Frequency change applies retroactively**: no per-day
  frequency-history snapshot in MVP — current frequency drives all
  past evaluations.
- **Negative habits = presence-not-value**: for `HabitType.negative`,
  any completion on a due day is a failure (value 0), absence is
  success (value 1). `Completion.value` is ignored for this type.
- **Counter/timer values sum across same-day completions**: supports
  both the "one tally completion per day" UX and the "log each unit"
  UX without forcing a choice in the data model.
- **`@Sendable` on every protocol and value type**: services pass
  through SwiftUI `Environment`, which crosses concurrency domains.
  Cheap insurance against future strict-concurrency warnings.

## Surprises and how we handled them

### "Edge case" tasks were no-ops in code

- **What happened**: Task 6 was scoped as
  archiving + DST-safe day arithmetic. Both turned out to require
  zero implementation changes — `FrequencyEvaluator` already
  short-circuits past `archivedAt`, and the calculator's day-walk
  uses `Calendar.date(byAdding: .day, ...)` which is DST-correct
  by construction.
- **What we did**: Kept Task 6 as a regression-test-only commit
  pinning the behavior so a future refactor can't regress it
  silently.
- **Lesson**: When you do the boring foundational work right (use
  `Calendar` operations, not `addingTimeInterval(86400)`), the scary
  edge cases evaporate. Worth flagging in `CLAUDE.md`.

### `Completion.value` semantics needed a per-`HabitType` definition

- **What happened**: The `Completion` struct has a single `value:
  Double` field, but its meaning differs per `HabitType` (binary →
  ignored, counter → units, timer → seconds, negative → ignored).
  Easy to misuse from a calling site that doesn't know the habit's
  type.
- **What we did**: Documented the per-type semantics in a doc-comment
  on `Completion`. The calculator's `derivedValue` is the single
  place that interprets the field, so misuse is local.
- **Lesson**: A single field with type-dependent semantics is a code
  smell, but here the alternative (separate fields per type, or a
  variant enum) is overkill for MVP. Acceptable as long as the
  doc-comment stays accurate. Revisit if a third caller emerges.

## What worked well

- **Strict TDD**: every business-logic task wrote tests first,
  confirmed red, then implemented. Caught zero post-implementation
  bugs across 37 tests. The "score is always in [0, 1]" invariant
  test in particular gives confidence the EMA can never break out
  of bounds even under pathological input.
- **`TestCalendar` helper**: a single 25-line file (UTC calendar +
  reference Monday + `day(_:)` offset helper) made every date
  fixture in the suite trivially readable. Day 0 is Monday — every
  test reads the offset directly.
- **Comparing non-daily scores against daily-equivalent baselines**:
  e.g. "Mon/Wed/Fri perfect over 10 weeks (30 due days) yields the
  same score as 30 daily perfects." This catches off-by-one in the
  skip logic far better than checking against a hard-coded EMA value.
- **Plan up front locked in the 4 semantic decisions**
  (.daysPerWeek window, off-schedule, frequency change, negative
  habits) before any code was written. Zero rework during build.
- **Per-task commits** (8 atomic commits across 7 tasks + 1 plan).
  Each task left the project green; debugging would be trivial.

## For the next person

- The calculator is **stateless and recomputes from `createdAt`
  every call**. Spec acknowledges this; caching is post-MVP and
  should only be added when a profiler shows it matters.
- `DefaultFrequencyEvaluator` is constructed automatically by
  `DefaultHabitScoreCalculator` when no evaluator is injected —
  they share the same calendar. Override only if you need a
  different "due" policy (e.g. `StreakCalculator` may want a
  stricter version).
- `Completion.value` defaults to `1.0`. For `.binary` and `.negative`
  habits, callers can ignore it. For `.counter` and `.timer`, callers
  must supply a meaningful value — the field's per-type semantics are
  documented on `Completion`.
- `EnvironmentValues+Services.swift` is the registry. Adding a new
  service: define the protocol, write a `private struct …Key:
  EnvironmentKey`, and add a computed property. The
  `HabitScoreCalculatorKey` is the canonical example.
- Tests under `KadoTests/Helpers/` are not yet wired with their own
  Xcode group — Xcode 16 synchronized folders pick them up
  automatically. Add new test helpers there.
- The four semantic decisions (rolling-7-day window, off-schedule
  ignored, current frequency retroactive, negative = presence) are
  load-bearing. Changing them silently will break user expectations
  even if tests still pass — surface them in any future product
  discussion.

## Generalizable lessons

- **[→ CLAUDE.md]** Day arithmetic must always go through
  `Calendar.date(byAdding: .day, ...)` and `Calendar.startOfDay(for:)`.
  Never `addingTimeInterval(86400)` or arithmetic on raw `TimeInterval`s
  for "a day later" — DST silently breaks them. Worth a short rule in
  the SwiftData / concurrency conventions block.
- **[→ CLAUDE.md]** Inject `Calendar` (and `Date`, when relevant) into
  any service that does date math, with default `.current`. Tests can
  then pin to UTC for determinism. Already implicit in the project,
  but worth stating explicitly.
- **[→ CLAUDE.md]** When a task can be expressed as "result equals
  the result of an analytically simpler computation" (e.g. score with
  skips equals score with N daily perfects), prefer that comparison
  over a hard-coded numeric expectation. Easier to read, more robust
  to small algorithm tweaks.
- **[local]** The `TestCalendar` helper pattern (UTC + a reference
  Monday + `day(_:)` offset) generalizes to any future date-sensitive
  service test. Keep it as the convention.
- **[ROADMAP, post-MVP]** Score caching: invalidate from the
  modified date forward. Spec acknowledges this as a perf
  optimization, not yet warranted.

## Metrics

- Tasks completed: 7 of 7
- Tests added: 36 (1 pre-existing smoke test untouched)
- Commits on branch: 8 (1 plan + 7 build)
- Files added: 13 source + 4 test + 2 docs
- Net diff: +1,277 / -14 across 16 files
- Build time (incremental): ~3s; tests run: ~5s
- Plan revisions during build: 0

## References

- [docs/habit-score.md](../../../habit-score.md) — algorithm spec
  (served as the research artifact for this feature).
- [Loop Habit Tracker Kotlin source](https://github.com/iSoron/uhabits) —
  philosophical inspiration; not consulted directly during implementation
  to keep the EMA derivation independent.
- Lally et al. (2010), habit formation 66-day finding cited in the
  spec — informs the choice of α = 0.05 (≈14-day half-life).
