---
# Research — Habit Detail view

**Date**: 2026-04-17
**Status**: draft
**Related**: [ROADMAP v0.1 — Habit Detail View](../../../ROADMAP.md), [new-habit-form compound](../new-habit-form/compound.md), [today-view compound](../today-view/compound.md), [habit-score-calculator compound](../habit-score-calculator/compound.md)

## Problem

Tapping a habit on Today only toggles today's completion. There's
no surface for the habit's history, streak, or current score —
and no way to edit or archive a habit. The detail view is the
central "zoom in on this habit" surface and the vehicle for three
v0.1 roadmap items: **habit score display**, **streak**, and
**edit/archive**.

Constraints framing the solution:

- **One visible habit at a time**. Push-navigation from Today.
- **StreakCalculator doesn't exist yet.** Needs TDD like the score
  calculator before UI consumption.
- **Edit mode reuses `NewHabitFormModel`.** The paired-enum pattern
  in the compound explicitly anticipated this.
- **Counter/timer completions still have no creation path** —
  today's tap is binary-only. Detail view is also the logical home
  for per-type quick-log affordances, but that can split from the
  "read-only detail" PR.
- **Scope discipline**: this risks becoming a mega-PR. Likely
  needs to split into 2-3 PRs.

## Current state of the codebase

What exists:

- [HabitScoreCalculator](../../../../Kado/Services/DefaultHabitScoreCalculator.swift) —
  current score + score history. Well-tested.
- [FrequencyEvaluator](../../../../Kado/Services/DefaultFrequencyEvaluator.swift) —
  `isDue(habit:on:completions:)`.
- [HabitRecord / CompletionRecord](../../../../Kado/Models/Persistence/) —
  full SwiftData layer.
- [NewHabitFormModel](../../../../Kado/ViewModels/NewHabitFormModel.swift) —
  create-only, but structure extends cleanly to edit.
- [TodayView row tap](../../../../Kado/Views/Today/TodayView.swift) —
  currently calls `toggle(record)` for binary/negative; counter/timer
  have `onTap: nil`.

What's missing:

- `StreakCalculator` (service + tests).
- `HabitDetailView` — any visualization.
- Monthly calendar component.
- Edit mode affordance.
- Archive / delete action.
- Counter/timer log input (out of scope for this PR — next PR).

## Proposed approach

