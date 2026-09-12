---
name: Counter tap feedback compound
description: Retrospective on giving every quick-log tap a haptic and bringing the count back into the Today row — the iOS-silent SensoryFeedback kinds, the popover that seeds its own state, and the Dynamic Type regression the preview couldn't show
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
ring-only decision from `today-row-actions`. Two deviations from the
plan: the calendar popover keys its haptic on the tap rather than on the
value, and the timer row needed the counter's `ViewThatFits` fallback.
The headline lesson is that the feedback the issue suggested,
`.increase` / `.decrease`, compiles on iOS and never plays — a fact the
SDK's swiftinterface doesn't carry and only Apple's doc page states.

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
- **The popover keys on the tap**: its `Binding` setter is the only
  user-driven path; it computes the feedback and bumps a `stepTick`. See
  Surprises.
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

### A popover that seeds its own state ticks on open

- **What happened**: `DayEditPopover` seeds `counterValue` in
  `.onAppear` (0 → today's value). A haptic keyed on that value — the
  plan's "trigger on whatever the label reads" — would tick every time
  the popover opens, and play `.success` on a day already done.
- **What we did**: key on the tap. The `Binding` setter records the
  feedback for old → new and bumps `stepTick`; one
  `.sensoryFeedback(trigger: stepTick) { stepFeedback }` on the body
  covers both steppers.
- **Lesson**: value-keyed `sensoryFeedback` is only right when the value
  moves *because* of the user. Anything that seeds, syncs or resets the
  value under the view needs a tap-keyed trigger instead.

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

- `QuickLogFeedback` is the single place the haptic rule lives. If a new
  quick-log control appears (a watch complication, a widget intent's
  in-app echo), apply it there; don't add a `.success` edge beside it.
- The Today row keys on `state.valueToday`, so a value that moves under
  the row — CloudKit sync, the midnight rollover — ticks once. The
  `.success` edge already had that exposure. If it is ever reported,
  the plan's Risks section describes the tap-keyed swap; the rule
  doesn't change.
- The popover is tap-keyed **on purpose**; #80 (its stuck display) can
  change the popover's state model without touching the trigger.
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
- **[→ CLAUDE.md]** A value-keyed `.sensoryFeedback` on a view that
  seeds its own `@State` in `.onAppear` ticks on appear. Key such views
  on the tap.
- **[local]** The row's ring-only design is reverted; the count is back
  by decision, not by accident.

## Metrics

- Tasks completed: 5 of 5
- Tests added: 9 (`QuickLogFeedbackTests`)
- Commits: 6 on the branch (plan, four tasks, compound)
- Files touched: 7 (`QuickLogFeedback.swift`, its tests, `HabitRowView`,
  `CounterQuickLogView`, `DayEditPopover`, `Localizable.xcstrings`, the
  plan)

## References

- [#81](https://github.com/scastiel/kado/issues/81) — the report;
  [#80](https://github.com/scastiel/kado/issues/80) — the popover's stuck
  display, same email, separate PR.
- [`SensoryFeedback.increase`](https://developer.apple.com/documentation/swiftui/sensoryfeedback/increase)
  and [`SensoryFeedback.selection`](https://developer.apple.com/documentation/swiftui/sensoryfeedback/selection)
  — the platform notes.
- `docs/plans/2026-04/today-row-actions/compound.md` — the ring-only
  decision this reverses.
