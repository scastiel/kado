---
# Research — New Habit form

**Date**: 2026-04-17
**Status**: ready for plan
**Related**: [ROADMAP v0.1 — New/Edit Habit View](../../../ROADMAP.md), [today-view compound](../today-view/compound.md), [swiftdata-models compound](../swiftdata-models/compound.md)

## Problem

The Today tab ships, but the app ships useless: there is no way to
create a habit from the UI. Every user who installs the app currently
sees "No habits yet" with no way forward. Until this PR lands, the
only way to populate the store is through SwiftUI previews.

Constraints framing the solution:

- **`HabitRecord` MVP fields**: `name`, `frequency`, `type`,
  `createdAt`. No icon, no color, no reminder. The form covers only
  these four — no data-model change.
- **Four `Frequency` variants, each with different params**
  (`.daily`, `.daysPerWeek(Int)`, `.specificDays(Set<Weekday>)`,
  `.everyNDays(Int)`) and **four `HabitType` variants** (`.binary`,
  `.counter(target:)`, `.timer(targetSeconds:)`, `.negative`). Each
  combination must be expressible cleanly.
- **Discoverable entry point**: a "+" button in the Today nav bar
  is the standard iOS pattern (Mail, Reminders, Notes all do this).
- **Create-only here; edit comes with the detail view.**
- **All strings must go through `String(localized:)`** per CLAUDE.md
  — even at MVP with only EN, so FR drops in cleanly at v1.0.

## Current state of the codebase

What exists:

- [HabitRecord](../../../../Kado/Models/Persistence/HabitRecord.swift) —
  `@Model`, defaults for every field, insertable into any
  `ModelContext`.
- [Frequency](../../../../Kado/Models/Frequency.swift) — four cases,
  nonisolated, Codable.
- [HabitType](../../../../Kado/Models/HabitType.swift) — four cases,
  Codable.
- [Weekday](../../../../Kado/Models/Weekday.swift) — `CaseIterable`,
  raw values aligned to `Calendar.component(.weekday, from:)`.
- [TodayView](../../../../Kado/Views/Today/TodayView.swift) — has a
  `NavigationStack` already; easy to attach a toolbar item.
- [PreviewContainer](../../../../Kado/Preview%20Content/PreviewContainer.swift) —
  already has `emptyContainer()` for empty-state previews.

What's missing:

- Anywhere in the UI that inserts a `HabitRecord`.
- Any component picker for `Frequency` / `HabitType`.
- An accessible "+" entry point in `TodayView`'s toolbar.

## Proposed approach

**One PR, scoped to create-only.** A sheet presented from Today's
nav-bar "+" button, driven by an `@Observable` `NewHabitFormModel`
that holds draft state. On Save, the model builds a `HabitRecord`
and inserts it into the injected `ModelContext`.

Why a ViewModel here (and not on Today)? This one crosses the
ViewModel threshold from CLAUDE.md: it mutates form state outside
any `@Query` (typed-by-user name, toggled weekdays, picked
frequency variant), and the validation predicate depends on
multiple fields. A free helper + `@State` fields would work but
the assembly of "current frequency case" from "picked tag + associated
value input" wants to live in a type.

### Key components

- **`NewHabitFormModel`** (`@Observable` class, `@MainActor`):
  - `name: String`
  - `frequencyKind: FrequencyKind` (`.daily | .daysPerWeek | .specificDays | .everyNDays` — a plain non-associated enum for Picker tagging)
  - `daysPerWeek: Int` (default 3)
  - `specificDays: Set<Weekday>` (default `[.monday, .wednesday, .friday]`)
  - `everyNDays: Int` (default 2)
  - `typeKind: HabitTypeKind` (`.binary | .counter | .timer | .negative`)
  - `counterTarget: Double` (default 1)
  - `timerTargetMinutes: Int` (default 10 — editor displays minutes; stored as seconds)
  - Computed `frequency: Frequency` assembles the final enum from `frequencyKind` + params.
  - Computed `type: HabitType` assembles the final enum from `typeKind` + params.
  - Computed `isValid: Bool` — non-empty trimmed name, plus per-kind validity (`daysPerWeek ∈ 1…7`, `specificDays.isEmpty == false`, `counterTarget > 0`, `timerTargetMinutes > 0`).
- **`NewHabitFormView`** — SwiftUI `Form` in a `NavigationStack`:
  - `TextField` for name (autofocused).
  - "Frequency" `Section`: `Picker` with 4 options. When a variant
    with params is picked, a second row appears (`Stepper` or
    weekday multi-toggle).
  - "Type" `Section`: same pattern.
  - Cancel/Save in toolbar. Save disabled until `isValid`.
- **Toolbar entry point in `TodayView`**: `.toolbar { plusButton }`
  opens a sheet bound to `@State showingNewHabit`.
- **Haptic on successful save**: reuse `.sensoryFeedback(.success, trigger:)`.
- **Weekday toggle UI**: 7 small capsule buttons in an `HStack`,
  each toggling membership in `specificDays`. Localized short
  labels ("M T W T F S S").

### Data model changes

None. `HabitRecord.init(...)` already takes every field with
defaults.

### UI changes

