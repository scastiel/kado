---
name: Compound — Past-completion editing
description: Retrospective on the past-day popover feature — decisions, surprises, and lessons that generalize.
type: project
---

# Compound — Past-completion editing

**Date**: 2026-04-20
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/past-completion-editing` · [PR #29](https://github.com/scastiel/kado/pull/29)

## Summary

Shipped a per-cell popover that lets users log or clear past-day
completions from the habit detail calendar. Service layer was already
date-parameterized, so the change was UI-only: a tap gesture on past /
today cells + a branching popover (`binary`, `negative`, `counter`,
`timer`). Two visual regressions missed by previews and tests were
caught by the user's screenshot feedback loop and fixed before merge.
Headline lesson: for calendar-style grids, popovers must anchor
per-cell — `.popover(item:)` at the parent anchors to the parent's
frame.

## Decisions made

- **Per-cell `.popover(isPresented:)`** on `MonthlyCalendarView`: the
  view takes a generic `PopoverContent: View` + a `@Binding var
  selectedDay: Date?` + `@ViewBuilder popoverContent: (Date) -> …`.
  Mirrors the Overview's `CellPopoverContent` pattern.
- **No `Identifiable` wrapper** on the selection: per-cell popovers
  use `calendar.isDate(selected, inSameDayAs: day)` so raw `Date?`
  works directly.
- **Convenience init** `where PopoverContent == EmptyView` keeps the
  nine existing read-only previews working without surface changes.
- **Scope = all four habit types** in the MVP (not binary / negative
  only).
- **Tap-on-today opens the popover** too — consistent behavior with
  past cells; inline quick-log above the grid is preserved as a
  second path.
- **Archived habits pass `.constant(nil)`** as the selection binding,
  so taps fire but nothing opens. Simpler than branching the view.
- **Stepper seeds to 0** when a day has no record (not to the
  habit's target). Users explicitly enter a value.
- **Clear button tracks live stepper value** (`counterValue /
  timerMinutes`), not the saved-at-open snapshot, so stepping up from
  0 reveals Clear immediately.
- **No Done button**: every stepper tick writes through. Binary /
  negative actions and Clear auto-dismiss; otherwise the user taps
  outside.
- **Timer `clear` routes through `logger.delete(existing)`** because
  `CompletionLogger.logTimerSession(seconds: 0)` inserts a zero-value
  record rather than deleting (asymmetric with `setCounter(to: 0)`).

## Surprises and how we handled them

### Popover anchoring

- **What happened**: First pass attached `.popover(item:)` at the
  whole-calendar level. In the sim, the popover's arrow pointed to the
  top of the grid regardless of which cell was tapped. Docs note on
  `.popover(item:)` was not enough — anchor is the modified view's
  frame.
- **What we did**: Lifted the selection + content closure down into
  `MonthlyCalendarView`, introduced a generic `PopoverContent: View`,
  attached `.popover(isPresented:)` per cell. Commit `d073fe0`.
- **Lesson**: For grids where any cell can be a popover source, use
  per-cell `.popover(isPresented:)`. Parent-level `.popover(item:)` is
  fine only when the anchor *is* the parent.

### Timer popover looked already-complete on open

- **What happened**: Seeding `timerMinutes` to the habit's target on
  empty days made the popover read "30 of 30 min" before any user
  action. Looked like the day was already logged.
- **What we did**: Seed to 0. Fixed in `1af83d3`.
- **Lesson**: When a popover edits a value, its default should read
  "nothing entered," not "the target." Default matters more than
  convenience.

### Clear button hidden after stepping up

- **What happened**: `clearButton(canClear: isRecorded)` where
  `isRecorded = currentValue > 0` used the saved-at-open snapshot.
  Stepping up from 0 never revealed Clear.
- **What we did**: Gate on the live stepper state
  (`counterValue > 0` / `timerMinutes > 0`). Same commit.
- **Lesson**: Local `@State` and passed-in snapshots diverge the
  moment the user interacts. If an action's availability depends on
  "current value," make sure that reflects *current*, not *initial*.

### XcodeBuildMCP has no tap primitives

- **What happened**: `build_run_sim` launched the app but there was
  no way to drive a tap on a calendar cell to verify the popover
  opened, its content, or the save path. `CLAUDE.md` already flags
  this, but it bit us mid-feature.
- **What we did**: User drove the sim manually and shared
  screenshots. Two rounds of screenshots surfaced both the anchoring
  bug and the UX regressions.
- **Lesson**: Tests + previews verify correctness and compile-cleanliness.
  They don't verify "does this actually look right when tapped."
  Build a screenshot feedback loop into UI-feature workflows.

## What worked well

- **Service layer was already date-parameterized.** The research pass
  surfaced this early — `CompletionToggler.toggleToday(on:)` and
  `CompletionLogger.setCounter(on:)` both took a `date` parameter.
  Meant zero schema change, zero service API change, and tests mostly
  passed green as regressions rather than as new coverage.
- **Convenience init on a generic view.** `extension MonthlyCalendarView
  where PopoverContent == EmptyView { init(...) }` let us introduce
  a generic type parameter without breaking any of the nine existing
  call sites and previews.
- **Conductor staging.** Research → plan → build → compound kept
  scope tight: four commit-sized tasks, each leaving the tree green,
  plus two clearly-scoped follow-ups when visual testing surfaced
  issues. The plan doc needed mid-flight updates but stayed a useful
  artifact throughout.
- **Regression tests over green services.** Adding "toggle past day,
  today intact" regressions even though the service already did the
  right thing is cheap insurance against a future "simplification"
  that hardcodes `.now`.

## For the next person

- `MonthlyCalendarView` is **generic** on `PopoverContent`. New
  read-only callers should use the convenience init
  (`MonthlyCalendarView(habit:completions:month:)`); edit-capable
  callers pass `selectedDay:` and `popoverContent:`.
- Selection comparison uses `calendar.isDate(a, inSameDayAs: b)`.
  Both the view and the services must get the *same* `Calendar`
  instance — pulled from `@Environment(\.calendar)` at the use site.
  Pinning `.current` anywhere would silently desync around DST.
- `CompletionLogger.logTimerSession(seconds: 0, …)` does **not**
  delete. If you add a new caller that wants "clear to zero" semantics
  for a timer habit, route through `logger.delete(existing)` after
  looking up the record — see `HabitDetailView.clear(on:)` for the
  pattern. Better long-term: normalize `logTimerSession` to match
  `setCounter`'s delete-on-zero contract.
- Every stepper tick saves + reloads widgets. If performance ever
  matters here, debounce at the view layer — but do it consistently
  with the existing `CounterQuickLogView` + `TimerLogSheet` save
  patterns, don't make this one popover the odd one out.
- Archived habits: the detail view passes `.constant(nil)` as
  `selectedDay`. Taps on cells fire `selectedDay = day` against the
  constant binding, which SwiftUI discards — so no popover opens.
  Slightly "wasted motion" but correct; could be replaced with an
  `isInteractive: Bool` flag on the view if someone cares.

## Generalizable lessons

- **[→ CLAUDE.md]** When attaching a popover to one of many identical
  cells, use per-cell `.popover(isPresented:)` owned by the cell, not
  `.popover(item:)` on the parent. The parent-level modifier anchors
  to the parent's frame, not the cell the user interacted with —
  visible regression, not caught by tests or previews.
- **[→ CLAUDE.md]** A popover that auto-saves on every change does
  **not** need a "Done" button. Dismissing is the user's job
  (tap-outside). Adding Done creates a no-op affordance that looks
  important.
- **[→ CLAUDE.md]** `CompletionLogger.logTimerSession(seconds: 0)`
  inserts a zero-value record rather than deleting — asymmetric with
  `setCounter(to: 0)`. Callers wanting "clear" semantics must route
  through `logger.delete(existing)`. Normalize this in a follow-up so
  the service is self-consistent.
- **[→ CLAUDE.md]** For UI features that depend on tap gestures, a
  build is not complete until a human-driven sim pass happens.
  `test_sim` + `build_sim` + previews will not catch regressions like
  mis-anchored popovers, wrong initial values, or affordance glitches.
  Bake a "screenshot loop with user" step into the build stage for
  any UI-only feature.
- **[local]** `MonthlyCalendarView` is generic on `PopoverContent: View`
  with an `EmptyView` convenience init. Keep the convenience init in
  place — nine callers depend on it, removing it would break previews
  across four habit types.

## Metrics

- Tasks completed: 4 planned + 2 follow-ups (anchoring fix, UX fixes)
- Tests added: 5 (`CompletionTogglerTests` ×2, `CompletionLoggerTests` ×3)
- Commits: 8 (4 tasks + 2 follow-ups + 2 doc syncs)
- Files touched: 8 (3 prod code, 1 catalog, 2 test files, 3 docs)
- Lines added: ~1,100 (of which ~540 are docs)

## References

- Existing popover precedent that informed the per-cell approach:
  `Kado/Views/Overview/OverviewView.swift` + `CellPopoverContent.swift`
- Service entry points used unchanged:
  `Packages/KadoCore/Sources/KadoCore/Services/CompletionToggler.swift`,
  `Kado/Services/CompletionLogger.swift`
- Test pattern for calendar-aware service mutations:
  `KadoTests/Helpers/TestCalendar.swift`
