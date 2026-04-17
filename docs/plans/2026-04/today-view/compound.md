---
# Compound — Today View

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/today-view](https://github.com/scastiel/kado/pull/4)

## Summary

Wired the Today tab to real `HabitRecord` data: `@Query` for active
habits, in-memory filter through the injected `FrequencyEvaluator`,
full-row rendering for every `HabitType`, and tap-to-toggle for
binary/negative via a small `CompletionToggler` helper.
`.sensoryFeedback(.success, trigger:)` handles haptics. Counter and
timer rows ship read-only until the habit detail view lands.
**Headline: the plan landed almost verbatim — research's 5-question
pre-plan conversation front-loaded the design decisions so no
surprises surfaced during build. The `#Predicate` fallback wasn't
needed; the toolchain cooperated.**

## Decisions made

- **No ViewModel**: `@Query` + computed properties + a 3-line toggle
  helper are enough. Tests target the helper, previews cover
  rendering. CLAUDE.md's "simple views can skip them" applies here.
- **In-memory filtering** for "due today". `FrequencyEvaluator.isDue`
  needs the habit's completions for `.daysPerWeek` rolling-window
  logic, which isn't expressible in `#Predicate`'s macro.
- **Full-row layout** with leading state indicator + name +
  type-specific trailing label. Standard `List`-row pattern.
- **Tap-to-toggle for binary/negative, no-op for counter/timer**:
  scope discipline. Counter/timer need detail-view input
  affordances that don't exist yet; showing them read-only beats
  faking interaction.
- **`.sensoryFeedback(.success, trigger: isCompletedToday)` on the
  outer row**: fires on both true→false and false→true transitions
  — tactile confirmation on tap AND undo, which is the desired UX.
- **`CompletionToggler` as a concrete `@MainActor struct`, no
  protocol**: tests use an in-memory `ModelContainer` directly,
  there's no substitution need. If one appears later, refactor
  then.
- **Empty state stays text-only** (no "Create habit" button). A
  disabled button in production would teach users a lie; the next
  PR adds it when it's real.
- **Three view states**: empty (no habits), "nothing due today"
  (habits exist but none scheduled), and populated. Separate
  `ContentUnavailableView` copy for the first two.
- **`frequencyEvaluator` environment key alongside
  `habitScoreCalculator`**: mirrors the existing pattern, no new
  conventions introduced.
- **Preview helpers on `PreviewContainer`**: `emptyContainer()` and
  `noneDueTodayContainer()` for state coverage in `TodayView`
  previews, reusing the single preview-container construction path.

## Surprises and how we handled them

### XcodeBuildMCP destination flakiness

- **What happened**: `test_sim` and `build_run_sim` intermittently
  failed with `Unable to find a destination matching { platform:iOS Simulator, OS:latest, name:iPhone 17 Pro }`
  even though `xcrun simctl` showed the sim booted on iOS 26.4 and
  `xcodebuild -showsdks` confirmed the simulator SDK was installed.
  The error message cited the *device* SDK: "iOS 26.4 is not
  installed." xcodebuild appears to walk all scheme destinations
  and bail out when device-side resolution fails — the missing iOS
  26.4 *device* SDK (we only have the simulator SDK) poisons
  destination resolution even though builds only need the
  simulator.
- **What we did**: shut down all simulators with
  `xcrun simctl shutdown all`, rebooted iPhone 17 Pro, reran.
  Sometimes also required cleaning DerivedData. After the reset,
  `test_sim` ran green (64/64). No source-level fix.
- **Lesson**: when XcodeBuildMCP's `test_sim` / `build_run_sim`
  returns an "OS:latest … not installed" destination error despite
  the sim being booted and the simulator SDK being present, the fix
  is environmental, not code-level. Reboot the sim before retrying.

### The production container starts empty — live tap-testing blocked

- **What happened**: `KadoApp` uses a file-backed `ModelContainer`
  with no onboarding/seed path. Launching the app on the simulator
  shows the empty state correctly but leaves no way to manually
  verify the tap-to-toggle flow.
- **What we did**: relied on unit tests (`CompletionTogglerTests`,
  5 cases covering insert/delete/idempotency/DST) + SwiftUI
  previews (4 row permutations × 2 done-states + 3 view-level
  states). Documented the gap in plan notes. End-to-end manual
  verification waits for the Create-habit PR.
- **Lesson**: when a persistence-consuming view lands before its
  data-creation flow, unit-test + preview coverage can substitute
  for live simulator testing — but the gap deserves an explicit
  note in the PR so it doesn't get forgotten.

### `#Predicate<HabitRecord> { $0.archivedAt == nil }` worked first try

- **What happened**: I planned a fallback (unfiltered `@Query` +
  in-memory archive filter) in case SwiftData's `#Predicate` macro
  balked at comparing an optional `Date` to `nil`. It didn't balk.
- **What we did**: kept the `#Predicate` path, removed the fallback
  task from scope.
- **Lesson**: The SwiftData-on-Xcode-26 composite-Codable-enum
  crash (from the previous PR) biased me toward over-planning
  around toolchain quirks. `#Predicate` with optional-to-nil is
  well-supported and wasn't worth hedging against. Next time, one
  5-minute smoke test up front would settle it.

## What worked well

- **Front-loading design decisions in research**: the 5-question
  pre-plan conversation (counter/timer rendering, undo semantics,
  empty-state button, row density, score-on-row) resolved in ~2
  minutes each because the options were framed with recommendations
  up front. Zero decisions got relitigated during build.
- **TDD on `CompletionToggler`**: writing 5 red tests before any
  implementation surfaced a DST test case I hadn't initially
  planned, and the implementation went green first try. The
  Europe/Paris calendar test is the kind of regression guard that
  would cost hours to debug if it ever broke silently.
- **Plan's "notes during build" section**: gave me a dedicated spot
  to record the flaky-sim workaround and the predicate-fallback
  non-event as they happened, which fed this compound directly with
  zero re-derivation.
- **Reusing `PreviewContainer` for state-specific helpers**: adding
  `emptyContainer()` and `noneDueTodayContainer()` beside the
  existing `.shared` kept preview wiring centralized. Previews
  stayed one-liners.
- **`Group { if onTap { Button … } else { rowContent } }`**: one
  view expression renders the interactive-vs-read-only distinction
  cleanly, and accessibility labels/hints attach to the whole
  thing. Beats two parallel implementations.

## For the next person

- **The Today list doesn't refresh past midnight** while the app is
  open — `Date.now` is only re-evaluated on render. Fix with a
  `ScenePhase` observer when it starts mattering (likely after
  v0.1).
- **Counter/timer rows are intentionally tap-inert.** Trailing
  labels show only the target ("`–/8`", "`30:00`"), not the actual
  today value, because there's no path to create counter/timer
  completions until the habit detail view ships. When the detail
  view lands, wire today's completion value through to the row
  (either pass `todayValue: Double?` to `HabitRowView`, or rethink
  the row as a protocol over the habit record).
- **`CompletionToggler` is `@MainActor` by necessity** —
  `ModelContext` mutations need main-actor isolation. Don't try to
  move it off-main "for responsiveness"; the operations are
  millisecond-scale.
- **`@Query(filter: #Predicate<HabitRecord> { $0.archivedAt == nil })`
  compiled and ran first-try on Xcode 26 / iOS 18.4**. If you add
  new predicate clauses, smoke-test them; the persistence-layer
  compound warned that the macro has surprising edges.
- **`.sensoryFeedback` observes the `isCompletedToday` boolean**,
  not an event. That means both toggle directions fire the haptic.
  If you want tap-only haptic, switch to
  `.sensoryFeedback(trigger: isCompletedToday) { old, new in new }`
  and guard. Don't switch without thinking about it — two-way
  haptic is the current intentional UX.
- **Empty state copy in `TodayView`** has two variants: "No habits
  yet" (no habits at all) and "Nothing due today" (habits exist but
  none scheduled for today). When adding archived-vs-deleted
  logic later, don't collapse these — they answer different user
  questions.
