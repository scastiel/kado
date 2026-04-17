---
# Research — Detail view quick-log + completion history

**Date**: 2026-04-17
**Status**: draft
**Related**: [ROADMAP v0.1 — deferred from habit-detail-view](../../../ROADMAP.md), [habit-detail-view compound](../habit-detail-view/compound.md)

## Problem

Counter and timer habits appear on Today as read-only rows, and
their detail view shows history/score/streak but no way to **log
a completion**. The previous detail-view PR deferred this as
"PR B." This PR delivers it:

- **Counter habits**: quick-log a day's value (e.g. "8 glasses of
  water") from the detail view.
- **Timer habits**: quick-log a session's minutes.
- **Completion history list**: a scrollable list below the
  calendar showing recent completions with their values.

Constraints:

- **No Live Activities yet** (v0.3 scope). Timer logging is a
  manual minute input, not a real start/stop timer.
- **No notes / photos on completions** (post-v1.0 per ROADMAP).
  Value-only.
- **Today view stays binary-only for toggling** — counter/timer
  rows still navigate to detail for logging.
- **Data model unchanged** — `CompletionRecord` already stores
  `value: Double` and an optional `note`.

## Current state of the codebase

What exists:

- [`CompletionRecord`](../../../../Kado/Models/Persistence/CompletionRecord.swift)
  — `value: Double` supports counter units or timer seconds.
- [`CompletionToggler`](../../../../Kado/Services/CompletionToggler.swift)
  — toggles today's binary completion (value = 1).
- [`HabitDetailView`](../../../../Kado/Views/HabitDetail/HabitDetailView.swift)
  — shows name, score, streak, monthly calendar. Edit + archive
  toolbar.
- [`MonthlyCalendarView`](../../../../Kado/UIComponents/MonthlyCalendarView.swift)
  — shows per-day completion state. For counter/timer, "completed"
  means ANY completion exists (regardless of value). Not ideal but
  not a blocker.
- [`HabitRowView`](../../../../Kado/UIComponents/HabitRowView.swift)
  — counter/timer rows render with trailing `–/target` label (the
  em-dash because today's value isn't threaded through).

What's missing:

- Any way to create a counter or timer `CompletionRecord`.
- Any way to adjust today's counter value (increment / decrement).
- A completion history list.
- Today-value display on the calendar or the row.

## Proposed approach

**Three components on `HabitDetailView`, stacked below the score
cards and above the calendar:**

1. **Quick-log section** — per habit type:
   - `.binary` / `.negative`: no-op. Toggling lives on Today.
   - `.counter`: shows today's value as `N / target`, with a
     `Stepper(value:) -> Button {−}` and `Button {+}` pair. The
     `+` adds 1 to today's completion value (creates a record if
     none); `−` subtracts 1, deletes the record when value drops
     to 0.
   - `.timer`: shows "Log a session" button opening a sheet with
     a minute stepper + Save. Adds (or replaces) today's
     completion with the given duration in seconds.

2. **Completion history list** — scrollable `List` section below
   the calendar showing up to 30 recent completions:
   - For each: date (relative format "Today", "Yesterday", "3 days
     ago", or date), value in habit-type-aware format.
   - Swipe-to-delete for historic corrections.
   - "Show more" button loads older entries (unbounded) if the list
     exceeds 30 items.

3. **Calendar today-value overlay** (optional): each counter/timer
   cell shows a small value badge if completed, e.g. "6/8" in the
   cell. Might be too cluttered at 32pt cell height — probably
   skip for v0.1 and revisit.

### Key components

- **`CompletionLogger`** — extends the `CompletionToggler` pattern
  for counter/timer operations:
  ```swift
  @MainActor
  struct CompletionLogger {
      let calendar: Calendar
      init(calendar: Calendar = .current)
      
      func increment(habit: HabitRecord, by delta: Double, on date: Date, in context: ModelContext)
      func logTimerSession(habit: HabitRecord, seconds: TimeInterval, on date: Date, in context: ModelContext)
      func delete(completion: CompletionRecord, in context: ModelContext)
  }
  ```
  TDD'd with in-memory `ModelContext` cases (mirrors
  `CompletionToggler`).

- **`CounterQuickLogView`** — small component rendering the
  `−` / value / `+` trio. Shows visual cue when target reached
  (e.g. checkmark overlay).

- **`TimerLogSheet`** — modal sheet with a minute stepper and Save
  button. Pre-fills with the habit's target minutes on first open;
  remembers prior input on subsequent opens.

- **`CompletionHistoryList`** — scrollable list with per-row cell
  formatting by habit type. Swipe-to-delete + confirmation.

### Data model changes

None. `CompletionRecord.value: Double` already supports it.

### UI changes

- `HabitDetailView` gains a "log" section (conditional on type)
  and a history list section.
