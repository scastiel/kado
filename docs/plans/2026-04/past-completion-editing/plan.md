---
name: Plan — Past-completion editing
description: Ordered task breakdown for the past-day popover in habit detail.
type: project
---

# Plan — Past-completion editing

**Date**: 2026-04-20
**Status**: in progress (manual visual verification pending)
**Research**: [research.md](./research.md)

## Summary

Let users check / uncheck a habit on a past or today cell by tapping
that cell in the habit detail's monthly calendar. A popover anchored
to the cell shows the right affordance per habit type (binary,
negative, counter, timer) and writes through the existing
`CompletionToggler` / `CompletionLogger` services — both already
accept an arbitrary `date` parameter. No schema change, no service
API change; purely UI wiring + a new popover view.

## Decisions locked in

- Scope: all four habit types (binary, negative, counter, timer) in
  the MVP.
- Tap-on-today: opens the popover, same as past days. Inline
  quick-log above the grid stays as a second path for today.
- Discoverability: ship silent. Accessibility hint only — no visible
  helper text.
- Archived habits: cells are non-interactive. No popover at all.
- Future cells: non-interactive. No popover.
- Binary / negative flow: tap the action, popover auto-dismisses.
- Counter / timer flow: popover stays open while the user adjusts
  the value; dismiss on tap-outside or explicit "Done."
- "Clear" in counter / timer popovers sets value to 0, which deletes
  the `CompletionRecord` via the existing logger contract.
- Popover presentation: `.presentationCompactAdaptation(.popover)`
  so iPhone gets the anchored popover look. Adapt to a sheet only
  under accessibility Dynamic Type (XXXL and above) where the
  popover body can't fit — flag as a task 4 decision once measured.
- Use an `Identifiable` wrapper (`EditingDay`) for `.popover(item:)`
  since `Date` isn't `Identifiable`.
- Mutations go through existing services with `@Environment(\.calendar)`
  injected — same calendar drives cell classification and write
  path, avoiding day-boundary drift.
- Widget refresh: call `WidgetReloader.reloadAll(using: modelContext)`
  after every mutation, mirroring the today quick-log pattern.

## Task list

- [x] Task 1 — Regression tests for past-day service mutations (bbd4baa)
- [x] Task 2 — Tappable past / today cells in `MonthlyCalendarView` (56a35b4)
- [x] Task 3 — `DayEditPopover` view + localization (d2693ec)
- [x] Task 4 — Wire popover into `HabitDetailView` (41463b2)

### Task 1: Regression tests for past-day service mutations

**Goal**: Lock in the invariant that `CompletionToggler` and
`CompletionLogger` write to the injected `date`, not `.now`, under
a fixed-calendar test. These should pass green on the current
service layer; they're insurance against a future "simplification"
that hardcodes `.now`.

**Changes**:
- `KadoTests/CompletionTogglerTests.swift` — add:
  - `@Test("Toggle on a past day inserts on that day, not today")`
    with `now = 2026-04-15` and `date = 2026-04-12`.
  - `@Test("Toggle on a past day twice deletes, leaving today intact")`
    with a today record pre-seeded.
- `KadoTests/CompletionLoggerTests.swift` — add:
  - `@Test("setCounter on past day preserves other days' values")`
    — seed days D-3 and D-1, set D-2, verify only D-2 changed.
  - `@Test("logTimerSession on past day targets the correct day")`
    — mirror the toggler test for timer values.
  - `@Test("setCounter to 0 on past day deletes the record")`.

**Tests / verification**:
- All new tests pass: `test_sim` scheme Kado.
- No warnings introduced.

**Commit**: `test(completions): lock in past-day service invariants`

---

### Task 2: Tappable past / today cells in `MonthlyCalendarView`

**Goal**: The calendar view exposes a tap callback for past and
today cells (future remains non-interactive). The view stays pure
presentation — it doesn't know what happens on tap.

**Changes**:
- `Kado/UIComponents/MonthlyCalendarView.swift`:
  - Add `var onTapDay: ((Date) -> Void)? = nil` property (default
    nil preserves all existing callers / previews).
  - In `cell(for:)`, attach `.onTapGesture { onTapDay?(day) }` only
    when `state(for: day) != .future`. Future cells remain
    non-interactive.
  - Add `.accessibilityHint(Text("Double-tap to edit this day."))`
    on non-future cells. Gate so VoiceOver doesn't announce a hint
    on future cells.
  - Add `.contentShape(Rectangle())` on the cell so the whole cell
    area (not just filled pixels) is hittable.
  - Add `.sensoryFeedback(.selection, trigger: lastTappedDay)` at
    the grid scope if we track the last-tapped day; optional — can
    also live on the detail view. Keep here if it's clean.

