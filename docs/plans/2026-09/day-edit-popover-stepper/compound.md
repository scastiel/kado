# Compound — Day-edit popover stepper freezes after the first tap

**Date**: 2026-09-11
**Status**: complete
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `fix/day-edit-popover-stepper` ·
[#83](https://github.com/scastiel/kado/pull/83) · fixes
[#80](https://github.com/scastiel/kado/issues/80)

## Summary

The plan set out to fix a popover that kept a local copy of a value
and froze. The reproduction found the copy was fine and the value it
was handed was stale: **the whole habit detail screen had stopped
re-rendering on value-only saves** since the #63 fix, and only inserts
and deletes woke it up. The quick-log on the same screen had the same,
unreported freeze. The fix gives `HabitDetailView` its own `@Query`
and resolves every record it mutates from that array — `TodayView`'s
shape — and the stateless popover from the plan ships on top as
hygiene. Headline lesson: the plan's "smoke-test the load-bearing
assumption" step is what turned a wrong fix into the right one.

## Decisions made

- **A view that mutates SwiftData records holds its own `@Query` and
  resolves them from it; never a `fetch` in the mutation path.** Both
  halves were measured: the `@Query`'s presence is what makes the
  loader re-render on a save, and a fetch between the tracked read and
  the mutation leaves the observer un-notified for the same instance.
- **Delete `ModelContext.habitRecord(id:)` / `completionRecord(id:)`.**
  No callers left, and the helper's own doc comment recommended the
  shape that caused this.
- **`CompletionHistoryList` hands deletion up through `onDelete`**
  rather than resolving a record itself, so resolution lives in one
  place.
- **Stateless popover, plain `Button`s** — as planned; now justified
  as "two sources of truth for one number", not as the fix.
- **Pin the SwiftData behaviour with `withKnownIssue`** in
  `ObservationAfterFetchTests`, so a toolchain fix surfaces as an
  unexpected pass instead of silently making the rule obsolete.
- **Three UI tests, one class**: the reported surface (popover), the
  test that actually goes red on the old code (quick-log), and the
  timer + `−`-to-zero path. XCUITest parallelises by class, so one
  class keeps the wall clock flat.
- **No `accessibilityValue` on value texts.** It reads "3 of 8, 3"
  under VoiceOver. The suite reads the leading number off the label
  under the pinned English run.

## Surprises and how we handled them

### The bug was not in the popover

- **What happened**: the test passed first time, on iOS 26.5 and then
  on an iPhone 16 Pro / iOS 18.1. Probes showed the popover's
  `@State` counting fine and its `currentValue` prop stuck at 1 — and
  the parent's own value stuck at 1, and a render counter on
  `HabitDetailLoader` flat across value-only taps.
- **What we did**: followed the staleness upward, then sideways to the
  quick-log (same freeze) and the Today row (fine), then into a
  scratch unit test that isolated the fetch-between-read-and-mutation
  shape.
- **Lesson**: when a fix rests on "the parent re-renders", prove it
  before building on it. The plan had that as Task 2's smoke test,
  and it paid for the whole afternoon.

### The `@Query`'s presence, not just the no-fetch rule, is what fixes the screen

- **What happened**: with the fetch *kept* and a `@Query` merely
  added to `HabitDetailView`, the loader re-rendered twice per tap and
  the display followed. With the array lookup and the `@Query`, the
  same. Without the `@Query`, red.
- **What we did**: shipped both halves and wrote the comments to say
  what was measured rather than name a mechanism. Why a child's
  `@Query` re-renders the parent loader is not understood.
- **Lesson**: SwiftData's `@Query` does more than fetch — it is what
  ties a view's subtree to saves. A view without one, mutating through
  the environment context, is on its own.

### Probing a `body` broke navigation

- **What happened**: `let _ = { counter += 1 }()` at the top of a
  `body` compiled and silently stopped the `NavigationStack` push to
  that screen, on both OS versions. Two runs were lost to it.
- **What we did**: counted inside an expression instead
  (`f(x)` wrapping an init argument).
- **Lesson**: statements in a `body` are not free even when they type-check.

### XCUITest at accessibility text sizes

- **What happened**: at `accessibility-extra-extra-extra-large` the
  Today rows expose their inner pill as a separate element and the
  row tap the suite relies on stops pushing. `firstMatch` on a row
  also resolves to whichever of the two same-identifier elements
  (outer 370pt, inner 304pt) comes first, so a normalised offset lands
  in different places.
- **What we did**: verified Dynamic Type at `extra-extra-extra-large`
  (the bar `CLAUDE.md` sets) and used `snapshot_ui` + a screenshot for
  real geometry when a coordinate tap was unavoidable.
- **Lesson**: the suite is not a Dynamic Type harness beyond the
  non-accessibility sizes; check AX sizes by hand.

## What worked well

- **Reading the diagnostics through the accessibility tree.** The MCP
  test summary shows only pass/fail and failure messages, so probe
  `Text`s with identifiers, read by the test and folded into an
  `XCTFail` message, were the fastest loop — one run per question.
- **A scratch unit test to isolate a toolchain behaviour.** Three
  cases, two minutes, and it settled what a dozen UI runs could only
  hint at. It became the regression test almost unchanged.
- **The known-issue test.** Encodes "this is why the rule exists" in
  a way that expires itself.
- **Direct `xcodebuild` with `-resultBundlePath` for captures.**
  `xcresulttool export attachments` gives the UI test's screenshots;
  `simctl ui <udid> appearance` / `content_size` between runs give
  dark mode and Dynamic Type without touching the test.

## For the next person

- `HabitDetailView.allHabits` is **load-bearing**. It is never read in
  `body`; removing it because "nothing uses it" brings #80 back. The
  type comment says so.
- Do not reintroduce a `fetch` in a mutation path on a view — resolve
  from the `@Query` array. `TodayView.record(for:)` and
  `HabitDetailView.record` are the two examples.
- `WidgetReloader.reloadAll` fetches too, but *after* the mutation,
  when the view is already dirty — that is why it never mattered.
- The App Intents (`CompleteHabitIntent`, `LogHabitValueIntent`) fetch
  then mutate. If a screen is open while one runs, the same staleness
  may apply. Not touched here.
- `ObservationAfterFetchTests` will one day report "known issue did
  not occur". That is the signal to re-read this document, not a
  flake.
- The UI suite pins `language: "en"`; `number(in:)` in
  `DayEditPopoverTests` relies on the number leading the label.

## Generalizable lessons

- **[→ CLAUDE.md, SwiftData]** A view that mutates records holds its
  own `@Query` and resolves the record from that array inside the
  mutation. Never `modelContext.fetch` in a mutation path: it leaves
  the view's observer un-notified, and without a `@Query` in the view
  nothing else re-renders it on a value-only save (#80). This
  *sharpens* the #63 bullet ("resolve the id back to a live record
  only inside the mutation, against the current `@Query`") — the
  first cut of #63 read "against the current context" and fetched.
- **[→ CLAUDE.md, Testing / UI tests]** Reading probes through
  accessibility identifiers and the failure message is the fast
  diagnostic loop under XcodeBuildMCP; a `let _ = …` statement in a
  `body` can break navigation; AX text sizes change the Today row's
  element tree and break coordinate taps.
- **[→ CLAUDE.md, Accessibility]** Don't put an `accessibilityValue`
  on a static text to help a test — VoiceOver reads label *and*
  value.
- **[local]** The popover is stateless except for the note draft; the
  `−` / `+` circles use `@ScaledMetric`.
- **[follow-ups, not in this PR]** The calendar cell shows any
  `value > 0` as complete (noted in #80); the popover header truncates
  at AX text sizes; the App Intents' fetch-then-mutate shape; #81
  (haptics).

## Metrics

- Tasks completed: 6 of 6 (one added mid-build)
- Tests added: 2 unit (one a known issue), 3 UI
- Commits: 6 on the branch
- Files touched: 10 (+960 / −102), one file deleted

## References

- [#80](https://github.com/scastiel/kado/issues/80) — the report
- [#63](https://github.com/scastiel/kado/issues/63) — where the
  fetching resolvers came from
- `KadoTests/ObservationAfterFetchTests.swift`,
  `KadoUITests/DayEditPopoverTests.swift`
