---
# Plan — Today View

**Date**: 2026-04-17
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Wire the Today tab to real `HabitRecord` data. A `@Query` pulls
active habits, an in-memory filter (via `FrequencyEvaluator`) keeps
only those due today, and each row shows the habit in a full-width
row with a tap-to-toggle completion for binary and negative habits.
Counter and timer rows render read-only until the habit detail view
lands. Empty state stays text-only; the Create-habit flow is a
separate PR.

## Decisions locked in

- **No ViewModel**. `@Query` + computed properties + a small toggle
  helper are enough; a view model would be structure for structure's
  sake.
- **In-memory filtering** for "due today". `#Predicate` can't express
  `FrequencyEvaluator`'s `.daysPerWeek` 7-day lookback.
- **Full-row layout** with leading state indicator, habit name,
  trailing type-specific state.
- **Tap-to-toggle** for binary/negative (undo uses the same tap).
  Counter/timer taps are no-ops for now.
- **`.sensoryFeedback(.success, trigger:)`** wired to the
  "done today" boolean — fires on both complete and undo.
- **Empty state is text-only** (keep existing `ContentUnavailableView`
  copy; no button).
- **No score on the row** — the score belongs to the detail view.
- **`CompletionToggler` as a simple helper** (concrete struct,
  injected `Calendar`). No protocol yet — no test-time substitution
  need; refactor later if one appears.
- **Tests land on `CompletionToggler`**, not on the view. SwiftUI
  previews cover the view side.

## Task list

### Task 1: Add `frequencyEvaluator` to the environment ✅

**Goal**: Make `FrequencyEvaluating` injectable the same way
`HabitScoreCalculating` already is.

**Changes**:
- `Kado/App/EnvironmentValues+Services.swift`: add
  `FrequencyEvaluatorKey` and the computed property on
  `EnvironmentValues`.

**Tests / verification**:
- `build_sim` compiles clean.
- No runtime check needed yet — consumers arrive in Task 5.

**Commit message (suggested)**:
`feat(env): expose frequency evaluator through SwiftUI environment`

---

### Task 2: Write tests for `CompletionToggler` ✅

**Goal**: Red tests for the toggle helper before any implementation.

**Changes**:
- `KadoTests/CompletionTogglerTests.swift` (new): in-memory
  `ModelContainer` per test, asserts completion-list state after
  each toggle.

**Tests to write**:
- `@Test("Toggling a habit with no completion today inserts one with value 1")`
- `@Test("Toggling a habit with a completion today deletes it")`
- `@Test("Toggling a habit with a completion yesterday leaves yesterday alone and inserts a new one for today")`
- `@Test("Toggling twice returns to the original state")`
- `@Test("Toggle on DST-crossing day uses the injected calendar's startOfDay")`
  (use `Europe/Paris` TestCalendar, assert insertion/deletion
  anchors to local day)

**Verification**:
- `test_sim` — all new tests fail with a "not implemented" error or
  a `CompletionToggler` symbol-missing build error. Expected red
  state before Task 3 lands.

**Commit message (suggested)**:
`test(completion-toggler): add red-state tests for toggle-today helper`

---

### Task 3: Implement `CompletionToggler` ✅

**Goal**: Minimal struct that inserts or deletes today's
`CompletionRecord` for a given habit.

**Changes**:
- `Kado/Services/CompletionToggler.swift` (new):
  ```swift
  @MainActor
  struct CompletionToggler {
      let calendar: Calendar
      init(calendar: Calendar = .current) { self.calendar = calendar }

      func toggleToday(
          for habit: HabitRecord,
          on date: Date = .now,
          in context: ModelContext
      ) {
          if let existing = habit.completions.first(where: {
              calendar.isDate($0.date, inSameDayAs: date)
          }) {
              context.delete(existing)
          } else {
              let completion = CompletionRecord(
                  date: date,
                  value: 1.0,
                  habit: habit
              )
              context.insert(completion)
          }
      }
  }
  ```
