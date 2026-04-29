# Research — Habit Notes

**Date**: 2026-04-29
**Status**: ready for plan
**Related**: [Issue #41](https://github.com/scastiel/kado/issues/41), ROADMAP post-v1.0

## Problem

Users want to attach free-text notes to a habit on a specific day.
Use cases from the issue: logging medication dosage changes, recording
workout details (distance, weight, reps), journaling mood or context.

The data model already supports this — `CompletionRecord.note: String?`
has shipped since v0.1 — but no UI lets users write or read notes.

## Current state of the codebase

### Already in place (no changes needed)

- **`CompletionRecord.note: String?`** — present in V1, V2, V3 schemas
  (`Packages/KadoCore/.../CompletionRecord.swift:15`). No migration.
- **`Completion.note: String?`** — domain struct mirrors the field
  (`Packages/KadoCore/.../Completion.swift:16`).
- **`CompletionBackup.note: String?`** — export/import already
  round-trips notes (`Packages/KadoCore/.../CompletionBackup.swift:9`).
- **`CompletionRecord.snapshot`** — maps `note` through to `Completion`.
- **CloudKit** — `String?` is a supported optional attribute; no shape
  issues.

### Missing (needs building)

- **`DayEditPopover`** (`Kado/Views/HabitDetail/DayEditPopover.swift`)
  — has no note input field. Currently shows type-specific controls
  (toggle, stepper, clear) and dismisses immediately on binary/negative
  toggle.
- **`CompletionHistoryList`** (`Kado/Views/HabitDetail/CompletionHistoryList.swift`)
  — rows show date + value only; no note display.
- **`CompletionLogger`** (`Kado/Services/CompletionLogger.swift`) —
  none of the mutation methods accept or write a `note` parameter.
- **`CompletionToggler`** (`Packages/KadoCore/.../CompletionToggler.swift`)
  — `toggleToday` creates records with `note: nil`; no note passthrough.
- **`HabitDetailView`** (`Kado/Views/HabitDetail/HabitDetailView.swift`)
  — popover callbacks don't carry notes; `currentValue(on:)` reads value
  only.

## Proposed approach

Add note editing inline in `DayEditPopover` and note display in
`CompletionHistoryList`. Keep the note optional and unobtrusive — a
collapsed "Add note" affordance that expands to a text field.

### Key components

- **`DayEditPopover`**: add a `TextField` / `TextEditor` below the
  type-specific control. Collapsed by default ("Add note..." tap
  target); expands when tapped or when an existing note is present.
  Requires a new `onSetNote: (String?) -> Void` callback plus a
  `currentNote: String?` input, or a single combined
  `onNoteChanged: (String?) -> Void`. The popover already stays open
  for counter/timer (stepper interaction), so note editing fits
  naturally. For binary/negative, the popover currently dismisses on
  tap — we'll need to keep it open if the user wants to add a note,
  so the toggle action should not auto-dismiss when a note field is
  active.
- **`CompletionHistoryList`**: show the note as a secondary line
  below the date, truncated to 2 lines with a disclosure to expand.
  No editing from the history list — tap the calendar day to edit.
- **`CompletionLogger`**: add a `setNote(for:on:to:in:)` method that
  updates `completion.note` on an existing record. If no record exists
  for the day (user wants to add a note without marking complete),
  decide: either require a completion first, or create a zero-value
  completion. Recommendation: require a completion first — a note
  without a completion is a confusing state.
- **`HabitDetailView`**: wire `currentNote(on:)` and `setNote(_:on:)`
  through to the popover, mirroring the existing value callbacks.

### Data model changes

None. `CompletionRecord.note: String?` already exists.

### UI changes

1. `DayEditPopover` — note input field (collapsed/expanded).
2. `CompletionHistoryList` — note display below date.
3. Previews for both (with and without notes, dark mode).

### Tests to write

- `CompletionLogger` note mutation: set, update, clear note on
  existing completion.
- `CompletionLogger` note on new completion: setting a counter value
  with a note preserves both.
- Round-trip: backup export with notes, import, verify notes survive
  (likely already passing given `CompletionBackup` wires it).

## Alternatives considered

### Alternative A: Separate NoteRecord model

- Idea: a standalone `@Model` class keyed by habit + date, independent
  of completions.
- Why not: adds a schema migration, a new relationship, and raises
  the question of notes on days without completions. The existing
  `note` field on `CompletionRecord` is simpler and already shipped.

### Alternative B: Full-screen note editor (sheet)

- Idea: tapping "Add note" opens a `.sheet` with a large `TextEditor`.
- Why not: heavyweight for what's typically a one-line annotation.
  A multi-line `TextField` in the popover is sufficient for MVP.
  Can revisit if users request rich text or photos (post-v1.0 ROADMAP
  item "Enriched completion notes").

### Alternative C: Notes on the habit itself (not per-day)

- Idea: a single note field on `HabitRecord`.
- Why not: doesn't address the use case. The user wants to log
  context per day ("reduced dosage today", "ran 5km"), not describe
  the habit generically.

## Risks and unknowns

- **Popover sizing**: adding a text field may cause the popover to
  overflow on smaller devices. Need to test on iPhone SE / compact
  width.
- **Binary/negative dismissal**: currently auto-dismisses on toggle.
  Adding a note requires keeping the popover open. This changes the
  interaction pattern for the simplest habit types — may feel heavier.
  Mitigation: only show the note field after the toggle, or use a
  two-tap flow (toggle + optional note).
- **Character limit**: no technical limit on `String?` in SwiftData,
  but CloudKit has a 1MB record limit. A reasonable UI cap
  (e.g., 500 chars) avoids abuse and keeps the history list readable.

## Open questions

- [ ] Should notes be available on days without a completion (e.g.,
      "skipped because I was sick")? This would require creating a
      zero-value `CompletionRecord` to hold the note, which breaks the
      current "no record = not done" semantics.
- [ ] Character limit: 280 (tweet-length), 500, or unlimited?
- [ ] Should the calendar grid show a visual indicator (small dot or
      icon) on days that have notes?

## References

- [Issue #41](https://github.com/scastiel/kado/issues/41) — original
  feature request
- ROADMAP post-v1.0: "Enriched completion notes (photos, mood)"
- `docs/plans/2026-04/detail-quick-log/research.md` — confirms note
  field exists but is deferred