**Tests / verification**:
- Existing previews still render without callbacks wired.
- Build cleanly: `build_sim`.
- Manual: run the app, confirm future cells don't respond to taps;
  past cells trigger the callback (temporarily print `onTapDay` in
  a preview harness to verify).

**Commit**: `feat(calendar): expose per-day tap callback on past cells`

---

### Task 3: `DayEditPopover` view + localization

**Goal**: Standalone SwiftUI view that, given a habit and a date,
renders the right edit control for that habit's type. Full preview
coverage for all four types + a dark preview. Not yet integrated
into `HabitDetailView`.

**Changes**:
- New file `Kado/Views/HabitDetail/DayEditPopover.swift`:
  - Inputs: `habit: Habit` (snapshot for display), `date: Date`,
    `currentValue: Double` (0 if no record), callbacks for each
    habit type's mutation (`onToggle`, `onSetCounter(Double)`,
    `onSetTimerSeconds(TimeInterval)`, `onClear`).
  - Layout mirrors `CellPopoverContent`: header (icon + name),
    date subtitle, then the type-specific control.
  - Binary / negative: a primary button ("Mark complete" / "Mark
    missed" / "Unmark" — copy inverted for negative) that calls
    `onToggle` and auto-dismisses.
  - Counter: stepper + "Clear" button. Cap max at `target × 3` or
    99, whichever is lower, to avoid runaway.
  - Timer: minute stepper (1-min increments, default to a useful
    max like 180 min) + "Clear" button.
  - Use semantic colors (`Color.primary`, `.secondary`, tint
    derived from habit color on action buttons).
- Localization: add catalog entries in
  `Kado/Resources/Localizable.xcstrings` with EN + hand-translated
  FR (per `docs/plans/2026-04/french-translations/` conventions —
  `tu`, `habitude` grammar):
  - "Mark complete" / "Marquer comme fait"
  - "Unmark" / "Annuler"
  - "Mark missed" / "Marquer comme raté" (negative habit)
  - "Unmark missed" / "Annuler" (negative habit)
  - "Clear" / "Effacer"
  - "Done" / "Terminé"
  - "Minutes" / "Minutes"
  - Any other copy introduced by the popover.

**Tests / verification**:
- Previews: one per habit type + one dark preview (pick the
  counter-partial state as the demanding one).
- `LocalizationCoverageTests` passes (FR parity enforced).
- `build_sim` clean; no unused-string warnings.

**Commit**: `feat(habit-detail): add DayEditPopover view`

---

### Task 4: Wire popover into `HabitDetailView`

**Goal**: Tapping a past or today cell in the detail view opens the
popover; actions in the popover mutate the habit's completions via
existing services. Archived habits stay non-interactive.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift`:
  - Add `@State private var editingDay: EditingDay? = nil` where
    `EditingDay` is a private `Identifiable` wrapper on `Date`.
  - Pass `onTapDay:` to `MonthlyCalendarView`, setting
    `editingDay = .init(date: day)` — but only when `!isArchived`.
  - Attach `.popover(item: $editingDay, attachmentAnchor: …)` (or
    anchor via `.overlay`/`PopoverAnchor`) rendering `DayEditPopover`.
    Use `.presentationCompactAdaptation(.popover)` to force popover
    on iPhone.
  - Compute `currentValue` for the tapped day from
    `habit.completions`.
  - Implement callback bodies:
    - Binary / negative → `CompletionToggler(calendar: calendar).toggleToday(for: habit, on: date, in: modelContext)`.
    - Counter → `CompletionLogger(calendar: calendar).setCounter(for: habit, on: date, to: value, in: modelContext)`.
    - Timer → `CompletionLogger(calendar: calendar).logTimerSession(for: habit, seconds: value, on: date, in: modelContext)`.
    - Clear → `setCounter(... to: 0, ...)` or `logTimerSession(... seconds: 0, ...)`.
  - After every mutation: `try? modelContext.save()` +
    `WidgetReloader.reloadAll(using: modelContext)` (existing
    pattern).

**Tests / verification**:
- `build_sim` clean.
- `test_sim` full suite green — existing detail-view tests should
  still pass.
- Manual in simulator (iPhone 17 Pro):
  1. Binary habit: tap past cell, popover opens, mark complete,
     dismiss, cell is now completed.
  2. Same cell again: tap, popover shows "Unmark," unmark, cell
     returns to missed.
  3. Counter habit: set value to target on a past day, popover
     stays open, close, cell shows completed.
  4. Timer habit: log 30 min on a past day; close; score /
     streak update.
  5. Negative habit: popover copy uses "Mark missed"/"Unmark."
  6. Future cell: tap does nothing.
  7. Archived habit: tap does nothing.
- Screenshot each state, drop into the compound doc.
- VoiceOver pass on the grid: hint reads, double-tap opens the
  popover, labels in the popover are accurate.
- Dynamic Type XXXL: popover body doesn't clip. If it does, fall
  back to sheet presentation for accessibility sizes — decision
  point during this task.

**Commit**: `feat(habit-detail): edit past-day completions via calendar popover`

---

## Risks and mitigation

- **Day-boundary drift** — `MonthlyCalendarView.state(for:)` and the
  service write path could disagree on "is this day D" if different
  `Calendar` instances are used. **Mitigation**: both read
  `@Environment(\.calendar)` in the detail view; pass that same
  calendar into both the view (implicitly via env) and the service
  constructors explicitly. Regression tests in task 1 lock this in.
- **Popover sizing under XXXL Dynamic Type** — controls may clip.
  **Mitigation**: during task 4 manual audit, measure; if clipped,
  fall back to a sheet via
  `.presentationCompactAdaptation(horizontal: .sheet, vertical: .popover)`
  or just `.sheet` at accessibility sizes. Note the chosen branch
  in the compound doc.
- **Tap target < 44 pt** — 32 pt cells are below HIG guidance.
  **Mitigation**: `.contentShape(Rectangle())` expands the hit
  region to the full grid cell (including 8 pt spacing). VoiceOver
  gets the full focusable element. Accept as a known constraint
  (calendar dates are traditionally compact); flag in the compound
  doc.
- **Counter runaway values** — user could spam +. **Mitigation**:
  cap stepper max (see task 3).
- **Toggling counter/timer via popover vs inline** — two UI paths
  for today's value. **Mitigation**: both call the same services;
  `@Query`-driven `HabitRecord.completions` re-renders both
  affordances in step. Verify during task 4 manual.
- **`.popover(item:)` requires `Identifiable`** — `Date` isn't.
  **Mitigation**: private `EditingDay` wrapper in the detail view.

## Open questions

- [ ] Month navigation is out of scope — if users reach for it once
      past-day editing exists, prioritize it in a follow-up. No
      action for this plan.

## Notes during build

- **Task 1**: The existing tests already passed with the new cases (no
  red first). Intentional — the services' date API is already correct;
  these are regressions against a hypothetical future "simplification."
- **Task 3**: SwiftUI `Text("\(Int) of \(Int) min")` interpolation
  needed a new catalog key `%lld of %lld min`; the counter control
  reuses the existing `%lld of %lld` key.
- **Task 4**: `CompletionLogger.logTimerSession(seconds: 0, …)` does
  **not** delete — it inserts a zero-value record. Routing the
  "stepped timer down to 0" path through `clear()` (which calls
  `logger.delete(existing)` after looking up the record) avoids
  leaving phantom records. Consider normalizing `logTimerSession`'s
  0-seconds behavior in a follow-up so the service API is consistent
  with `setCounter`'s delete-on-zero contract.
- **Popover anchoring**: Attached to `MonthlyCalendarView` as a whole
  (not per-cell) because routing popover content down into the view
  would require a generic type parameter. The popover's header shows
  the formatted date so there's no ambiguity, but the anchor point is
  the calendar's center, not the tapped cell. If that feels wrong in
  manual testing, two options: (a) lift the `@State` selection into
  `MonthlyCalendarView` and attach `.popover(isPresented:)` per cell
  with a generic `popoverContent: (Date) -> some View` closure (mirrors
  the Overview pattern); (b) adopt `.popoverAttachmentAnchor` with a
  `PopoverAttachmentAnchor.rect(…)` computed from the tapped cell's
  frame.
- **UI-automation limitation**: Tap primitives aren't available in the
  default XcodeBuildMCP install (`CLAUDE.md` flags this), so the
  simulator run only exercises the Today view — the popover itself
  needs a human visual pass. The SwiftUI previews compile successfully
  across all four habit types plus dark mode.

## Out of scope

- Month navigation (paging back through prior months).
- Changing `CompleteHabitIntent` (widget / Siri) to accept an
  arbitrary date — today-only is correct for the widget tap
  gesture.
- Bulk past-day editing (Overview-style for a single habit).
- Surfacing a hint banner / onboarding tooltip for discoverability —
  revisit if feedback shows confusion.
- Editing completions before `habit.createdAt` (current grid only
  shows the current month; not reachable until month navigation
  lands).
