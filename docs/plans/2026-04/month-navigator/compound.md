# Compound — Month navigator

**Date**: 2026-04-29
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [#46](https://github.com/scastiel/kado/pull/46)

## Summary

Added month navigation to `MonthlyCalendarView` — chevron buttons
flank the month title, tapping the title resets to the current month,
and transitions animate directionally. The initial plan included a
backward lower bound (`lowerBound: Date?` tied to `effectiveStart`),
which was removed mid-build at the user's request. The final API is
simpler: a `navigable: Bool` flag.

## Decisions made

- **Navigation lives inside `MonthlyCalendarView`, not `HabitDetailView`**: the header and chevrons are semantically coupled; any future consumer gets navigation for free by setting `navigable: true`.
- **`navigable: Bool` over `lowerBound: Date?`**: originally the presence of a lower bound toggled navigation and constrained backward movement. User feedback simplified this to a plain boolean with unlimited backward navigation.
- **`@Binding var month` over callbacks**: the parent owns the state, the component mutates via binding. Cleaner than `onMonthChange` closures and consistent with how `selectedDay` already works.
- **`.id(monthStart)` for animation**: swapping the grid's identity on month change triggers SwiftUI's insert/remove transition. Simple, no `TabView` or manual offset math needed.
- **Tap title to reset**: low-effort affordance to return to the current month. Disabled when already viewing the current month.

## Surprises and how we handled them

### Lower bound removal mid-build

- **What happened**: the plan called for disabling backward navigation past `effectiveStart`. User said there should be no constraint to go in the past.
- **What we did**: replaced `lowerBound: Date?` with `navigable: Bool`, removed `canGoBackward` and `isShowingCurrentMonth`, simplified to a single `canGoForward` check.
- **Lesson**: when designing navigation bounds, default to no constraint unless the user explicitly asks for one.

### Accessibility label wrapping

- **What happened**: initial code used `Text(String(localized: "Previous month"))` — double-wrapping since `Text("...")` already goes through `LocalizedStringKey`.
- **What we did**: simplified to `Text("Previous month")` during review.
- **Lesson**: when the API accepts `Text`, rely on `LocalizedStringKey` implicit conversion. Reserve `String(localized:)` for `String`-typed APIs.

## What worked well

- **Existing `month: Date` parameter**: `MonthlyCalendarView` already accepted a month parameter that was always `.now`. Changing it to a `@Binding` was the minimal delta to unlock full navigation.
- **Convenience init backward compat**: wrapping the plain `Date` in `.constant()` in the `EmptyView` convenience init meant zero changes to preview call sites.
- **Single commit for tightly coupled changes**: calendar view + detail view + localization shipped together since they're inseparable.

## For the next person

- `MonthlyCalendarView` has two modes: static (default, `navigable: false`) and navigable. The convenience init forces static mode — no way to accidentally get navigation without a real `@Binding`.
- The slide animation relies on `.id(monthStart)` destroying and recreating the grid. This is fine for ~30 cells but would need rethinking if the grid ever becomes heavy (e.g., multi-month view).
- `canGoForward` compares `monthStart` against `Calendar.dateInterval(of: .month, for: .now)?.start`. This uses `.now` at evaluation time, which is correct for SwiftUI's re-render model.

## Generalizable lessons

- **[local]** `navigable: Bool` is simpler than `lowerBound: Date?` when the only question is "show navigation or not."
- **[local]** `.accessibilityLabel(Text("..."))` uses `LocalizedStringKey` — no need for `String(localized:)` wrapping.

## Metrics

- Tasks completed: 4 of 4 (including visual verification by user)
- Tests added: 0 (pure UI, no extractable business logic)
- Commits: 6
- Files touched: 3 production + 2 docs