- **Adding a new `@Model` or environment service**: follow the
  pattern in `EnvironmentValues+Services.swift` (one file is the
  single registry for environment keys). Add both the key and the
  computed property in the same commit.

## Generalizable lessons

- **[→ CLAUDE.md]** When XcodeBuildMCP's `test_sim` or
  `build_run_sim` fails with "Unable to find a destination matching
  …OS:latest… not installed" despite the simulator being booted and
  its SDK installed, the cause is usually xcodebuild's
  whole-scheme destination walk choking on a missing *device* SDK.
  Workaround: `xcrun simctl shutdown all && xcrun simctl boot
  "iPhone 17 Pro"`, then retry. Cleaning DerivedData helps
  occasionally. No source fix.
- **[→ CLAUDE.md]** A "simple SwiftUI view" is one where `@Query`
  + small computed properties + inline actions cover the logic. If
  business logic needs a helper, extract it as a free struct with
  injected `Calendar` (pattern: `CompletionToggler`), not a
  `@Observable` ViewModel. The ViewModel threshold: state the view
  itself must mutate outside of `@Query`-driven updates, or shared
  state across multiple views.
- **[→ CLAUDE.md]** When a toolchain quirk bit us once (SwiftData
  composite-Codable-enum crash), don't reflex-hedge every similar-
  sounding risk on the next feature. Validate with a 2-minute
  smoke test before baking a fallback into the plan. Planning
  overhead has a cost too.
- **[local]** Pre-plan resolution of open questions via a
  recommendation-first conversation (5 questions, ~10 min total) is
  a high-ROI pattern on feature-scale work. Candidate for the
  conductor skill's docs if it proves out over 2-3 more features.

## Metrics

- Tasks completed: 5 of 6 (Task 6 intentionally skipped — nothing
  to polish)
- Tests added: 5 (`CompletionTogglerTests`)
- Total test count: 59 → 64 (64/64 green)
- Commits on branch: 10 (3 docs, 5 build, 2 plan updates)
- Files added: 2 source + 1 test + 3 docs
- Files modified: 3 source + 0 test
- Net diff: +944 / -7 across 8 files (of which +506 lines are the
  three plan/research/compound docs)
- Mid-build pivots: 0 (plan landed verbatim)
- Plan revisions during build: 0

## References

- [@Query](https://developer.apple.com/documentation/swiftdata/query)
- [#Predicate](https://developer.apple.com/documentation/foundation/predicate)
- [.sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:))
- [ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview)
- [PR #3 compound — SwiftData persistence layer](../swiftdata-models/compound.md) — the layer this PR consumes.
- [PR #2 compound — habit score calculator](../habit-score-calculator/compound.md) — source of the concurrency / Calendar conventions applied here.
