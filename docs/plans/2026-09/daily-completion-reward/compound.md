---
name: Daily completion reward compound
description: Retrospective on the confetti-on-all-done moment and the lock-screen day-progress ring — why the edge is detected in the snapshot funnel, and what the UI test had to work around
type: project
---

# Compound — Daily completion reward

**Date**: 2026-09-09
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/daily-completion-reward`

## Summary

Shipped two things: a confetti burst with an "All done for today"
caption the moment the last habit scheduled for today is completed,
and a second circular lock-screen widget, "Daily Progress", showing
*completed / scheduled* as a closing ring. The build followed the plan
without a pivot. The headline lesson is architectural: a behaviour
that must react to "any completion, from anywhere" belongs at the one
call every mutation already makes — here `WidgetSnapshotBuilder.rebuildAndWrite`
— not in the view that happens to own the tap.

## Decisions made

- **One all-done rule, `DayProgress.isComplete`**: the confetti, the
  review-prompt milestone and the widget ring all read it, and all
  agree that a day with nothing scheduled is not a finished one. The
  Today milestone check used `allSatisfy` over a possibly-empty list
  and was quietly wrong on rest days; it now goes through the same
  type.
- **Detect the edge in the snapshot funnel**: `rebuildAndWrite` runs
  after every save from every surface — views via `WidgetReloader`,
  the intents directly, the app at launch and at the day edge — and
  already computes the two counts. Feeding a tracker there covers Siri
  and the Detail screen for free and is independent of `@Query`
  timing.
- **Tracker fires only on a same-day incomplete→complete edge**: the
  first observation and any change of logical day are baselines.
  Moving the day-start hour can relabel the current day as a finished
  yesterday, and a dev-mode swap lands on a different store; neither
  is a tick. The day-edge task in `KadoApp` reports the fresh day
  first, which is what makes "first tick of the new day" celebrate.
- **Replay on re-tick, no once-per-day gate**: un-ticking and
  re-ticking is the user's doing, and a habit added after the first
  celebration deserves a second when it is done. A persisted gate is a
  ten-line addition if it turns out to be wanted.
- **Overlay on `ContentView`, not Today**: a completion from Detail,
  from the Overview popover, or from an intent should celebrate on the
  screen the user is looking at.
- **`Canvas` + closed-form motion for the confetti**: no SpriteKit, no
  simulation state; every particle is a function of elapsed time, the
  set comes from a seeded generator, and the whole thing is ~150
  lines that preview.
- **No extra haptic**: the row control already fires `.success`; a
  second buzz on top would read as a bug.
- **A new widget `kind`, not a change to the per-habit ring**: users
  who configured `LockCircularWidget` keep it; the gallery lists both.
- **`.accessoryCircularCapacity`** for the ring: the style built for
  "N of M", system-drawn, so it adapts to vibrant and tinted lock
  screens without routing through `WidgetPalette`.

## Surprises and how we handled them

### `#expect` cannot call a mutating method

- **What happened**: `#expect(tracker.record(done, on: day))` fails to
  compile — the macro captures its operands, and `record` is
  `mutating` on a captured `var`.
- **What we did**: bind each result to a `let` first.
- **Lesson**: any Swift Testing assertion over a mutating call needs
  the intermediate constant; the error message names `$0` and is not
  obviously about the macro.

### XCUITest cannot reach a row's pill

- **What happened**: `HabitRowView` collapses to one accessibility
  element, so the check circle has no element of its own, and the
  "Mark as done" custom action is invisible to XCUITest.
- **What we did**: tap the row at a normalised offset (`dx: 0.92`),
  which lands on the trailing 28pt circle on both phone widths.
- **Lesson**: coordinates are the only handle on controls inside a
  combined row. If this becomes common, an unmerged identifier on the
  control would be the cleaner seam — at the cost of the single-element
  VoiceOver reading the rows deliberately have.

### Seeing a three-second animation without a tap primitive

- **What happened**: XcodeBuildMCP can build and screenshot but cannot
  tap, so the confetti could not be triggered from the tooling.
- **What we did**: the UI test captures a screenshot mid-burst as an
  attachment, exported with
  `xcrun xcresulttool export attachments --path <run>.xcresult --output-path <dir>`;
  `manifest.json` maps names to files. That picture is what caught the
  particles being a touch small on a 3× screen.
