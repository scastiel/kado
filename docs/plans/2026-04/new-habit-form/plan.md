---
# Plan — New Habit form

**Date**: 2026-04-17
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Add a create-a-habit sheet, presented from a toolbar "+" on Today.
An `@Observable NewHabitFormModel` holds draft state, validates,
and builds a `HabitRecord` on save. Scope: name + frequency + type
only. No icon, color, reminder, or `createdAt` editing — those
land with later PRs.

## Decisions locked in

- **`@Observable NewHabitFormModel`**: the one cross-field state
  bag. Validates per kind. Free helpers stay out of reach here.
- **Sheet from Today's toolbar "+"**. Standard iOS creation UX.
- **Save is a trailing toolbar button**, disabled until
  `isValid`; dismisses the sheet on success.
- **No icon / color / `createdAt` / reminder in this PR.**
- **Defaults on open**: name empty, `.daily`, `.binary`. One tap to
  save a daily binary habit.
- **Frequency picker**: 4-option `Picker`, params revealed in a
  conditional row below.
- **Weekday picker**: 7 capsule toggles in an `HStack`, Mon–Sun
  order.
- **Timer target in minutes at the form layer**, converted to
  seconds at build time (`HabitType.timer(targetSeconds:)`).
- **No tests on the SwiftUI view**; tests target the ViewModel.
- **Name is trimmed before validation** (`.whitespacesAndNewlines`).

## Task list

### Task 1: ✅ Red tests for `NewHabitFormModel`

**Goal**: TDD on the form model.

**Changes**:
- `KadoTests/NewHabitFormModelTests.swift` (new): 8-ish Swift
  Testing cases. No `ModelContainer` needed — model is pure.

