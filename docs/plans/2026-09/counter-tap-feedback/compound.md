---
name: Counter tap feedback compound
description: Retrospective on giving every quick-log tap a haptic and bringing the count back into the Today row — the iOS-silent SensoryFeedback kinds, why a haptic must be keyed on the mutation and not on displayed state, and the Dynamic Type regression the preview couldn't show
type: project
---

# Compound — Counter tap feedback

**Date**: 2026-09-11
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/counter-tap-feedback` · [#85](https://github.com/scastiel/kado/pull/85) · closes [#81](https://github.com/scastiel/kado/issues/81)

## Summary

Every `+` / `−` / `+5m` tap on the four quick-log controls now ticks
(`.selection`), with `.success` kept for the tap that meets the target,
through one tested rule, `QuickLogFeedback`. The Today row shows the
day's count again — `− 3 +`, `12m +5m` — at every value, reversing the
ring-only decision from `today-row-actions`. The big deviation from the
plan came from the code review, after build: keying each control's
haptic on the value it displays was the wrong seam, and the haptic
moved to the **mutation sites** as a `QuickLogEvent`. Two lessons lead:
the feedback the issue suggested, `.increase` / `.decrease`, compiles on
iOS and never plays — a fact only Apple's doc page states — and a
haptic keyed on displayed state fires for every reason that state moves,
of which the user's tap is only one.

## Decisions made

- **`.selection` per tap, `.success` on the edge, one rule**:
  `QuickLogFeedback.feedback(oldValue:newValue:target:)` returns exactly
  one feedback per change, so the two never stack on the tap that meets
  the target. The rule is a pure `nonisolated enum` in the app target;
  `SensoryFeedback` is `Equatable`, so nine cases pin it.
- **All four controls, not just the reported one**: the Today row, the
  detail quick-log and the calendar popover shared the edge-only pattern
  (the popover had nothing). A tap should feel the same wherever it lands.
- **Count always visible, value only**: `− 3 +` reads as the classic
  stepper without explanation; the ring still carries the target
  relation under target and the filled disc says "met" past it. Reverts
  *"drop value/target text; the ring is sufficient"* — the ring
  structurally can't express past-target, which is where the reporter
  was.
- **Presentation only**: `state.valueToday` formatted in the row;
  `HabitRowState` unchanged. Timer minutes floor like the VoiceOver
  phrase so the two never disagree.
- **The haptic is recorded where the value is written**: the mutation
  functions in `TodayView` and `HabitDetailView` read the value before,
  derive the value after from the step they apply, and store a sequenced
  `QuickLogEvent`; one `.quickLogFeedback(_:)` on the `List` / the
  `ScrollView` plays it. `HabitRowView`, `CounterQuickLogView` and
  `DayEditPopover` are display-only. See Surprises for why.
- **The "Log specific value…" sheets keep their own save `.success`**:
  they save through their own logger call, not through the recording
  functions, so a save is one haptic, not two.
- **Timer fallback drops the count, keeps the chip**: at Dynamic Type AX
  sizes `35m +5m` gives way to `+5m` alone. The chip is the action; the
  count is still in `accessibilityValue`.
- **One catalog key, `%lldm` → `%lld min`**: mirrors `+5m` → `+5 min`.
  The counter's number uses `Text(_:format:)` and needs no key.

## Surprises and how we handled them

### `.increase` / `.decrease` are silent on iOS

- **What happened**: the issue proposed
  `.sensoryFeedback(.increase, trigger:)`. The SDK declares every
  `SensoryFeedback` kind `@available(iOS 17.0, …)`, and the
  swiftinterface strips doc comments, so nothing at compile time says
  otherwise. Apple's doc page for each kind does: *"Only plays feedback
  on watchOS and visionOS."*
- **What we did**: fetched the per-kind doc pages before planning
  (`SensoryFeedback/increase`, `/selection`) and used `.selection`,
  whose page reads *"Only plays feedback on iOS and watchOS."*
- **Lesson**: haptic kinds are a per-platform table, not an availability
  annotation. Check the doc page for the kind, not the SDK.

### The value the control displays is the wrong trigger

- **What happened**: the build keyed each control's haptic on the value
  it shows (`state.valueToday`, `todayValue`), as the plan said. The
  first crack showed during build: `DayEditPopover` seeds its value in
  `.onAppear`, so it would have ticked on open — patched locally with a
  tap counter. The review then found the same fault everywhere else, in
  four shapes: a new day zeroes every row's value on the first
  foreground → N ticks on launch (the old `.success` edge never fired on
  value → 0, so this was a regression, not the "same exposure" the plan
  claimed); a not-scheduled row that gets logged moves to the other
  `ForEach`, a new identity that sees no old → new → the first tap on it
  was silent, the very #81 class; a popover step on today also moved the
  quick-log control's value → two haptics; and the log sheets stacked
  their save `.success` on the row's tick.
- **What we did**: hoisted the haptic to the mutation sites. They know
  `(old, new, target)` exactly — the step is a fixed `+1`, `−1` floored
  at zero, `+300`, or the explicit value — so each records a sequenced
  `QuickLogEvent` and one `.quickLogFeedback(_:)` on a stable ancestor
  plays it. Every control-level haptic went away, the popover patch
  included (it is byte-identical to `main` again).
- **Lesson**: a haptic answers *"did my tap land?"*, so it must be keyed
  on the tap. Displayed state moves for many reasons — seed, rollover,
  sync, container swap, a re-created row — and a trigger on it can't
  tell them apart. Record the event where the write happens.

### The Dynamic Type regression the preview couldn't show

- **What happened**: the `"Dynamic Type XXXL"` preview holds a binary
  and a counter row — no timer. At AX3 on the simulator the timer row's
  `35m` and `+5m` chip both wrapped mid-token (`35 / m`, `+5 / m`),
  because the count now shares the trailing space with the chip.
- **What we did**: gave the timer trailing the counter's `ViewThatFits`
  (`35m +5m`, then the chip alone) and `.fixedSize(horizontal:)` on the
  count so it can never split. Verified at AX3 and AX5 with
  `xcrun simctl ui <udid> content_size accessibility-extra-large` /
  `accessibility-extra-extra-extra-large`, then reset to `large`.
- **Lesson**: a Dynamic Type preview only covers the row types you put
  in it. The simulator's content size is settable from the shell even
  though the run tools can't set it, and a seeded launch plus one
  screenshot per size is a two-minute check.

## What worked well

- **A pure rule with nine tests** for a six-line function. It pins the
  "no double haptic on the edge" invariant, which no preview or
  simulator run can hear.
- **The screenshot seed as the pixel-check dataset**: launching with
  `-uiTestRun -uiTestResetState -uiTestSeedProduction
  -uiTestSeedForScreenshots` gives a counter mid-fill and an unlogged
  timer on a fresh simulator. Bumping the seed's today values locally
  (12 / 2100s) and `git checkout`-ing them back showed the complete and
  over-target rows without tap primitives.
- **`ViewThatFits` as the one answer for large text** — the counter had
  it; the timer just needed the same shape.

## For the next person

- `QuickLogFeedback` is the single place the haptic rule lives, and
  `QuickLogEvent.next(after:type:oldValue:newValue:)` is how a mutation
  reports itself. A new quick-log path (a watch action, an intent's
  in-app echo) records an event in the function that writes the value;
  it does **not** put a `.sensoryFeedback` on the control.
- The value *after* is derived from the step, never read back: after
  `context.delete` the relationship can still hold the record until the
  save lands, so a read-back would say `1` where the user sees `0`.
- The binary / negative toggles still key `.success` on `state.status`
  in `HabitRowView` — untouched by this PR, and they carry the same
  rollover exposure (a completed row goes `.complete → .none` on the
  first foreground of a new day). Moving toggles onto the same event is
  a small follow-up; it needs a decision on what un-ticking plays.
- `DayEditPopover` is untouched relative to `main`; #80 can restructure
  it freely.
- The count label is `.fixedSize(horizontal:)`. It's short by nature; if
  a count ever reaches four digits at AX5 it overflows rather than wraps,
  which is the right failure.
- VoiceOver output is unchanged (`Drink water, counter, target 8` /
  `3 of 8, streak 2, score 55 percent`): the row is one combined element
  with an explicit label and value, and the new `Text` never reaches
  the screen reader on its own.
- Haptics can't be verified on a simulator. The rule is tested; the
  wiring is one modifier per control; one on-device pass is still owed
  before the PR leaves draft.
- The App Store Today captures now show counter rows without a count.
  Re-run `make screenshots` with the next listing refresh.
- Seen at AX sizes, pre-existing, not touched here: the binary checkmark
  glyph overflows its 28pt circle, the "Slipped" pill breaks into three
  lines at AX5, and the habit name is a fixed 15pt system font. Worth an
  issue of their own.

## Generalizable lessons

- **[→ CLAUDE.md]** `SensoryFeedback` kinds are a per-platform table,
  not an availability annotation: `.increase`, `.decrease`, `.start`,
  `.stop` and `.pathComplete` compile on iOS and never play; `.selection`,
  `.impact`, `.success`, `.warning`, `.error` do. The swiftinterface
  strips the note — read the kind's doc page.
- **[→ CLAUDE.md]** Set Dynamic Type on a simulator with
  `xcrun simctl ui <udid> content_size <size>` (`accessibility-extra-large`
  is the preview's `.accessibility3`; `accessibility-extra-extra-extra-large`
  is the ceiling; `large` is default). XcodeBuildMCP can't set it, and a
  preview only covers the row types it holds.
- **[→ CLAUDE.md]** Key a tap haptic on the **mutation**, not on the
  state a control displays. `.sensoryFeedback(trigger: displayedValue)`
  fires on seed-on-appear, the day rollover, a CloudKit sync, a
  container swap, and misses a tap that re-creates the view (a row moving
  between `ForEach`es). Pattern: the function that writes records a
  sequenced event in `@State`; one `.sensoryFeedback(trigger:)` on a
  stable ancestor plays it (`QuickLogEvent` / `.quickLogFeedback(_:)`).
- **[→ CLAUDE.md]** Run `/code-review` before the on-device check, not
  after. It found four wiring faults in a build that had green unit and
  UI suites and a clean screenshot pass — none of which can see a haptic.
- **[local]** The row's ring-only design is reverted; the count is back
  by decision, not by accident.

## Metrics

- Tasks completed: 5 of 5, plus one review pass
- Tests added: 12 (`QuickLogFeedbackTests`)
- Commits: 7 on the branch (plan, four tasks, compound, review fix)
- Files touched: 9 (`QuickLogFeedback.swift`, its tests, `HabitRowView`,
  `CounterQuickLogView`, `TodayView`, `HabitDetailView`,
  `CompletionLogger`, `Localizable.xcstrings`, the plan)

## References

- [#81](https://github.com/scastiel/kado/issues/81) — the report;
  [#80](https://github.com/scastiel/kado/issues/80) — the popover's stuck
  display, same email, separate PR.
- [`SensoryFeedback.increase`](https://developer.apple.com/documentation/swiftui/sensoryfeedback/increase)
  and [`SensoryFeedback.selection`](https://developer.apple.com/documentation/swiftui/sensoryfeedback/selection)
  — the platform notes.
- `docs/plans/2026-04/today-row-actions/compound.md` — the ring-only
  decision this reverses.
