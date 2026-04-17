---
# Research — Today View

**Date**: 2026-04-17
**Status**: draft
**Related**: [ROADMAP v0.1 — Views](../../../ROADMAP.md), [swiftdata-models compound](../swiftdata-models/compound.md), [habit-score-calculator compound](../habit-score-calculator/compound.md)

## Problem

v0.1 needs a working Today tab: the user opens the app, sees the
habits due today, taps one to mark it complete, feels a haptic. This
is the app's daily touchpoint — every other flow is secondary.

Persistence (HabitRecord / CompletionRecord), frequency evaluation,
and score calculation all exist as services. Nothing consumes them in
a view yet. The current `TodayView` is a `ContentUnavailableView`
placeholder.

Constraints framing the solution:

- **No create-habit flow yet**. Either this PR stubs one, or the app
  is unusable in production until the next PR.
- **Four `HabitType`s**: binary, counter, timer, negative. v0.1
  roadmap says "tap to complete" — binary is obvious, the others need
  a decision.
- **CLAUDE.md**: "prefer `@Query` in simple views, explicit
  descriptor + fetch in services for complex logic." Today leans
  "simple view" if the filtering logic stays local.

## Current state of the codebase

What exists:

- [HabitRecord](../../../../Kado/Models/Persistence/HabitRecord.swift) —
  `@Model`, `snapshot: Habit` projection, `completions` relationship.
- [CompletionRecord](../../../../Kado/Models/Persistence/CompletionRecord.swift) —
  `@Model`, parent `habit: HabitRecord?`, `snapshot: Completion`.
- [DefaultFrequencyEvaluator](../../../../Kado/Services/DefaultFrequencyEvaluator.swift) —
  `isDue(habit:on:completions:)`, calendar-aware, handles all four
  `Frequency` cases.
- [DefaultHabitScoreCalculator](../../../../Kado/Services/DefaultHabitScoreCalculator.swift) —
  `currentScore(...)`, `scoreHistory(...)`. Not needed for v0.1 Today
  row, but useful later.
- [EnvironmentValues+Services](../../../../Kado/App/EnvironmentValues+Services.swift) —
  registers `habitScoreCalculator` via `EnvironmentKey`. Pattern for
  adding `frequencyEvaluator`.
- [PreviewContainer](../../../../Kado/Preview%20Content/PreviewContainer.swift) —
  seeds 5 habits (one of each type combo) with partial completion
  history. Previews can rely on it.
- [KadoApp](../../../../Kado/App/KadoApp.swift) —
  wires the file-backed `ModelContainer` via `.modelContainer(_:)`.

What's missing:

- `frequencyEvaluator` in `EnvironmentValues`.
- Any way to insert a `HabitRecord` from the UI.
- Anywhere that reads a `ModelContext` from within a view.
- A row component for a habit.
- Haptic wiring.

## Proposed approach

Single PR, strictly the Today list + tap-to-complete for **binary
and negative** habits. Counter/timer rows render but tap opens a
"Not yet — opens in habit detail" behavior (we'll wire properly once
the detail view lands). Create-habit and habit-detail each get their
own PR next.

### Key components

- **`TodayView`** (rewritten): `@Query` fetches active `HabitRecord`s
  (predicate: `archivedAt == nil`, sorted by `createdAt`); computed
  property uses `FrequencyEvaluator` to filter to "due today";
  renders a `List` of rows. Uses `@Environment(\.modelContext)` for
  inserts/deletes, `@Environment(\.frequencyEvaluator)` for filtering,
  and `@Environment(\.calendar)` for day arithmetic.
- **`HabitRowView`** (new, in `UIComponents/`): takes a `HabitRecord`,
  displays name + type-specific state (checkmark for binary/negative,
  "x/y" for counter, "mm:ss / target" for timer), tap action
  closure. `.sensoryFeedback(.success, trigger:)` on the completion
  count so haptic fires on insert.
- **`frequencyEvaluator` environment key**: mirror of existing
  `habitScoreCalculator`. Added to `EnvironmentValues+Services.swift`.
- **Empty state**: `ContentUnavailableView` with a "Create habit"
  button. In this PR the button is wired to a **disabled** action
  with a TODO comment pointing at the next PR. Keeps the UI truthful
  without bloating scope.

### Data flow for "tap to complete" (binary)

1. User taps row.
2. Row fires closure: `complete(habit:)`.
3. `TodayView` creates a `CompletionRecord(date: .now, value: 1, habit: habit)`
   and inserts into `modelContext`. `try? modelContext.save()` — or
   let SwiftData autosave.
4. `@Query` re-runs on the context change; the row sees an updated
   `today's completion` count and renders checked.
5. `.sensoryFeedback` observes the count and fires `.success`.

**Undo**: tap a completed binary habit today → find today's
completion, delete it. Same path in reverse.

### Data model changes

None. All `@Model` shapes stay as-is.

### UI changes

- Replace `TodayView` body.
- Add `HabitRowView`.
- Add `frequencyEvaluator` environment key.
- Leave `ContentView` tab shell untouched.

### Tests to write

Unit tests (Swift Testing, in-memory `ModelContainer`, no
`@MainActor` required for the pure logic):

