# Plan — Habit Notes

**Date**: 2026-04-29
**Status**: done
**Research**: [research.md](./research.md)

## Summary

Add per-day free-text notes on habit completions, surfacing the
existing `CompletionRecord.note: String?` field that has shipped
unused since v0.1. Users can attach a note in the day-edit popover,
see notes in the completion history list, and spot annotated days via
a small dot on the calendar grid. Notes are standalone — they can
exist on days without a completion (creating a zero-value record).

## Decisions locked in

- Notes live on `CompletionRecord.note` — no new model, no migration
- Standalone notes allowed (zero-value completion holds the note)
- 500-character limit enforced in the UI
- Small dot indicator on calendar days that have a note
- Note editing happens in `DayEditPopover`, not a separate sheet
- Notes are app-only — not exposed in widget snapshots

## Task list

### Task 1: CompletionLogger note mutation methods

**Goal**: Add service methods to set/clear notes on completions.

**Changes**:
- `Kado/Services/CompletionLogger.swift` — add `setNote(for:on:to:in:)`
  that upserts a note on an existing completion or creates a
  zero-value completion to hold a standalone note. Add
  `clearNote(for:on:in:)` as a convenience.

**Tests / verification**:
- Set note on existing completion — note persists, value unchanged
- Set note on day without completion — creates zero-value record
- Clear note — sets `note` to nil
- Update note — overwrites previous note

**Commit message**: `feat(habit-notes): add note mutation to CompletionLogger`

---

### Task 2: DayEditPopover note input

**Goal**: Add a collapsible note text field to the day-edit popover.

**Changes**:
- `Kado/Views/HabitDetail/DayEditPopover.swift` — add `currentNote:
  String?` and `onNoteChanged: (String?) -> Void` parameters. Add a
  collapsible `TextField` section below the type-specific control,
  above the clear button. "Add a note..." placeholder when empty;
  shows the note text when populated. 500-char limit. For
  binary/negative types: keep popover open after toggle when the note
  field has focus (don't auto-dismiss).
- Update all `#Preview` blocks with note variants.

**Tests / verification**:
- Preview: binary with note, counter with note, timer with note
- Preview: dark mode with note
- Manual: type a note, dismiss, reopen — note persists
- Manual: binary toggle doesn't dismiss while note field is focused

**Commit message**: `feat(habit-notes): add note input to DayEditPopover`

---

### Task 3: Wire notes through HabitDetailView

**Goal**: Connect the popover note callbacks to `CompletionLogger`.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift` — add
  `currentNote(on:)` helper (mirrors `currentValue(on:)`). Add
  `setNote(_:on:)` method that calls `CompletionLogger.setNote`.
  Pass `currentNote` and `onNoteChanged` to `DayEditPopover`.

**Tests / verification**:
- Build succeeds with no warnings
- Manual: add note via popover, verify it's saved

**Commit message**: `feat(habit-notes): wire note callbacks in HabitDetailView`

---

### Task 4: Display notes in CompletionHistoryList

**Goal**: Show notes as a secondary line in the history list rows.

**Changes**:
- `Kado/Views/HabitDetail/CompletionHistoryList.swift` — in `row(for:)`,
  add a note line below the date VStack when `completion.note` is
  non-nil and non-empty. Truncate to 2 lines with `.lineLimit(2)`.
  Use `.font(.caption)` and `.foregroundStyle(.secondary)`.
- Update previews with seed data that includes notes.

**Tests / verification**:
- Preview: row with note, row without note
- Preview: long note truncated to 2 lines
- Manual: history list shows notes after adding them via popover

**Commit message**: `feat(habit-notes): show notes in CompletionHistoryList`

---

### Task 5: Calendar note indicator dot

**Goal**: Show a small dot below the day number on calendar cells
that have a note.

**Changes**:
- `Kado/UIComponents/MonthlyCalendarView.swift` — in `cell(for:)`,
  add a small circle (4pt) below the day number inside the `ZStack`
  when the day's completion has a non-empty note. Use
  `Color.secondary` for the dot to stay subtle. Need to check
  `completions` for a matching note.

**Tests / verification**:
- Preview: calendar with some days having notes, verify dots appear
- Manual: add note via popover, verify dot appears on the day

**Commit message**: `feat(habit-notes): add note indicator dot to calendar`

---

### Task 6: Localization (EN + FR)

**Goal**: Add all new user-facing strings to the string catalog with
FR translations.

**Changes**:
- `Localizable.xcstrings` — add keys: "Add a note..." (placeholder),
  "Note" (accessibility / history label), any other new strings.
  FR translations: "Ajouter une note...", "Note".

**Tests / verification**:
- `LocalizationCoverageTests` passes (no missing FR keys)
- Preview in FR locale: placeholder and labels render correctly

**Commit message**: `feat(habit-notes): add EN + FR localization`

---

### Task 7: Accessibility pass

**Goal**: Ensure note input and display work with VoiceOver and
Dynamic Type.

**Changes**:
- `DayEditPopover` — `accessibilityLabel` on the note field
- `CompletionHistoryList` — `accessibilityLabel` including note
  content when present
- `MonthlyCalendarView` — update day cell accessibility label to
  mention "has note" when applicable

**Tests / verification**:
- VoiceOver reads note field and content correctly
- Dynamic Type XXXL: popover doesn't overflow, note text wraps

**Commit message**: `feat(habit-notes): accessibility for notes`

## Risks and mitigation

- **Popover overflow on small screens**: the note text field adds
  height. Mitigation: use a compact single-line `TextField` that
  expands to multi-line only when focused, and test on iPhone SE.
- **Binary/negative dismissal change**: keeping the popover open
  after toggle changes the interaction pattern. Mitigation: only
  prevent auto-dismiss if the note field is actively focused;
  otherwise preserve the quick-tap-to-toggle flow.
- **Zero-value completions**: standalone notes create a `value: 0`
  record. This could affect score/streak calculations if they
  count any existing record as "done." Mitigation: verify that
  `HabitScoreCalculator` and `StreakCalculator` treat `value <= 0`
  as "not done" (or add a guard if they don't).

## Open questions

- (All resolved during planning — none remaining.)

## Notes during build

- **Task 1**: Discovered that `DailyValue.compute` and
  `DefaultStreakCalculator` are presence-based — any existing
  `CompletionRecord` counts as "done" regardless of value. Zero-value
  standalone notes would incorrectly inflate scores and streaks.
  Fixed by filtering `value > 0` in both calculators. Also updated
  `CompletionToggler` to upgrade note-only records on toggle-on and
  preserve them on toggle-off, and `CompletionLogger` to preserve
  notes across timer session replace and counter decrement-to-zero.
  This was more involved than planned but was safety-critical.
- **Tasks 2+3**: Combined into a single commit since the popover
  changes require the wiring in HabitDetailView to compile.

## Out of scope

- Rich text, photos, or mood tags on notes (ROADMAP post-v1.0)
- Notes in widget snapshots
- Note search or filtering
- Note editing from the history list (edit via calendar popover only)
