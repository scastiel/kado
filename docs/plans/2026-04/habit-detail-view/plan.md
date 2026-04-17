---
# Plan — Habit Detail view

**Date**: 2026-04-17
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Ship the Habit Detail screen: reached by tapping a Today row's
non-toggle region, shows name, current score, current/best
streak, frequency + type labels, and a current-month calendar of
completions. Toolbar offers Edit (reuses the form) and Archive
(confirmed dialog). New `StreakCalculator` service lands with a
spec doc. Counter/timer logging and scrollable history are PR B.

## Decisions locked in

- **Bundle streak + detail + edit + archive** in this PR.
  Task-level splits keep commits reviewable.
- **Row split**: leading circle stays the toggle target;
  everything else is a `NavigationLink` to detail. Counter/timer
  rows (which have no toggle today) become fully tap-to-navigate.
- **Calendar range**: current calendar month grid. Past months
  are out of scope.
- **Archive**: sets `archivedAt = .now`. `@Query` already excludes
  archived habits from Today. No un-archive UI in this PR — that
  lands with an archive browser.
- **Destroy**: not in v0.1. Settings' "erase all data" handles it
  later.
- **Spec doc `docs/streak.md`** lands in Task 1, before the
  service. Mirrors `habit-score.md`'s shape.
- **`NewHabitFormModel.init(editing: HabitRecord)`**: pre-fills
  all fields, remembers the source record for in-place update on
  save.
- **`StreakCalculator` is protocol-defined + env-injected**,
  matching the score / frequency pattern.
- **Detail view does not duplicate tap-to-toggle**. Completion
  toggling stays on Today; detail is read-only for completions
  (PR B adds counter/timer inputs).
- **No data-model changes.** `archivedAt` already exists.

## Task list

### Task 1: Write `docs/streak.md` spec

**Goal**: Pin down streak semantics across frequencies before any
code.

**Content**:
- Definition: current streak = consecutive "due days" ending at
  today where the habit was completed. Today itself doesn't break
  a streak if not yet done ("grace day").
- Best streak: longest such run in the habit's history.
- Per-frequency semantics:
  - `.daily`: every day is a due day.
  - `.specificDays(Set)`: only listed weekdays count.
  - `.everyNDays(N)`: every Nth day from `createdAt`.
  - `.daysPerWeek(N)`: streak measured in **weeks** — a week
    counts if ≥ N completions land in it.
- Negative habits: streak is days WITHOUT a completion in the
  due window.
- Archived habits: streak computed as of `archivedAt`, not today.

**Verification**: doc exists, links from ROADMAP if appropriate.

**Commit**: `docs(streak): specify streak semantics`

---

### Task 2: Red tests for `StreakCalculator`

**Goal**: TDD on the streak service.

**Changes**:
- `KadoTests/StreakCalculatorTests.swift` (new): Swift Testing
  cases using `TestCalendar` helper.

**Cases**:
- `@Test("No completions → current 0 and best 0")`
- `@Test("10 consecutive daily completions → current 10, best 10")`
- `@Test("Today uncomplete is a grace day (streak not broken)")`
- `@Test("Yesterday uncomplete breaks the streak")`
- `@Test(".specificDays skips non-due weekdays without breaking")`
- `@Test(".everyNDays streak breaks on a missed due day")`
- `@Test(".daysPerWeek(3) streak counts qualifying weeks")`
- `@Test("Negative habit streak counts days without completion")`
- `@Test("best ≥ current by construction")`
- `@Test("Archived habit streak is computed as of archivedAt, not .now")`

**Verification**: `test_sim` — all fail (symbol missing). Use the
`OS=26.4.1` bash fallback if MCP flakes.

**Commit**: `test(streak): red-state tests for StreakCalculator`

---

### Task 3: Implement `StreakCalculator` + env key

**Goal**: Protocol, default impl, environment injection.

**Changes**:
- `Kado/Services/StreakCalculating.swift` (protocol).
- `Kado/Services/DefaultStreakCalculator.swift`.
- `Kado/App/EnvironmentValues+Services.swift` — add
  `streakCalculator` env key alongside `habitScoreCalculator` /
  `frequencyEvaluator`.

**Verification**: `test_sim` green, no new warnings.

**Commit**: `feat(streak): implement current/best streak calculator`

---

### Task 4: Build `MonthlyCalendarView`

**Goal**: Reusable current-month grid.

**Changes**:
- `Kado/UIComponents/MonthlyCalendarView.swift` (new):
  - Inputs: `habit: Habit`, `completions: [Completion]`,
    `month: Date = .now`, `calendar: Calendar = .current`.
  - 7-column `LazyVGrid`, one cell per day of the displayed
    month. Leading blanks fill alignment to Monday (locale-
    default first weekday is acceptable here since the grid is
    aligned by header row).
  - Cell states:
    - Future: muted
    - Non-due: light outline
    - Due & completed: filled accent
    - Due & missed: filled muted-red
    - Today: always bordered
  - Accessibility label per cell ("April 14, completed").
- Previews: typical month with mixed state; empty history;
  archived habit.

**Verification**: `build_sim` clean; previews render on iPhone
and iPad.

**Commit**: `feat(monthly-calendar): add current-month completion grid`

---

### Task 5: Build `HabitDetailView`

