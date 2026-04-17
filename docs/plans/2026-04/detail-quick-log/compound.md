---
# Compound — Detail view quick-log + history

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/detail-quick-log](https://github.com/scastiel/kado/pull/7)

## Summary

Shipped counter `+/−` controls, a timer "Log session" modal sheet,
and a scrollable completion history list on `HabitDetailView`. New
`CompletionLogger` service handles the value-carrying mutations
(mirrors `CompletionToggler`'s shape). `HabitRowView` now surfaces
today's value for counter/timer rows (`3/8` instead of `–/8`). 7
tasks shipped verbatim from the plan. **Headline: the "sub-minute
timer edit" issue that bit the previous PR reappeared as a
Double-vs-Int `#expect` failure — same family of bug, different
surface.**

## Decisions made

- **`CompletionLogger` as a concrete struct mirroring
  `CompletionToggler`**: no protocol, `Calendar` injection, inline
  instantiation at call sites. The pattern is clearly the right
  fit for "mutate a habit's completions from UI" — third time it
  recurs, worth codifying.
- **Single-record-per-day invariant holds across all types**:
  counter increments add to today's record; timer replaces it
  (delete-then-insert); decrement-to-zero deletes. "No record" ↔
  "not done today" bijection preserved.
- **Counter target-reached haptic fires only on below→at
  transition**: `.sensoryFeedback(.success, trigger:) { old, new in !old && new }`.
  Not on every re-render, not on the reverse direction.
- **Timer logging via modal sheet with minute stepper**: defers
  the real start/stop timer (ActivityKit, v0.3). Manual minute
  logging covers the MVP use case — 2 taps to log a 25-min
  session.
- **History list empty state is a neutral "No history yet" row**
  (not a `ContentUnavailableView` — the calendar above already
  signals "nothing here").
- **Swipe-to-delete with no confirmation**: iOS-convention. Undo
  lives in the row (tap +/-, delete, re-log).
- **Counter `+` always enabled**; `−` disabled only when value is
  0. Users can overshoot targets intentionally.
- **`HabitRowView.todayValue: Double? = nil`**: optional with a
  default to preserve every existing call site. `TodayView`
  computes it; detail-view consumers don't need it.
- **History list uses `LazyVStack`** (fixed during review): long
  histories render lazily, not eagerly.
- **Timer prefill via `.onAppear` + env calendar** (also a review
  fix): init-time `Calendar.current` was subtly inconsistent with
  the save path's env calendar.

## Surprises and how we handled them

### Double vs Int equality in `#expect` fails silently at compile time

- **What happened**: Two timer-session tests failed with
  `(habit.completions.first?.value → 1500.0) == (25 * 60 → 1500)`.
  `value` is `Double?`; `25 * 60` is `Int`. Swift's type system
  compiles the expression via permissive coercion but runtime
  equality returns false — the Double and Int have different
  bitwise representations, and `#expect`'s macro captures both
  values honestly.
- **What we did**: Explicit `Double(25 * 60)` on the RHS. Tests
  went green immediately. No impl change.
- **Lesson**: In Swift Testing with numeric types, always match
  sides explicitly. `Double(...)` or `1500.0` literal on the RHS
  of a `Double?` comparison. The compiler's silent coercion is a
  landmine for `#expect`. Worth a CLAUDE.md note under Testing.

### `CompletionHistoryList` was a `VStack`, not a `LazyVStack`

- **What happened**: The plan explicitly called for `LazyVStack`.
  The initial implementation used plain `VStack`, which eagerly
  builds every row on first render. Review caught it.
- **What we did**: One-line swap: `VStack` → `LazyVStack`. No
  other changes.
- **Lesson**: When the plan specifies `LazyVStack` for a
  potentially-large list, double-check at build time. Easy to
  drift from the plan's perf assumptions.

### Timer prefill used `Calendar.current`, not env

- **What happened**: `TimerLogSheet.init` read today's completion
  via `Calendar.current` because `@Environment` isn't accessible
  in `init`. The save path later used the env calendar — subtle
  inconsistency in tests/previews with overridden calendars.
- **What we did**: Moved prefill to `.onAppear`, where the env
  calendar is bound. Added a small `Optional<Int>` dance for the
  `@State` to reflect "not prefilled yet." No user-facing
  change.
- **Lesson**: `@Environment` values can't drive `@State`
  initializers directly. For env-dependent defaults, use
  `.onAppear` to perform the first assignment. Generalizable
  pattern worth calling out in CLAUDE.md alongside the existing
  `@Observable ViewModel` note.

## What worked well

- **Third time using the "service struct with Calendar injection"
  pattern** (after `CompletionToggler`, `StreakCalculator`,
  `HabitScoreCalculator`): the `CompletionLogger` landed in under
  an hour. Shape is familiar, tests are familiar, instantiation
  is familiar. Pattern is now load-bearing across the codebase.
- **TDD caught the Double/Int issue at first run**: red tests
  failed on the value comparison, not on scaffolding or build
  errors. Tight loop.
- **Plan tasks 3-7 each landed as their own commit** with no
  cross-task refactors — row update, counter view, timer sheet,
  history list, wiring. The bundling held.
- **Plan's "Out of scope" section** kept the PR from bloating.
  Live Activities, notes on completions, scrollable past months
  stayed deferred.
- **`@Bindable var habit: HabitRecord`** continues to carry
  SwiftData mutations cleanly across child components
  (`CompletionHistoryList`, `CounterQuickLogView` callbacks,
  `TimerLogSheet`). No explicit propagation needed; the detail
  view's `@Bindable` root cascades updates to every consumer.
- **Pre-merge review catching two real issues** that unit tests
  wouldn't have (LazyVStack perf, env-calendar consistency). The
  review stage is earning its time.

## For the next person

- **`CompletionLogger.delete` is a passthrough to
  `modelContext.delete`**. It exists for API symmetry with the
  other mutations. If you add centralized logging/telemetry
  later, the hook is there. Otherwise, `modelContext.delete`
  directly is equally correct.
- **Counter decrement below 1 deletes the record.** If a user
  edits `value` to a fractional number (via a hypothetical future
  API or data import), the deletion threshold (`<= 1`) might
  surprise — 0.5 decrements to deletion, not 0. Current UI uses
  integer steps so it can't happen today.
- **Timer sessions replace, not accumulate.** If a user logs two
  25-minute sessions in the same day, the second replaces the
  first. If product feedback wants sum-in-day semantics, revisit
  `logTimerSession` to add instead of replace — but note that
  the score algorithm currently expects one record per day.
- **`HabitDetailView.quickLogSection` is `.disabled(isArchived)`**
  — archived habits can't be logged against. But
  `CompletionHistoryList` swipe-to-delete stays enabled on
  archived habits intentionally: history editing remains
  possible after archive. Revisit if users treat archive as
  "read-only vault."
- **`CompletionHistoryList.valueLabel` for counter rows compares
  the completion's value against the habit's CURRENT target**,
  not the target at the time of the completion. If target
  changes (8→10), old "6/8" entries retroactively render as
  "6/10." To fix properly, store `targetAtTime` on
  `CompletionRecord` — a data-model change that belongs with the
  score-history spec work.
- **`absoluteDate` in the history list uses fixed format
  `"EEE MMM d"`** — English abbreviations baked in. Swap to a
  locale-aware formatter when FR lands.
- **Today row's `todayValue` threads through from `@Query`'s
  reactive result**: no explicit observation plumbing. If you
  add another per-row reactive field (score? streak?), follow
  the same pattern: compute in `TodayView`, pass via optional
  parameter with default `nil` to preserve call-site
  compatibility.

## Generalizable lessons

- **[→ CLAUDE.md — Testing]** In Swift Testing, numeric
  comparisons in `#expect` must have matching types on both
  sides. `Double? == Int` compiles (via the expression macro's
  permissive binding) but evaluates to `false` at runtime even
  for the same logical value. Always use explicit `Double(...)`
  or a `1500.0` literal when asserting against a `Double` value.
  Applies to `#require` too.
- **[→ CLAUDE.md — SwiftUI]** For `@State` defaults that depend
  on `@Environment` values (calendar, locale, dismiss action),
  initialize in `.onAppear`, not `init`. `@State` is seeded
  before env injection happens. Pattern: declare as
  `@State var value: T? = nil`, then `.onAppear { if value == nil { value = computeDefault() } }`.
  Applied to `TimerLogSheet`'s minute prefill.
- **[local]** The "service struct + Calendar injection + inline
  instantiation" pattern (`CompletionToggler`, `CompletionLogger`,
  `DefaultStreakCalculator`, `DefaultFrequencyEvaluator`) is now
  the default for "write or read completion-adjacent data." Don't
  reach for a protocol until there's a real substitution need.

## Metrics

- Tasks completed: 7 of 8 (Task 8 polish skipped; addressed
  two review items instead)
- Tests added: 9 (`CompletionLoggerTests`)
- Total test count: 97 → 106 (106/106 green)
- Commits on branch: 11 (3 docs, 6 build, 1 plan notes, 1 review
  fix)
- Files added: 4 source + 1 test + 3 docs
- Files modified: 2 source (HabitRowView, TodayView)
- Net diff: +1,145 / -3 across 10 files (of which ~707 lines are
  plan/research/compound docs)
- Mid-build pivots: 0
- Pre-merge review fixes: 2 (LazyVStack, env-calendar prefill)

## References

- [habit-detail-view compound](../habit-detail-view/compound.md)
  — the parent PR that deferred this scope as "PR B."
- [CompletionToggler](../../../../Kado/Services/CompletionToggler.swift)
  — the pattern this PR's logger mirrors.
- [Stepper](https://developer.apple.com/documentation/swiftui/stepper)
- [swipeActions](https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:))
- [LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack)
- [Swift Testing — #expect](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:))