**Split into two PRs** (this research scopes the first; the second
gets its own research when we're ready).

### PR A (this PR): **Habit Detail — read-only + edit + archive**

- Row in Today's list pushes to `HabitDetailView`.
- Detail shows: habit name, current score, current/best streak,
  monthly calendar of completions (past 30-ish days), frequency
  label, type label.
- Toolbar: **Edit** button opens `NewHabitFormView` in edit mode.
- Toolbar: **Archive** action (destructive, confirmed) sets
  `archivedAt = .now`. Archived habits disappear from Today
  (`@Query` filter already excludes them) but persist for history.
- No counter/timer log inputs yet. Binary/negative completion
  toggle stays on Today; the detail view doesn't duplicate it.

### PR B (next): **Counter/timer logging + advanced history**

- Per-type input in the detail view (stepper for counter, timer
  start/stop with Live Activity, note field).
- Extended history view (scroll past 30 days, see values).
- Defers until PR A ships so we can see which parts of the UI
  actually need the extra chrome.

### Key components (PR A)

- **`StreakCalculator`** (protocol + default impl): `.current` and
  `.best` for a given habit + completions + calendar, respecting
  frequency. TDD'd like the score calculator.
- **`HabitDetailView`**: single-screen layout, `@Bindable` on the
  `HabitRecord` it receives. Uses
  `@Environment(\.habitScoreCalculator, \.frequencyEvaluator, \.calendar)`.
- **`MonthlyCalendarView`** (in `UIComponents/`): 7-column grid,
  each cell one day; color encodes due / done / missed / future.
- **`NewHabitFormModel.editing(_ record: HabitRecord)` initializer**
  or a separate `HabitFormMode` enum (`.create` / `.edit(HabitRecord)`).
  Save path differs: edit updates in-place + saves; create inserts.
- **`TodayView` row tap target**: the row becomes a
  `NavigationLink` for the name/chevron area, while the leading
  checkmark circle stays the tap-to-toggle target for
  binary/negative. Small interaction design call — currently the
  whole row is one button.

### Tests to write

Business logic (Swift Testing, no `ModelContainer` needed for the
streak service — pure math over `[Completion]`):

```swift
@Test("Current streak is 0 when no completions exist")
@Test("Current streak counts consecutive completed days ending today")
@Test("Current streak skips non-due days (.specificDays)")
@Test("Current streak allows today to be uncomplete without breaking (grace)")
@Test("Best streak returns the longest run across history")
@Test("Best streak ≥ current streak by construction")
@Test(".daysPerWeek streaks count weeks meeting the quota")
@Test(".everyNDays streak resets on a missed due day")
@Test("A negative habit's streak is days WITHOUT completion")
```

UI: previews cover populated / empty / archived / each frequency.
No view-level tests.

### Data model changes

None required. `archivedAt` already exists on `HabitRecord`.

### UI changes

- `TodayView` row: split into navigation region + toggle region
  (or swap to `NavigationLink` with trailing toggle via
  `swipeActions` — TBD in plan).
- New `HabitDetailView`, `MonthlyCalendarView`.
- `NewHabitFormView` gains edit mode (title, Save button label,
  save action behavior).
- No changes to `Settings`.

## Alternatives considered

### Alternative A: Ship calendar + score only; defer streak and edit

- Idea: Minimum viable detail — just show the score and the last
  30 days. Edit/archive/streak in later PRs.
- Why not: This is what PR A already is, minus streak. Streak is a
  small, self-contained service with heavy TDD value; shipping it
  in the same PR as the view that displays it keeps the TDD loop
  tight. Edit/archive, on the other hand, are genuinely
  separable — the question is whether to split them.
- Decision: keep streak + edit + archive in PR A; they all feel
  like "the detail screen." If the PR balloons past 10 tasks or
  600 lines of code, split during the plan stage.

### Alternative B: Long-press on row for detail, tap stays toggle

- Idea: Keep today's tap-to-toggle; long-press navigates.
- Why not: Long-press is a discoverability problem (no visual
  affordance). iOS convention for "go deeper into a row" is
  tap + chevron or a disclosure pattern, not long-press.

### Alternative C: Separate Edit + Archive PRs

- Idea: PR A ships read-only detail; PR B adds edit; PR C adds
  archive.
- Why not: Three PRs for small additions to the same view is
  ceremony overhead. Edit-mode logic is a small diff on the
  existing form. Archive is one destructive-action button with a
  confirmation dialog. Keep them together; keep the PR shape
  predictable (~5 tasks).

### Alternative D: Tap-row-to-navigate, rely on swipe-to-complete

- Idea: Row tap always navigates. Swipe-right-from-left triggers
  completion.
- Why not: Breaks the current mental model ("tap = done") that
  just shipped. One user-visible regression per PR is plenty.
  Solution: make the leading checkmark circle the toggle target,
  the rest of the row the navigation target (iOS-standard split).

## Risks and unknowns

- **Scope creep**: calendar + streak + score + edit + archive in
  one PR. Mitigation: plan stage will break this into ~6 tasks,
  each with a working-state commit. If Task 4 starts feeling
  heavy, split into PR A and PR A-edit.
- **Streak definition for `.daysPerWeek`**: the score algorithm
  already decides "rolling 7-day window, compare count vs
  target." Streaks likely follow the same window, but semantics
  need confirming. Open question for the plan stage — a tiny
  doc like `docs/streak.md` might land in this PR, mirroring
  `habit-score.md`.
- **Negative habit streak semantics**: a streak of "days WITHOUT
  the negative behavior" inverts the completion logic. The test
  list covers it; the implementation will need a per-type branch.
- **Row tap split (toggle vs navigate)**: the current `Button`
  wraps the whole row. Splitting means two tap targets with
  clear affordances, which requires an interaction-design call
  and a row-layout change. Could regress the clean look.
- **Edit mode state sync**: the form holds draft state; saving
  must update the `HabitRecord` in place, which triggers a
  SwiftData update cascade. Test on the sim to make sure the
  Today list refreshes.
- **Calendar performance at scale**: 30-day calendar render
  computes per-day state (due / done). Fine at v0.1 — revisit
  when the range expands.

## Open questions

- [ ] **Scope of this PR**: detail view alone, or detail +
  streak + edit + archive bundled? *Recommendation*: bundle,
  with task-level splits during planning. Easier to see the
  screen's full shape in one reviewable PR.
- [ ] **Row split: toggle vs. navigate**: leading checkmark is
  the toggle target, rest of row is a `NavigationLink`? Or
  `swipeActions` to toggle and row tap navigates? *Recommendation*:
  leading-circle-toggle. Discoverable, matches the existing
  visual of the row.
- [ ] **Calendar range**: last 30 days, current calendar month,
  or scrollable? *Recommendation*: current calendar month in
  this PR. Scrollable history is PR B scope.
- [ ] **Archive UX**: "Archive" confirmed dialog, or swipe-to-
  archive in Today? *Recommendation*: detail-view button with
  confirmation dialog. Swipe actions in Today add visual noise
  for a rare action.
- [ ] **Delete vs. archive**: v0.1 roadmap says "Habit archive
  with history preservation" for v1.0. Do we offer *destroy*
  in v0.1, or only archive? *Recommendation*: archive only in
  this PR. Destroy lands with Settings' "erase all data" in a
  later PR.
- [ ] **Streak `docs/streak.md` spec**: write a small spec doc
  ahead of the service (like `habit-score.md`)? *Recommendation*:
  yes — the non-daily edge cases (daysPerWeek, everyNDays,
  negative) benefit from a short decision log that tests can
  cite.
- [ ] **Edit mode initial values**: reopen the form pre-filled
  from the record's current `name`/`frequency`/`type`. Trivial
  but decides whether `NewHabitFormModel` gets an `init(editing:)`
  or an `enum HabitFormMode`. *Recommendation*: `init(editing: HabitRecord)`
  — simpler, no branching on mode throughout the form.

## References

- [NavigationLink](https://developer.apple.com/documentation/swiftui/navigationlink)
- [LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid) — for the monthly calendar
- [confirmationDialog](https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:))
- [habit-score.md](../../../habit-score.md) — sibling spec the streak doc will mirror
- [new-habit-form compound — paired-enum pattern](../new-habit-form/compound.md) — the edit-mode reuse argument