**Goal**: The detail screen itself.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift` (new):
  - `let habit: HabitRecord`
  - `@Environment(\.habitScoreCalculator, \.frequencyEvaluator, \.streakCalculator, \.calendar, \.modelContext, \.dismiss)`
  - Layout (vertical): header (name, frequency label, type label,
    archived badge if applicable), score card ("87%"), streaks
    card ("Current 14 / Best 22"), `MonthlyCalendarView`.
  - Toolbar: Edit + Archive (the Archive confirmation + edit
    wiring arrive in Tasks 7–8; stub them as disabled buttons
    now so the layout is testable).
- Previews: each frequency type, archived state, no-completions
  state.

**Verification**: `build_sim` clean; preview renders each state.

**Commit**: `feat(habit-detail): add read-only detail screen`

---

### Task 6: Wire Today row split + navigation

**Goal**: Split Today's row into toggle region (leading circle)
and navigate region (the rest), push to `HabitDetailView`.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift`:
  - Change top-level structure: leading icon becomes its own
    `Button` (binary/negative only, no-op otherwise), rest of
    row becomes a `NavigationLink` region.
  - Preserve `onTap: (() -> Void)?` contract for the toggle.
  - Add `onNavigate: (() -> Void)?` or switch the parent to pass
    a `NavigationLink` destination directly.
- `Kado/Views/Today/TodayView.swift`:
  - `NavigationLink(value: record)` wrapping the row content
    (minus the toggle circle), combined with
    `navigationDestination(for: HabitRecord.self) { HabitDetailView(habit: $0) }`.
- Verify: tapping the circle still toggles; tapping anywhere else
  pushes to detail.

**Verification**:
- `build_sim` clean; `test_sim` green.
- Manual sim run: tap circle → toggle; tap name area → navigate;
  pull back → list unchanged.
- `screenshot` the detail view for the PR.

**Commit**: `feat(today): navigate to habit detail on row tap`

---

### Task 7: `NewHabitFormModel.init(editing:)` + edit-mode save path

**Goal**: Reuse the form for editing.

**Changes**:
- `Kado/ViewModels/NewHabitFormModel.swift`:
  - Add `private(set) var editingRecord: HabitRecord?`.
  - Add `convenience init(editing record: HabitRecord)` that
    pre-fills `name`, `frequencyKind` + params, `typeKind` +
    params from the record's current state. Maps counter
    targets and timer seconds → minutes.
  - `build()` stays the same for create. Add `applyEdits()` that
    mutates `editingRecord` in place when set. Expose a
    `save(in: ModelContext)` helper that picks the right path.
  - Tests: new cases covering "init with editing record fills
    every field", "timer seconds round-trip through minutes
    cleanly", "applyEdits mutates the record's fields".
- `Kado/Views/NewHabit/NewHabitFormView.swift`:
  - Title: "Edit habit" when `editingRecord != nil`, else "New
    habit".
  - Save button calls `model.save(in: modelContext)` and dismisses.
  - Haptic still fires.

**Verification**: `test_sim` green; open a record via edit, see
pre-filled values, edit and save, return to detail with updates
visible.

**Commit**: `feat(new-habit-form): support editing an existing habit`

---

### Task 8: Detail toolbar — Edit + Archive with confirmation

**Goal**: Wire the two actions on `HabitDetailView`.

**Changes**:
- Edit: `ToolbarItem(placement: .primaryAction) { Button("Edit") { showingEdit = true } }`; sheet presents
  `NewHabitFormView(model: NewHabitFormModel(editing: habit))`.
- Archive: `Menu` on a trailing ellipsis containing "Archive"
  action that triggers `.confirmationDialog`. On confirm:
  `habit.archivedAt = .now; try? modelContext.save(); dismiss()`
  (pops back to Today, where `@Query` excludes it).
- Archived habits show "Archived" badge in the header and grey
  out the toolbar actions (no re-editing archived items in this
  PR).

**Verification**:
- Manual: edit flow preserves fields, archive flow confirms +
  removes from Today.
- `test_sim` remains green.

**Commit**: `feat(habit-detail): wire edit sheet and archive action`

---

### Task 9: (Optional) polish

Reserved for issues uncovered during Tasks 6–8 — a11y labels,
empty-state copy, dark-mode checks, Dynamic Type XXXL pass on the
calendar.

## Risks and mitigation

- **Row split may regress the current Today look/feel**:
  Mitigation: screenshot before/after, aim for "same pixels
  except the tap target split is invisible to the eye."
- **`NavigationLink(value:)` + `navigationDestination(for:)`
  requires a `Hashable` route type**: `HabitRecord` is a
  SwiftData `@Model` — `Hashable` by identity. Confirm during
  Task 6. Fallback: push via `NavigationStack` path binding.
- **Edit mode + SwiftData**: mutating the record's fields via
  the computed accessors (`frequency`, `type`) triggers JSON
  blob re-encode — confirmed safe from the persistence PR.
- **`StreakCalculator` `.daysPerWeek` semantics** need settling
  in `docs/streak.md` before tests. Reuses the "rolling 7-day
  window" call from the score algorithm for consistency.
- **Archive confirmation dismiss**: after confirming archive, we
  call `dismiss()` on the detail view; verify the nav stack pops
  correctly on iPhone and iPad.
- **XcodeBuildMCP destination flake**: use the CLAUDE.md
  three-step escalation when it bites.

## Open questions

None — all resolved in research.

## Out of scope

- Un-archive UI (archive browser in Settings later).
- Hard-delete (Settings "erase all data").
- Counter/timer quick-log on detail (PR B).
- Score history graph (PR B).
- Scrollable past-months calendar (PR B).
- Notes on completions (post-v0.1).
- Sharing / export from detail (v0.2+).
