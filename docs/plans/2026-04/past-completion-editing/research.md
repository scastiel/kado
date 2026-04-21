---
name: Research — Past-completion editing
description: Allow users to check/uncheck habits on past days by tapping a cell in the habit detail calendar.
type: project
---

# Research — Past-completion editing

**Date**: 2026-04-20
**Status**: ready for plan
**Related**: `docs/ROADMAP.md` (v0.x polish), `docs/plans/2026-04/detail-quick-log/`, `docs/plans/2026-04/multi-habit-overview/` (popover pattern)

## Problem

Today, users can only log a completion for **the current day**. The
detail view's monthly calendar is read-only. If a user forgets to log
a completion — e.g. they read before bed but their phone was already
off, or they went to the gym and only remembered the next morning —
the day is permanently marked as missed.

From the user's perspective, "done" looks like: open the habit's
detail, tap yesterday's cell in the calendar, confirm the completion,
and see the streak / score update. The same gesture unchecks a day
that was marked by mistake.

Why it matters: a single missed log shouldn't break a streak or
degrade the score when the underlying behavior actually happened.
This is standard in Streaks, Loop, (Not Boring) Habits — its absence
is a visible gap.

## Current state of the codebase

The good news: **the service layer is already date-parameterized**.
Only the UI is read-only.

- `Packages/KadoCore/Sources/KadoCore/Services/CompletionToggler.swift`
  — `toggleToday(for:on:in:)` already accepts an arbitrary `date`
  (defaulted to `.now`). Inserts a `CompletionRecord` if none exists
  for the injected calendar's day, otherwise deletes the match. DST-
  safe; covered by `KadoTests/CompletionTogglerTests.swift`.
- `Kado/Services/CompletionLogger.swift` — `incrementCounter(on:)`,
  `decrementCounter(on:)`, `setCounter(on:to:)`,
  `logTimerSession(seconds:on:)`. All already take a `date:` and
  keep the one-record-per-day invariant.
- `CompletionRecord` (`Packages/KadoCore/Sources/KadoCore/Models/Persistence/CompletionRecord.swift`)
  — no `@Attribute(.unique)`; uniqueness is application-enforced via
  calendar-aware lookup.
- `Kado/UIComponents/MonthlyCalendarView.swift` — renders the grid.
  Each day is a `ZStack` inside a `LazyVGrid` (32 pt cells). Has an
  accessibility label per cell. **No tap handler today.** Computes
  `CellState` of `.future | .completed | .missed | .nonDue` locally.
- `Kado/Views/HabitDetail/HabitDetailView.swift` — owns the grid,
  the quick-log affordance (counter/timer), and the
  `CompletionHistoryList`. `@Bindable var habit: HabitRecord` with
  `@Environment(\.modelContext)`.
- `Kado/Views/Overview/CellPopoverContent.swift` — **the UX
  precedent.** The multi-habit overview already attaches a
  read-only `.popover` per (habit × day) cell. We'll adapt the
  look-and-feel (habit mark + date + status) and add edit
  affordances.

Gaps:
- No tap gesture on calendar cells.
- No existing editable popover anywhere in the app.
- `CompleteHabitIntent` (widget / Siri) is today-only. This feature
  doesn't need to change that — arbitrary-date logging from the
  widget is a separate design conversation.

## Proposed approach

Attach a tap gesture to past-or-today cells in `MonthlyCalendarView`.
The tap opens a popover (anchored to the cell) whose body branches
on `habit.type`:

- **Binary / negative**: single toggle button. Current state rendered
  as "Completed / Missed" with a primary action labeled *Mark
  complete* or *Unmark* (inverted copy for negative). Calls
  `CompletionToggler.toggleToday(for:on:in:)` with the tapped day.
- **Counter**: stepper + number field bound to the day's value;
  calls `CompletionLogger.setCounter(for:on:to:)`. "Clear" sets 0
  which deletes the record.
- **Timer**: duration picker (minutes) bound to the day's logged
  seconds; calls `CompletionLogger.logTimerSession(for:seconds:on:)`.
  "Clear" logs 0 to delete.