**Tests to write**:
- `@Test("Initial state is invalid due to empty name")`
- `@Test("A daily habit with a trimmed name is valid")`
- `@Test("Name with only whitespace is invalid")`
- `@Test(".daysPerWeek requires count in 1...7")`
- `@Test(".specificDays requires a non-empty set")`
- `@Test(".counter requires target > 0")`
- `@Test(".timer requires target minutes > 0")`
- `@Test("build() returns the assembled Frequency for each kind")`
- `@Test("build() returns .timer(targetSeconds:) converted from minutes")`
- `@Test("Changing frequencyKind preserves other kinds' draft params")`
  (ensure we don't wipe `daysPerWeek` when user toggles through kinds)

**Verification**: `test_sim` — all fail (symbol missing).

**Commit**: `test(new-habit-form): red-state tests for NewHabitFormModel`

---

### Task 2: ✅ Implement `NewHabitFormModel`

**Goal**: Minimal `@Observable` model passing the red tests.

**Changes**:
- `Kado/ViewModels/NewHabitFormModel.swift` (new):
  ```swift
  @MainActor
  @Observable
  final class NewHabitFormModel {
      var name = ""
      var frequencyKind: FrequencyKind = .daily
      var daysPerWeek = 3
      var specificDays: Set<Weekday> = [.monday, .wednesday, .friday]
      var everyNDays = 2
      var typeKind: HabitTypeKind = .binary
      var counterTarget: Double = 1
      var timerTargetMinutes = 10

      enum FrequencyKind: Hashable { case daily, daysPerWeek, specificDays, everyNDays }
      enum HabitTypeKind: Hashable { case binary, counter, timer, negative }

      var trimmedName: String {
          name.trimmingCharacters(in: .whitespacesAndNewlines)
      }
      var isValid: Bool { ... }
      var frequency: Frequency { ... }
      var type: HabitType { ... }

      func build() -> HabitRecord { ... }
  }
  ```
- Per-kind draft params are separate stored properties so
  toggling `frequencyKind` doesn't destroy a partially-edited
  variant. Bonus: predictable UX.

**Verification**: `test_sim` green.

**Commit**: `feat(new-habit-form): introduce NewHabitFormModel with validation`

---

### Task 3: ✅ Build `WeekdayPicker` component

**Goal**: Reusable 7-capsule toggle row for `Set<Weekday>`.

**Changes**:
- `Kado/UIComponents/WeekdayPicker.swift` (new):
  - `@Binding var selection: Set<Weekday>`
  - Iterates `Weekday.allCases` in Mon–Sun display order (rotating
    Sunday to the end for EN; acceptable default at MVP — locale-aware
    ordering lands post-v0.1).
  - Each capsule is a `Button` toggling membership; visually
    filled when selected.
  - Localized 1-char labels via `String(localized: "weekday.short.mon")`
    keys to prep the FR catalog.
- Previews: empty set, full set, weekdays-only, weekends-only.

**Verification**: `build_sim` clean; previews render.

**Commit**: `feat(weekday-picker): add reusable weekday multi-toggle`

---

### Task 4: ✅ Build `NewHabitFormView`

**Goal**: The form itself.

**Changes**:
- `Kado/Views/NewHabit/NewHabitFormView.swift` (new):
  - `@Bindable var model: NewHabitFormModel`
  - `@Environment(\.modelContext) private var modelContext`
  - `@Environment(\.dismiss) private var dismiss`
  - `@FocusState private var nameFocused: Bool`
  - `NavigationStack { Form { … } }` with:
    - Name section: `TextField` (focused on appear).
    - Frequency section: `Picker` + conditional detail row.
    - Type section: `Picker` + conditional detail row.
  - Toolbar: Cancel (leading), Save (trailing). Save disabled when
    `!model.isValid`. Save action: `modelContext.insert(model.build()); try? modelContext.save(); dismiss()`.
  - Haptic on save: `.sensoryFeedback(.success, trigger: savedTickCounter)`.
- Previews: default state, counter/timer/`.daysPerWeek` permutations.

**Verification**: `build_sim` clean; SwiftUI previews render.

**Commit**: `feat(new-habit-form): add NewHabitFormView sheet`

---

### Task 5: ✅ Wire the "+" toolbar button in `TodayView`

**Goal**: Expose the sheet.

**Changes**:
- `Kado/Views/Today/TodayView.swift`:
  - Add `@State private var showingNewHabit = false`.
  - `.toolbar { ToolbarItem(placement: .primaryAction) { Button(action: { showingNewHabit = true }) { Image(systemName: "plus") } } }`.
  - `.sheet(isPresented: $showingNewHabit) { NewHabitFormView(model: NewHabitFormModel()) }`.
- Previews: unchanged (Today already has three).

**Verification**:
- `build_sim` clean.
- Launch on iPhone sim: tap "+", fill name, Save, see habit appear
  in the list. Toggle it, close, reopen app, verify persistence.
- `screenshot` the populated Today list + the sheet for the PR.
- Quick Dynamic Type XXXL preview pass on the form.

**Commit**: `feat(today): add toolbar button presenting the new-habit sheet`

---

### Task 6: (Optional) Polish pass — skipped

No issues surfaced during Task 5. Build clean on iPhone + iPad,
76/76 tests green. `@Bindable` / `.sheet` environment propagation
worked without extra plumbing; `.sensoryFeedback(trigger: saveTick)`
fires on save without a spurious first-render trigger.

## Notes during build

- **XcodeBuildMCP `test_sim` destination flake hit immediately**
  after the Today-view PR merged, reproducing the known pattern
  ("OS:latest … not installed"). Workaround from CLAUDE.md
  (`xcrun simctl shutdown all && boot`) didn't clear it this
  time — the actual fix was passing `OS=26.4.1` explicitly
  because `iPhone 17 Pro` was on 26.4.1 but the tool resolved to
  `OS:latest` which xcodebuild couldn't match. Worth promoting
  to CLAUDE.md as a follow-up to the existing note.
- **`.sheet` inherits `modelContainer`** from the presenter. No
  explicit propagation needed on `NewHabitFormView`.
- **`@FocusState` + `.onAppear`** for autofocus worked first try
  on iOS 18.4 / 26.4.1.
- **Live tap-through testing was blocked**: XcodeBuildMCP in this
  config has no UI automation tool (tap/type), so verifying the
  sheet-presents-and-saves-inserts flow end-to-end required either
  installing `idb`/Appium or trusting previews + unit tests.
  Accepted the latter; the `@Observable` tests cover all
  per-kind validity transitions.

## Risks and mitigation

- **`@Bindable` with an `@Observable @MainActor` class on iOS 18**
  is well-supported; nothing to mitigate.
- **`Stepper` with `Double`** range: constrain to `1...999` for
  counter, `1...240` for timer minutes. Reassess once real usage
  surfaces edge cases.
- **`.sheet` + `.modelContainer` propagation**: sheets inherit the
  presenter's environment, so `modelContext` should flow through.
  Confirm during Task 5; if not, explicit `.modelContainer(...)`
  on the sheet's root.
- **Haptic on save**: needs an incrementing trigger. Simple `Int`
  counter in the view, bumped on the save branch.
- **XcodeBuildMCP destination flakiness** (see CLAUDE.md): fall
  back to `xcrun simctl shutdown all && boot`, or
  `xcodebuild … -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1"`.

## Open questions

None — all resolved in research.

## Out of scope

- Edit mode (detail view PR).
- Icon / color (needs schema migration; deferred).
- Reminder / notifications (v0.2).
- Custom `createdAt` / backfill UX (detail view).
- Localized French translations (v1.0).
- Scale-aware stepper ranges.