```swift
@Test("Today list contains only non-archived habits that are due today")
@Test("Toggling a binary habit inserts a completion with value 1 dated today")
@Test("Toggling a binary habit that's already done today deletes today's completion")
@Test("Counter/timer habits are listed but tap does nothing (stub)")
@Test("An archived habit is not listed")
@Test("A habit with .specificDays frequency not matching today is not listed")
```

If we extract the toggle logic into a small helper (e.g.
`TodayCompletionToggler` or a `TodayViewModel.toggle(habit:)`), tests
land on the helper rather than the SwiftUI view. Leaning toward
**not** adding a ViewModel — the logic is ~10 lines and fits in the
view cleanly. Tests instead target a free function
`toggleBinary(habit:on:in:)` in a new `Services/` file.

UI-level: previews cover the list with `PreviewContainer.shared`,
plus an empty-state preview with an empty in-memory container.

## Alternatives considered

### Alternative A: Full counter/timer interaction in this PR

- Idea: Counter = `+1` tap increments today's completion value; timer
  = tap starts a session, tap-to-stop logs elapsed seconds.
- Why not: Timer especially needs persistent state across app
  backgrounding — that's a Live Activities / ActivityKit concern, v0.3
  scope. Counter could be done but forces a UX decision (overshoot?
  long-press to set explicit value?) that belongs with the detail
  view. Deferring keeps the PR honest.

### Alternative B: Introduce a `@Observable TodayViewModel`

- Idea: Move fetch + filter + toggle logic into a class,
  `TodayView` becomes a thin renderer.
- Why not: `@Query` already provides the reactive fetch. The filter
  is a 3-line computed property. The toggle is a 5-line function.
  A ViewModel here is structure for structure's sake. CLAUDE.md
  explicitly says simple views can skip them.

### Alternative C: Stub the "Create habit" flow in this PR

- Idea: Add a minimal sheet with just a name field, default
  `.daily` / `.binary`. Lets the user exit the empty state.
- Why not: Even a "minimal" new-habit form has decisions (icon
  picker? color? frequency UI?) that belong in their own research
  pass. This PR stays focused; next PR is "New Habit MVP."
- Mitigation: ship this PR with `PreviewContainer` still driving
  previews; production empty state shows the disabled button plus a
  reassuring "Coming in the next update" (or just a greyed-out
  button — we'll decide during build).

### Alternative D: Predicate-level "is due" filter in `@Query`

- Idea: Push the filter into the `#Predicate` so `@Query` returns
  only due habits.
- Why not: `FrequencyEvaluator`'s `.daysPerWeek` case needs a
  7-day lookback over completions — not expressible in SwiftData's
  predicate macro. The predicate can only do `archivedAt == nil` and
  maybe a `createdAt` bound. In-memory filter is the right layer.

## Risks and unknowns

- **`@Query` + `#Predicate` quirks on Xcode 26**: the bootstrap
  project already works with `@Query` in the preview, but this will
  be the first runtime use of `#Predicate`. If it hits a toolchain
  bug (echoing the composite-Codable-enum crash from the persistence
  PR), fall back to `@Query(sort: ...)` unfiltered + filter all
  habits in memory (filter-out archived at the same time as filter-
  for-due). Cost: marginal at ≤50 habits, which is v0.1's scale.
- **Sensory feedback timing**: `.sensoryFeedback` observes a trigger
  value. If the trigger is the completion row's "is done today"
  boolean, it fires on both completion AND un-completion. Probably
  desirable (user gets haptic on undo too). If not, trigger on the
  count of today's completions with a guard.
- **Daily rollover**: the view binds to `.now` at render time; if the
  app is kept open past midnight, the list doesn't refresh. For
  v0.1 this is fine (user relaunches in the morning). Worth a note;
  fix with a `Timer.publish` or `ScenePhase` observer later.
- **Archive filter correctness**: `#Predicate` with `archivedAt == nil`
  on an optional Date — confirm predicate syntax during build.
- **MainActor isolation**: `TodayView` body runs on MainActor
  (SwiftUI default). `FrequencyEvaluator` is `Sendable`, so calling
  it synchronously is fine.

## Open questions

- [ ] **Counter/timer rows**: render as read-only ("coming in habit
  detail") or entirely hidden from Today until detail view lands?
  *Recommendation*: render as read-only — the user should see their
  full set of habits even if not all are interactive yet.
- [ ] **Toggle semantics for binary habits already done today**: tap
  again to un-do, or require swipe-to-delete? *Recommendation*: tap
  again to un-do (matches Loop, Streaks).
- [ ] **Empty-state button**: disabled with a "Coming soon" hint, or
  fully hidden (just the icon + text)? *Recommendation*: visible but
  disabled, so the next PR wiring it is a 2-line change.
- [ ] **Row visual density**: full row with icon + name + state, or
  compact "checklist" style? *Recommendation*: full row for v0.1;
  revisit once we have icons and colors (post-v0.1).
- [ ] **Score on the row**: show current score as a small badge, or
  reserve it for the detail view? *Recommendation*: detail view
  only. Keep Today's row purely about today's state.

## References

- [SwiftData @Query](https://developer.apple.com/documentation/swiftdata/query)
- [SwiftData #Predicate](https://developer.apple.com/documentation/foundation/predicate)
- [SwiftUI .sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
- [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- Prior-art UX: Streaks (tap-to-toggle), Loop Habit Tracker (checkbox list), (Not Boring) Habits (animated row)