- `TodayView` gets a toolbar "+" item, presents `NewHabitFormView`
  as a sheet.
- New `NewHabitFormView` + `NewHabitFormModel`.
- New `WeekdayPicker` component in `UIComponents/`.

### Tests to write

Unit tests on the ViewModel (Swift Testing):

```swift
@Test("Initial state is invalid (empty name)")
@Test("A daily habit with a name becomes valid")
@Test(".daysPerWeek requires count between 1 and 7")
@Test(".specificDays requires a non-empty set")
@Test(".counter requires target > 0")
@Test(".timer requires target minutes > 0")
@Test("build() returns the assembled Frequency and HabitType")
@Test("Name whitespace is trimmed before validation")
```

No tests on the SwiftUI view itself — previews + manual simulator
testing suffice at MVP phase, per CLAUDE.md.

## Alternatives considered

### Alternative A: Free `@State` fields, no ViewModel

- Idea: Keep the form as a bag of `@State var name, @State var frequencyKind, …` properties in the view, with computed properties assembling the final `Frequency` / `HabitType`.
- Why not: Eight-plus `@State` fields, per-kind validation scattered across the view, and the assembly logic ends up duplicated between "Save disabled" and "Save action." A `@Observable` class collects this into one type with testable init/validate/build semantics. CLAUDE.md's ViewModel threshold is met.

### Alternative B: Full-screen `NavigationStack` push instead of sheet

- Idea: Push the form onto Today's nav stack instead of presenting modally.
- Why not: Creation is a modal task (user stops what they were doing, completes, returns). A push blurs the return path — back-button semantics feel wrong after Save. All reference habit trackers (Streaks, Loop, Things) use sheets. Sheet it is.

### Alternative C: Icon + color in v0.1

- Idea: Ship icon picker + color picker now, consistent with the compound iOS habit-tracker UX.
- Why not: `HabitRecord` has no icon/color fields — shipping them requires a migration. That's the opposite of MVP discipline. Defer to v0.2 or v1.0 polish; ROADMAP lists them there.

### Alternative D: Combined "advanced" frequency (`.everyNDays`) under "Custom" menu

- Idea: Only show `.daily`, `.daysPerWeek`, `.specificDays` as first-class picks; gate `.everyNDays` behind a "More…" row.
- Why not: Four equally legitimate frequencies, all one `Picker` row tall. Hiding one adds complexity, not clarity.

### Alternative E: Weekday picker using native `MultiDatePicker` or `Menu`

- Idea: Use Apple's `MultiDatePicker` for `.specificDays`.
- Why not: `MultiDatePicker` picks dates, not weekdays. A 7-capsule row is the right fit — seen in Shortcuts, Calendar events, standard HIG pattern.

## Risks and unknowns

- **`Stepper` with a `Double` value for `counterTarget`**: `Stepper`
  binds to `Double` cleanly but the step size needs tuning (1 for
  small targets, maybe larger for big ones). Probably fine with
  step 1 for v0.1; revisit if feedback surfaces friction.
- **Timer target stored as seconds but edited as minutes**: easy
  off-by-60 risk; the ViewModel must do exactly one conversion.
  Tests cover it.
- **Focus behavior**: `@FocusState` on the name field autofocuses
  on sheet appear. Standard iOS pattern but depends on iOS 18.
- **Dismiss-on-save haptic**: `.sensoryFeedback` needs a trigger
  value that increments on save — a simple counter or a `UUID`
  reset. Small detail.
- **Save keeps the sheet dismissed even if insert fails**: the
  insert path (`modelContext.insert(habit)` + optional
  `try? save()`) effectively can't fail for an in-memory operation,
  but if save throws (full disk, etc.), we currently swallow. For
  MVP that's acceptable — error surfaces on next launch as missing
  data. A toast for failure lands post-v0.1.

## Open questions

All resolved 2026-04-17:

- [x] **Icon + color**: deferred. `HabitRecord` has no fields; no
  schema migration just for the UI. Ship with detail view / polish.
- [x] **Presentation**: sheet from Today's "+" toolbar button.
- [x] **Save placement**: trailing toolbar.
- [x] **Dismiss on save**: yes, dismiss on successful save.
- [x] **`createdAt` exposure**: no, defaults to `.now`. Editing lands
  in detail-view edit mode.
- [x] **Default frequency + type**: `.daily` + `.binary`.

## References

- [SwiftUI Form](https://developer.apple.com/documentation/swiftui/form)
- [SwiftUI .sheet(isPresented:)](https://developer.apple.com/documentation/swiftui/view/sheet(ispresented:ondismiss:content:))
- [Picker](https://developer.apple.com/documentation/swiftui/picker)
- [Stepper](https://developer.apple.com/documentation/swiftui/stepper)
- [@FocusState](https://developer.apple.com/documentation/swiftui/focusstate)
- [HIG — Modality](https://developer.apple.com/design/human-interface-guidelines/modality)
- Prior-art UX: Things (sheet creation), Reminders (inline new item but separate sheet for detail), Streaks (sheet with multi-step flow)
- [today-view compound](../today-view/compound.md) — confirmed the `CompletionToggler` pattern for testable "write to ModelContext" helpers.