- **Lesson**: for any transient visual, the UI suite is both the
  regression test and the camera.

## What worked well

- **Research first paid off in one specific way**: mapping every
  `WidgetReloader.reloadAll` call site made the funnel choice obvious,
  and the edge-only tracker design fell out of listing the non-user
  paths (launch, day edge, day-start change, dev swap) as test cases
  before writing code. All eight tracker tests passed on the first
  compile of the implementation.
- **Value types all the way down**: `DayProgress` and
  `DayCompletionTracker` are `nonisolated` structs, so the suite runs
  them without a container or an actor hop, and the `@Observable`
  wrapper is four lines.
- **Both UI tests passed first run**, including the "touches pass
  through the overlay" case, which is the one most likely to regress
  if someone later wraps the overlay in a container that eats hits.

## For the next person

- `DayCompletionCelebration.shared` is fed from `rebuildAndWrite`.
  If you add a mutation path that writes completions **without**
  going through `WidgetReloader.reloadAll` or that call, the widgets
  go stale *and* the celebration misses it — the two failures travel
  together, which is deliberate.
- Before swapping the model container, call
  `DayCompletionCelebration.shared.reset()`. `KadoApp` does for dev
  mode; a future "restore from backup into a fresh store" should too.
- The tracker compares logical days by `==` on the anchor
  `DayBoundary.startOfDay(for:)` returns. Feed it that anchor, not
  `.now`.
- `ConfettiView.duration` is the single knob for how long the overlay
  stays; the modifier's `.task(id:)` timer reads it.
- The caption's identifier (`celebration.caption`) is the UI suite's
  only seam. Keep the caption an accessibility element even if the
  visual changes.
- The widget target is pinned to iOS 26.4 while the app is 18.0; the
  ring uses nothing newer than iOS 16 APIs, but that gap is where a
  future "works in preview, fails in the app" would come from.
- The `.accented` / `.vibrant` lock-screen renderings cannot be seen
  from the simulator suite (see the widget-colours section of
  `CLAUDE.md`). Add the ring to a real lock screen and check Clear and
  Tinted before a release.

## Generalizable lessons

- **[→ CLAUDE.md, Testing]** In Swift Testing, `#expect` cannot wrap
  a call to a `mutating` method on a local `var` — bind the result to
  a constant first. The error ("cannot use mutating member on
  immutable value: '$0'") does not mention the macro.
- **[→ CLAUDE.md, UI tests]** Controls inside a row collapsed with
  `.accessibilityElement(children: .combine)` are unreachable by
  identifier from XCUITest, and so are custom accessibility actions.
  Tap by normalised coordinate on the row, and document the offset.
- **[→ CLAUDE.md, UI tests]** To see a transient visual from a
  headless run, `capture(app, name)` in the test and export with
  `xcrun xcresulttool export attachments`; the manifest maps names to
  files.
- **[→ CLAUDE.md, Architecture]** When a behaviour must respond to
  "any mutation, from any surface", hook the funnel every mutation
  already passes through (`WidgetSnapshotBuilder.rebuildAndWrite`)
  rather than each view's action methods — and make the reaction a
  pure, tested edge detector so non-user rebuilds (launch, day edge,
  settings, store swaps) are baselines by construction.
- **[local]** Replay-on-re-tick rather than once-per-day is a product
  choice; revisit if a user reports confetti fatigue.

## Metrics

- Tasks completed: 7 of 7
- Tests added: 13 unit (`DayProgressTests`, `DayCompletionTrackerTests`),
  2 UI (`DayCompletionCelebrationTests`)
- Commits: 9 on the branch
- Files touched: 20 (5 new source, 3 new test, 2 catalogs, 3 docs)

## References

- [`Gauge` accessory styles](https://developer.apple.com/documentation/swiftui/gaugestyle/accessorycircularcapacity)
- [`Canvas`](https://developer.apple.com/documentation/swiftui/canvas)
- [`xcresulttool`](https://developer.apple.com/documentation/xcode/analyzing-the-result-bundle) — `export attachments`
- Prior widget work: [widgets compound](../../2026-04/widgets/compound.md)