Discoverability is the biggest UX question (cells are small; tap
affordance isn't obvious). Two mitigations:
- Add `accessibilityHint("Double-tap to edit this day")`.
- Add a subtle haptic on tap-down (`.sensoryFeedback(.impact, ...)`)
  so the cell feels "pressable."
- Consider a first-launch tooltip (deferred — not in MVP).

Interactions to preserve:
- **Future days**: remain non-interactive. No popover.
- **Archived habits**: cells are non-interactive. No popover at all,
  matching the read-only spirit of the rest of `HabitDetailView` on
  archived habits.
- **Today's cell**: also opens the popover. That's a behavior
  change for counter/timer (today's counter +/- is currently in
  the inline quick-log above the grid). The popover becomes a
  second path to log today — cheap, non-conflicting, doesn't
  remove existing affordances.
- **Discoverability**: ship silent — no helper text. Rely on the
  accessibility hint and the familiar popover pattern. Revisit if
  user feedback shows confusion.

### Key components

- `MonthlyCalendarView` — extend cell closure with a `onTap: (Date) -> Void`
  callback, gate to `!isFuture`. The view stays presentation-only.
- `HabitDetailView` — new `@State private var editingDay: Date?` +
  a single `.popover(item:)` projection. Owns the mutation calls.
- New `Kado/Views/HabitDetail/DayEditPopover.swift` — small view that
  switches on `habit.type` and renders the right control. Mirrors
  `CellPopoverContent` visual style; reuses `CounterQuickLogView` for
  counter, the timer duration control from `TimerLogSheet` for timer.
- Localization: new catalog entries for popover copy (EN + FR).
- `WidgetReloader.reloadAll(using:)` after every mutation (existing
  pattern; no new work).

### Data model changes

**None.** The existing `CompletionRecord` shape is sufficient. The
calendar-aware one-per-day invariant already holds at the service
layer. No schema bump, no migration.

### UI changes

- Cells become tappable for past + today (not future).
- New popover: binary toggle / counter stepper / timer duration
  picker depending on type.
- Minor: add accessibility hint, haptic feedback on cell tap.

### Tests to write

Services are already covered for arbitrary dates; the value-add is
guarding the new UI path and the day-identity edge cases.

- `@Test("Toggling a past day inserts a record on that day, not today")`
  — exercise `CompletionToggler.toggleToday(on:)` with `now` fixed to
  mid-April and `date` = 3 days earlier. Assert the stored
  `CompletionRecord.date` matches the target day, not `.now`.
- `@Test("Toggling a past day twice is idempotent (delete)")` —
  covered conceptually, add a targeted regression if absent.
- `@Test("Setting counter on a past day preserves other days'
  values")` — ensure `setCounter(on:to:)` only mutates the matching
  day.
- `@Test("DayEditPopover binary flow")` — a light view-model-style
  test that ensures the right service method is called with the
  right date. (Or skip if popover is a pure passthrough.)
- Manual: VoiceOver walk of the grid (focus + hint + action),
  Dynamic Type XXXL doesn't crop the popover, dark mode contrast on
  the popover surface.

## Alternatives considered

### Alternative A: long-press instead of tap

- Idea: long-press a cell to enter edit mode; tap preserved for a
  potential future behavior (e.g. zoom to day detail).
- Why not: tap is the expected iOS gesture for "interact with this
  thing," and long-press is less discoverable. We have no other tap
  semantics competing for the gesture. Keep tap for MVP; revisit if
  we ever need a secondary action.

### Alternative B: full-screen "edit day" sheet

- Idea: tap opens a sheet listing all habits for that day (Overview-
  style), allowing bulk edits.
- Why not: mixes concerns. The user's flow is "I want to log this
  one habit for yesterday," not "let me revisit all habits for a
  day." That's a separate feature and arguably belongs in the
  Overview surface rather than the detail view. Defer.

### Alternative C: inline row below the grid

- Idea: tapping selects a day; a row appears below with the same
  controls as the today quick-log.
- Why not: extra vertical push, less spatial continuity. Popover
  anchored to the cell is the well-established iOS pattern we
  already use in Overview.

### Alternative D: Swipe on `CompletionHistoryList`

- Idea: use the existing `CompletionHistoryList` to edit past days.
- Why not: history only shows *existing* completions — it can't
  insert a missing day. We'd have to add a "pick a date" flow,
  which is strictly worse UX than tapping the calendar.

## Risks and unknowns

- **Day-boundary bugs.** The calendar is injected via
  `@Environment(\.calendar)`, but the service layer also takes a
  `Calendar`. Make sure both paths use the same instance — regress
  if mismatched around DST.
- **Popover sizing under Dynamic Type XXXL.** Counter / timer
  controls can push the popover past comfortable widths. May need
  `.presentationCompactAdaptation(.popover)` + max-width clamps, or
  switch to a sheet in compact accessibility sizes.
- **Tap target.** 32 pt cells are below Apple's 44 pt guideline.
  VoiceOver users get the full-width focusable element; mouse/tap
  users have a smaller target. Acceptable (calendar dates are
  traditionally smaller) but flag as a known constraint.
- **Counter > target.** The popover stepper should allow values
  above the target (same as today's quick-log) — just capped at a
  reasonable max to prevent runaway.
- **Logging a day before `habit.createdAt`.** Technically possible;
  the `missed`/`nonDue` classification still works. We should
  allow it — users sometimes want to record pre-existing behavior
  — but the calendar currently shows cells only for the current
  month. Not a blocker; revisit if month navigation ever lands.

## Resolved decisions

- **Habit-type scope**: all four types (binary / negative / counter
  / timer) in MVP.
- **Tap-on-today**: opens the popover, same as past days. Inline
  quick-log remains as a second path for today.
- **Discoverability**: ship silent. Rely on accessibility hint.
- **Archived habits**: no popover at all. Cells stay non-interactive.

## Open questions

- [ ] **Month navigation** is out of scope for this feature — the
      grid still shows only the current month. Past-day editing is
      limited to that window until someone adds paging. Flag if
      users reach beyond the current month, otherwise defer.

## References

- Apple HIG — Popovers:
  https://developer.apple.com/design/human-interface-guidelines/popovers
- Existing popover precedent: `Kado/Views/Overview/CellPopoverContent.swift`
- Service entry points:
  `Packages/KadoCore/Sources/KadoCore/Services/CompletionToggler.swift`,
  `Kado/Services/CompletionLogger.swift`
- Test patterns (calendar injection + DST):
  `KadoTests/CompletionTogglerTests.swift`, `KadoTests/Helpers/TestCalendar.swift`