- `HabitRowView`'s trailing label updates to show today's value
  when non-zero (`3/8` instead of `–/8`).
- `MonthlyCalendarView` — no change (day-level completion state
  already handles this).

### Tests to write

Pure-logic unit tests on `CompletionLogger`:

```swift
@Test("Incrementing a counter on a day with no completion creates one with value 1")
@Test("Incrementing adds to an existing completion's value")
@Test("Decrementing below zero deletes the completion")
@Test("Logging a timer session replaces today's completion")
@Test("Delete removes the completion and preserves others")
```

Also extend `HabitRowView` preview coverage to include "counter
with today's value" and "timer with today's value" states.

## Alternatives considered

### Alternative A: Real timer (start / stop) on detail view

- Idea: Tap "Start" to begin tracking, "Stop" to save session.
  Requires `BackgroundTasks` / `ActivityKit` for resilience.
- Why not: v0.3 scope per ROADMAP. Minute-based manual logging
  covers the MVP use case ("I read for 25 minutes").

### Alternative B: Editable value field (no stepper)

- Idea: TextField for counter value, user types a number.
- Why not: Steppers are the HIG pattern for bounded integer
  input. Typing is less ergonomic for "+1 water glass" interactions.
  An editable field could be a fallback for power users — defer.

### Alternative C: Combine quick-log with the edit form

- Idea: Open the edit sheet to log. Same UI as creation.
- Why not: Quick-log is fundamentally "one tap" (increment by 1 or
  start a session). An edit sheet is too heavy and would erode the
  ergonomic win.

### Alternative D: History as a second tab on the detail view

- Idea: TabView with "Overview" (score/streak/calendar) and
  "History" (list).
- Why not: Extra navigation for a section most users will scroll
  to. The inline scrollable list is more discoverable.

## Risks and unknowns

- **Counter decrement crossing zero**: What happens if user hits
  "−" with value=1? Delete the record, or leave it at 0? We
  already treat "no record" as "not completed," so deleting is the
  coherent choice — but it means "−" and "+" aren't exactly
  inverses (the final "-" deletes; the first "+" on a fresh day
  creates). Test covers it.
- **Timer session replacing vs adding**: If a user logs 25 min
  twice in one day, does the second replace or add? Replace is
  simpler; add matches "I did two sessions today" but complicates
  the data model (single record per day is the current invariant).
  Recommend **replace** for MVP; revisit if users ask.
- **Counter target met feedback**: haptic, check overlay, or
  both? Haptic on the transition is lowest-effort.
- **History list pagination**: 30 items is arbitrary. Paginate
  manually or use a LazyVStack with an unbounded fetch? For
  v0.1, LazyVStack with the habit's full `completions` array
  sorted descending should be fine at habit-scale (~hundreds
  max).
- **Swipe-to-delete confirmation**: iOS convention is no
  confirmation for list swipe actions (undo lives in the parent
  view). Align with convention; no dialog.
- **Today row value display**: updating `HabitRowView` to show
  today's value requires threading it through. Small diff. The
  trailing label becomes `3/8` instead of `–/8` when a completion
  exists.

## Open questions

- [ ] **Counter `+` / `−` or `+` only?** `−` helps correct
  mistakes but adds visual weight. *Recommendation*: both, with
  `−` disabled when value is 0.
- [ ] **Timer: minute stepper in a sheet, or inline on detail?**
  *Recommendation*: sheet. Matches iOS pattern for "log a thing
  now" interactions (Health sessions, Reminders quick-add).
- [ ] **History list scope**: just today + recent 30 days, or
  full unbounded history? *Recommendation*: full history in a
  `LazyVStack`, sorted descending. At habit-scale, perf is fine.
- [ ] **Swipe-to-delete**: with or without confirmation?
  *Recommendation*: without (iOS convention).
- [ ] **Same-day timer logging**: replace the existing completion
  or add another? *Recommendation*: replace (single record per
  day invariant).
- [ ] **Scrollable past-months calendar**: ship in this PR or
  defer? *Recommendation*: defer. Scope creep; the history list
  is the more useful surface.
- [ ] **Update `HabitRowView` to show today's value for
  counter/timer?** *Recommendation*: yes — it's a 10-line diff
  and the `–/8` placeholder is a known eyesore.
- [ ] **Haptic on counter target reached?** *Recommendation*:
  yes, `.success` on transition from below-target to at-or-above.

## References

- [Stepper](https://developer.apple.com/documentation/swiftui/stepper)
- [swipeActions](https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:))
- [LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack)
- [habit-detail-view compound](../habit-detail-view/compound.md)
  — parent PR's deferral of this scope.
- [CompletionToggler](../../../../Kado/Services/CompletionToggler.swift)
  — pattern the new logger mirrors.
