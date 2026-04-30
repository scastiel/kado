# Research — Month navigator

**Date**: 2026-04-29
**Status**: ready for plan
**Related**: [GitHub issue #45](https://github.com/scastiel/kado/issues/45), `Kado/UIComponents/MonthlyCalendarView.swift`, `Kado/Views/HabitDetail/HabitDetailView.swift`

## Problem

The habit detail screen shows a calendar grid for the **current month only**. Users with history spanning multiple months have no way to browse past completions on the calendar — they can only see the flat `CompletionHistoryList` below. Navigating months is essential for reviewing patterns, editing past days, and understanding long-term trends.

## Current state of the codebase

`MonthlyCalendarView` already accepts a `month: Date` parameter (defaults to `.now`) and renders whichever month that date falls in. All the month-start, day-range, and leading-blank computation is self-contained. The component just never gets a different month because `HabitDetailView` uses the default.

The month header (`monthHeader`) is a plain `Text(monthTitle)` with no navigation controls.

`HabitDetailView` has no `@State` for which month is displayed. The `editingDay` binding already flows into `MonthlyCalendarView` for the day-edit popover, so the interaction pattern is established.

`Habit.effectiveStart(completions:calendar:)` returns the earliest meaningful date (earliest completion or `createdAt`), which is a natural lower bound for backward navigation.

No existing chevron-navigation pattern exists in the app — this will be the first.

## Proposed approach

Add month navigation **inside `MonthlyCalendarView`** so any consumer gets it for free. The component already owns the month header — flanking it with chevron buttons is a natural extension.

### Design

The month header row becomes:

```
  ‹   April 2026   ›
```

- Left chevron: go to previous month. Disabled when the displayed month contains `effectiveStart`.
- Right chevron: go to next month. Disabled (or hidden) when the displayed month is the current month.
- Tapping the month title could reset to current month (nice touch, not required for MVP).

### Key changes

1. **`MonthlyCalendarView`**: change `month` from a plain `Date` property to a `@Binding var month: Date` so the parent can track which month is displayed and the component can mutate it. Add chevron buttons to `monthHeader`. Add lower/upper bound logic.

2. **`HabitDetailView`**: add `@State private var displayedMonth: Date = .now` and pass it as the binding. Pass `habit.snapshot.effectiveStart(...)` as the lower bound.

3. **Localization**: the chevron buttons use SF Symbols (`chevron.left` / `chevron.right`) and accessibility labels ("Previous month" / "Next month") — two new catalog entries with FR translations.

### Data model changes

None.

### UI changes

- `MonthlyCalendarView.monthHeader` gains two `Button`s flanking the title.
- The month title becomes tappable to reset to current month (optional, low effort).

### Tests to write

- `@Test("Previous month button navigates backward")` — verify `month` binding updates to the prior month's first day.
- `@Test("Next month button is disabled on current month")` — verify the upper bound.
- `@Test("Previous month button is disabled on effectiveStart month")` — verify the lower bound.

These are UI-behavior tests and can be light — the core date math uses `calendar.date(byAdding:)` which is already well-tested by the system. If we prefer pure-unit coverage, we can extract the bound-checking logic into a small helper.

## Alternatives considered

### Alternative A: Navigation owned by HabitDetailView

- Idea: put the chevron buttons outside `MonthlyCalendarView`, in `HabitDetailView`'s VStack.
- Why not: the month header and navigation are visually and semantically coupled. Splitting them forces layout coordination and makes `MonthlyCalendarView` less reusable. Any future consumer (e.g., overview, widget preview) would need to re-implement navigation.

### Alternative B: Swipe gesture instead of buttons

- Idea: horizontal swipe on the calendar to change months.
- Why not as primary: conflicts with the scroll view's gesture and the popover tap targets. Could be a future enhancement layered on top of buttons.

### Alternative C: `TabView` with page-style swiping

- Idea: embed months in a `TabView(.page)` for swipe navigation.
- Why not: adds complexity (lazy loading of off-screen months, gesture conflicts with day taps and popovers). Buttons are simpler and more accessible. Could revisit for a polish pass.

## Risks and unknowns

- **Popover + month change interaction**: if a day-edit popover is open and the user navigates away, the popover should dismiss. Setting `selectedDay = nil` on month change handles this naturally.
- **Performance**: rendering a month grid is fast (~30 cells). No concern even with rapid navigation.

## Open questions

- [x] Should tapping the month title reset to the current month? **Yes.**
- [x] Should the calendar animate the month transition (e.g., slide left/right)? **Yes** — slide transition matching chevron direction.

## References

- [GitHub issue #45](https://github.com/scastiel/kado/issues/45)
- `MonthlyCalendarView.swift` — existing calendar grid component
- `HabitDetailView.swift` — detail screen that hosts the calendar
- `Habit.effectiveStart(completions:calendar:)` — lower bound for navigation
