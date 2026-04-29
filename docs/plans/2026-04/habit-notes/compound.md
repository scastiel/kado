# Compound — Habit Notes

**Date**: 2026-04-29
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/habit-notes — PR #43](https://github.com/scastiel/kado/pull/43)

## Summary

Surfaced the unused `CompletionRecord.note: String?` field as a
user-facing feature: per-day free-text notes on habits, editable via
the calendar popover, visible in the history list, with a dot indicator
on annotated calendar days. The biggest unplanned work was discovering
and fixing every presence-based completion check in the codebase —
standalone notes (zero-value records) would have silently inflated
scores, streaks, and visual state across five different code paths.

## Decisions made

- **Notes live on `CompletionRecord.note`, no new model**: the field
  shipped unused since v0.1 across all three schema versions. Zero
  migration cost.
- **Standalone notes create zero-value records**: a `value: 0` record
  with a non-nil note means "no completion, but has annotation." This
  required filtering `value > 0` everywhere completions are
  interpreted as "done."
- **500-character limit enforced in UI only**: no server-side or
  persistence-layer enforcement. CloudKit's 1MB record limit is the
  real ceiling; the UI cap keeps notes concise.
- **Collapsible note section in popover, not a separate sheet**: keeps
  the interaction lightweight. The field auto-expands when a note
  exists.
- **Binary/negative toggle stays open when note is expanded**: without
  this, the auto-dismiss on toggle would make it impossible to add a
  note on the same interaction. When the note section is collapsed, the
  quick-tap-to-toggle flow is preserved.
- **Toggle-off with a note preserves the record as zero-value**: the
  user's note survives un-marking a day. Toggle-on upgrades back to
  value 1. Toggle-off without a note deletes as before.
- **Notes excluded from widget snapshots**: app-only for now, keeps
  the JSON payload minimal.

## Surprises and how we handled them

### Zero-value records break presence-based completion logic

- **What happened**: six code paths treated any existing
  `CompletionRecord` as "completed" regardless of value:
  `DailyValue.compute` (binary/negative), `DefaultStreakCalculator`
  (completedDaySet + completionsInRange), `MonthlyCalendarView`
  (cell state), `HabitRowState.resolve`, and
  `TodayView.isDueTodayOrCompletedToday`. A standalone note would
  color the calendar cell, inflate the streak, raise the score, and
  show the habit as done on the Today tab.
- **What we did**: added `value > 0` guards in all six paths. Added
  regression tests for calculators and toggler. The calendar cell
  bug was caught by the user during manual testing after the initial
  build.
- **Lesson**: any new record type that can exist with `value == 0`
  needs a sweep of every presence-based check. The codebase assumed
  "record exists ↔ done" as an invariant — that invariant is now
  explicitly broken by design.

### Timer session replace was destructive

- **What happened**: `CompletionLogger.logTimerSession` deleted the
  existing record and inserted a new one, losing any attached note.
- **What we did**: changed to update-in-place (`existing.value =
  seconds`) which preserves all other fields including `note`.
- **Lesson**: prefer update-in-place over delete+insert when the
  record carries metadata beyond the primary value.

## What worked well

- **Data model readiness**: `note: String?` was already on
  `CompletionRecord`, `Completion` domain struct, and
  `CompletionBackup`. Zero schema migration, zero export/import work.
- **TDD caught the calculator issues early**: writing tests for
  zero-value records before implementing exposed the presence-based
  assumption in `DailyValue` and `DefaultStreakCalculator` at compile
  time rather than at runtime.
- **Collapsible note UI**: the expand-on-tap / auto-expand-if-exists
  pattern keeps the popover clean for the common case (no note) while
  being discoverable.

## For the next person

- **`value == 0` means "note-only, not done."** Every code path that
  interprets completion presence must filter `value > 0`. If you add
  a new view or calculator that reads completions, check for this.
- **`CompletionToggler` has three-way logic now**: no record → insert
  (value 1); record with value 0 (note-only) → upgrade to value 1;
  record with value > 0 and note → downgrade to value 0 (keep note);
  record with value > 0 and no note → delete.
- **`CompletionLogger.setNote` with nil on a zero-value record deletes
  it**: clearing the last reason for a record to exist removes it
  entirely. This is intentional — no orphaned zero-value records.
- **The note field in `DayEditPopover` commits on "Done" tap or on
  submit, not on every keystroke.** This avoids rapid-fire saves to
  SwiftData.

## Generalizable lessons

- **[→ CLAUDE.md]** When introducing a record that can exist with
  `value == 0` (or any "metadata-only" state), sweep every
  presence-based check in the codebase. The "record exists ↔ done"
  assumption was implicit in six places.
- **[→ CLAUDE.md]** Prefer update-in-place over delete+insert when
  modifying `CompletionRecord` — the record may carry a `note` (or
  future metadata) that a fresh insert would lose.
- **[local]** The `DayEditPopover` `isNoteExpanded` flag controls
  whether binary/negative auto-dismiss fires. This coupling is
  intentional but non-obvious.

## Metrics

- Tasks completed: 7 of 7
- Tests added: 18 (12 logger, 3 toggler, 2 score calculator, 2 streak calculator, minus 1 overlap)
- Commits: 10
- Files touched: 17

## References

- [Issue #41](https://github.com/scastiel/kado/issues/41) — original
  feature request by @097115
- ROADMAP post-v1.0: "Enriched completion notes (photos, mood)" —
  this is the text-only first step