- Uses `calendar.isDate(_:inSameDayAs:)` for day comparison (DST-safe
  per CLAUDE.md's calendar conventions).

**Tests / verification**:
- `test_sim` — all Task 2 tests pass.
- Full suite still green.

**Commit message (suggested)**:
`feat(completion-toggler): toggle today's completion for a habit`

---

### Task 4: Build `HabitRowView` ✅

**Goal**: A reusable row that renders any habit type, with an
optional tap action for binary/negative.

**Changes**:
- `Kado/UIComponents/HabitRowView.swift` (new):
  - Inputs: `habit: Habit` (value-type snapshot),
    `isCompletedToday: Bool`, `onTap: (() -> Void)?`.
  - Binary/negative: leading filled/empty circle with SF Symbol
    (`checkmark.circle.fill` vs `circle`); the whole row is a
    `Button` with the closure; trailing is empty.
  - Counter: leading neutral symbol (e.g. `number.circle`);
    trailing "progress" label (`"–/\(target)"` since the actual
    value lives in the completion; MVP shows only the target).
  - Timer: leading `timer` symbol; trailing target in `mm:ss`.
  - No-tap types render as plain `HStack` rows (no Button), so no
    hover/tap affordance.
  - `.sensoryFeedback(.success, trigger: isCompletedToday)` on the
    outer view.
- Accessibility: `accessibilityLabel` combining name + state
  ("Meditation, done" / "Gym, not done"), `accessibilityHint`
  ("Double tap to toggle completion") for interactive rows.
- Previews: 8 permutations (4 types × done/not-done).

**Tests / verification**:
- `build_sim` clean.
- Preview screenshot for manual visual check.
- Dynamic Type XXXL smoke-check via preview trait.

**Commit message (suggested)**:
`feat(today): add HabitRowView for Today list rendering`

---

### Task 5: Wire `TodayView` ✅

**Goal**: Replace the placeholder with a working list.

**Changes**:
- `Kado/Views/Today/TodayView.swift` (rewrite):
  - `@Query` with `#Predicate<HabitRecord> { $0.archivedAt == nil }`
    sorted by `createdAt`. Fallback path (if predicate fails at
    runtime): `@Query(sort: \.createdAt)` and filter archived in
    the computed property.
  - `@Environment(\.modelContext)`, `@Environment(\.frequencyEvaluator)`,
    `@Environment(\.calendar)`.
  - Computed `habitsDueToday: [HabitRecord]` applies
    `FrequencyEvaluator.isDue` using each record's snapshot +
    completions-as-snapshots.
  - `isCompletedToday(_:)` helper on the view checks for any
    completion on today's day.
  - For binary/negative rows, `onTap` calls
    `CompletionToggler(calendar: calendar).toggleToday(for:in:)`.
  - Counter/timer rows pass `nil` for `onTap`.
  - Empty state: keep `ContentUnavailableView` as-is (title "No
    habits yet", description "Habits you create will appear here.").
  - A separate "Nothing due today" state kicks in when
    `activeHabits.isEmpty == false` but `habitsDueToday.isEmpty`.
- Previews:
  - Populated: `.modelContainer(PreviewContainer.shared)`.
  - Empty (no habits): in-memory container, no seed.
  - Nothing due today: in-memory container with one archived habit
    or one with `.specificDays` not matching today.

**Tests / verification**:
- `build_sim` clean.
- `test_sim` still green.
- Launch on iPhone 16 Pro sim, verify:
  - Populated list renders with correct today-state per habit.
  - Tap a binary habit → haptic fires, row checks.
  - Tap again → haptic fires, row unchecks.
  - Tap a counter/timer → no change, no haptic.
  - After app restart, toggled state persists (SwiftData autosave).
- `screenshot` capture for the PR.

**Commit message (suggested)**:
`feat(today): list habits due today and tap-to-toggle completion`

---

### Task 6: (Optional) UI polish pass — skipped

No issues surfaced during Task 5 that warrant a polish pass. Empty
state renders cleanly in the simulator; previews cover populated
and "nothing due today" states. Counter/timer trailing labels show
target only (no today's value) because there's no path to create
counter/timer completions until the detail view ships — revisit
when that lands.

## Notes during build

- **Task 5 manual verification**: the production `ModelContainer` is
  file-backed and starts empty, so tap-to-toggle couldn't be tested
  end-to-end on the simulator in this PR. Previews cover the
  populated rendering. Full manual verification (tap → haptic →
  persisted state) unlocks once the Create-habit PR lands.
- **XcodeBuildMCP destination flakiness**: `build_sim` and
  `test_sim` occasionally fail with
  `Unable to find a destination matching { platform:iOS Simulator, OS:latest, name:iPhone 17 Pro }`
  even though the sim is booted and iOS 26.4 simulator SDK is
  installed. The error cites the missing iOS 26.4 device SDK —
  xcodebuild seems to walk all scheme destinations and give up
  when device-side resolution fails. Workaround: shut down and
  reboot the simulator, then rerun. Cleaning DerivedData also
  helps. Worth promoting as a CLAUDE.md lesson.
- **`#Predicate<HabitRecord> { $0.archivedAt == nil }` worked first
  try** — the fallback path (unfiltered `@Query` + in-memory
  archive filter) stayed a spec-only contingency.
- **`.sensoryFeedback(.success, trigger: isCompletedToday)` on the
  outer view** fires on both true→false and false→true transitions,
  giving tactile confirmation on tap and undo. No first-render
  spurious fire observed.

## Risks and mitigation

- **`#Predicate` on `archivedAt == nil` may hit a toolchain quirk.**
  Mitigation: Task 5's fallback path — unfiltered `@Query`, filter
  in memory. Cost is negligible at ≤50 habits (v0.1 scale).
- **`.sensoryFeedback` may fire on first render if `isCompletedToday`
  is initially true.** Mitigation: verify on simulator. Fix with
  `.sensoryFeedback(trigger:action:)` (the transform variant) if
  needed, only firing on `false → true` transitions.
- **ModelContext writes on MainActor.** `CompletionToggler` is
  marked `@MainActor`. The view body is already on MainActor.
  Tests call it from MainActor-isolated test cases
  (`@MainActor struct`).
- **Daily rollover while app is open** (past midnight). Out of
  scope for this PR — noted in research, fix lands with a
  `ScenePhase` observer later.
- **Counter/timer read-only rendering might confuse users** who
  expect to interact. Mitigation: trailing label makes state
  visible; onboarding/detail-view PR will address interaction.

## Open questions

None — all resolved in research.

## Out of scope

- Create-habit flow (next PR).
- Habit detail view (later PR).
- Counter / timer interaction (detail view PR; timer also needs
  Live Activities design, v0.3).
- Swipe-to-archive and long-press actions on rows.
- App icon, colors, icon picker per habit.
- Past-midnight refresh.
- Score badge on the row (deliberately deferred).
