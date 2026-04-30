# Compound — Habit Backdate

**Date**: 2026-04-29
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/habit-backdate — PR #44](https://github.com/scastiel/kado/pull/44)

## Summary

Replaced `createdAt` as the hard boundary in all 6 code paths with a
computed `effectiveStart` — the earliest positive-value completion
date, or `createdAt` if none. Users can now log completions before
creation, and the score/streak window starts at the first completion
rather than penalizing early missed days. No schema migration. The
build went smoothly — no mid-plan pivots, and the one existing test
that broke (`scoredReflectsDailyValue`) was an expected semantic
change.

## Decisions made

- **Computed, not stored**: `effectiveStart` is derived from
  completions at call time. No new field, no migration, no CloudKit
  complexity. Trade-off: O(N) scan per call — acceptable for current
  data volumes.
- **Negative habits keep `createdAt`**: "no completion = success"
  means the start must be anchored to creation, not first slip.
  Without this exception, early clean days would vanish from the
  score when a slip is recorded.
- **`everyNDays` cycle anchor stays at `createdAt`**: only the
  boundary shifts; the modular arithmetic that defines which days
  are due still anchors to the original creation. This avoids
  shifting the cycle when backdating.
- **`((delta % n) + n) % n == 0` for negative deltas**: Swift's `%`
  preserves the sign of the dividend, so `-5 % 3 == -2`, not `1`.
  The double-modulo idiom normalizes to `[0, n)`.
- **"Tracking since" only shown when effective start differs from
  `createdAt`**: avoids noise on habits where they match (the
  common case).
- **No backdate limit**: users can go as far back as they want.

## Surprises and how we handled them

### No surprises

The research correctly identified all 6 code paths and the
`everyNDays` modular arithmetic trap. The only test that broke
(`scoredReflectsDailyValue` in `OverviewMatrixTests`) was an expected
semantic change — pre-creation days now render as `.notDue` instead
of `.scored(0.0)` because the effective start shifted forward to the
first completion. Updated the expectation.

## What worked well

- **Research-first approach**: the codebase survey identified every
  `createdAt` usage before writing a line of code. Zero surprises
  during build.
- **Pure function on a value type**: `effectiveStart` is testable in
  isolation, no SwiftData needed. The 7 unit tests for it run in
  milliseconds.
- **Consistent replacement pattern**: every code path followed the
  same change — replace `createdAt` with `effectiveStart`. No
  special cases beyond negative habits.

## For the next person

- **`effectiveStart` is called multiple times per render.** The
  calendar view calls it once per cell (up to 31 times), and the
  score/streak calculators call it independently. If performance
  becomes an issue with large completion sets, precompute once per
  view update and pass through. Profile before optimizing.
- **The `everyNDays` modular arithmetic appears in three places**:
  `DefaultFrequencyEvaluator`, `DefaultStreakCalculator.isDueByDay`,
  and `MonthlyCalendarView.dayIsDue`. All three must use the
  `((delta % n) + n) % n` pattern. If you add a fourth, check for
  negative deltas.
- **Pre-effective-start calendar cells are `.nonDue` but tappable.**
  Creating a completion on a pre-effective-start day shifts the
  effective start back and lights up the intervening cells. This is
  intentional — it's how backdating works from the user's
  perspective.

## Generalizable lessons

- **[local]** When replacing a boundary value used across multiple
  services, a pure computed property on the domain type is cleaner
  than passing a new parameter everywhere — callers already have the
  habit and its completions.
- **[local]** Swift's `%` operator with negative dividends is a
  recurring trap. The `((x % n) + n) % n` idiom should be used
  anywhere modular day arithmetic can go negative.

## Metrics

- Tasks completed: 7 of 7 (tasks 6+7 combined into one commit)
- Tests added: 22
- Commits: 8
- Files touched: 12 Swift files + 1 xcstrings
