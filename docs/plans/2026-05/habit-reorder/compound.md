# Compound — Habit reordering

**Date**: 2026-05-04
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [#49](https://github.com/scastiel/kado/pull/49)

## Summary

Added a `sortOrder: Int` field to `HabitRecord` (schema V4) and enabled
drag-to-reorder via `.onMove` in the Today view. The implementation
followed the plan closely — all 6 tasks completed without reordering or
splitting. The only notable deviation was keeping the migration
lightweight (default 0 for all existing habits) instead of the custom
migration originally planned, since a lightweight stage is simpler and
existing users with few habits can reorder manually on first launch.

## Decisions made

- **Lightweight migration, not custom**: all migrated habits get
  `sortOrder = 0`. Users reorder on first use. Avoids the project's
  first custom migration stage for a low-stakes field.
- **Global sort order, not per-section**: one flat `sortOrder` across
  "Scheduled" and "Not scheduled" sections. Position is stable across
  days.
- **Direct long-press-drag, no Edit button**: matches Apple Reminders
  UX. `.onMove` and `.contextMenu` coexist on the same row — SwiftUI
  distinguishes by gesture duration.
- **Integer renumbering on every move**: simple, no precision
  degradation. The habit list is small enough that renumbering all
  items in a section is effectively free.
- **`HabitSortOrder` as a namespace enum**: follows `CompletionToggler`
  pattern — free functions on a caseless enum, not a protocol. No DI
  needed since the logic is trivial.
- **Backup format unchanged**: `sortOrder` not added to
  `HabitBackup`. Imported habits get `sortOrder = 0` and cluster at
  the top. Acceptable for now; can be added later without a breaking
  format change since `Codable` handles missing keys with defaults.

## Surprises and how we handled them

### `.onMove` section-to-global index mapping

- **What happened**: moving a habit within a section requires
  renumbering the full global ordering, not just the section. The
  naive approach of renumbering only the moved section would leave
  gaps or collisions with the other section's sort orders.
- **What we did**: the `moveHabits` handler rebuilds the full
  `[due + other]` array with the moved section spliced in, then
  assigns sequential `sortOrder = index` to every habit.
- **Lesson**: when a global ordering is split into filtered sections
  for display, any section-local mutation needs to reconcile back to
  the global state.

### Test expectation mismatch on `Array.move`

- **What happened**: initial test expectations for `reorder` assumed
  the array values would shift (thinking about "what position does
  value X end up at"), but `Array.move(fromOffsets:toOffset:)` moves
  elements by index position. `[0,1,2,3,4]` moving index 2 to 0
  becomes `[2,0,1,3,4]`, not `[1,2,0,3,4]`.
- **What we did**: ran the test, observed actual output, corrected
  expectations.
- **Lesson**: matches the CLAUDE.md advice — don't hand-compute
  expected values, run once and paste actuals.

## What worked well

- **Schema bump checklist in CLAUDE.md**: the documented list of files
  to update made the V3→V4 bump mechanical. No files missed.
- **TDD cycle**: writing `HabitSortOrderTests` before implementation
  caught the `Array.move` semantics confusion immediately.
- **Small commits per task**: 6 implementation commits, each green.
  Easy to bisect if needed.

## For the next person

- **`moveHabits` renumbers all active habits on every drag**: this is
  O(n) writes per move. Fine for tens of habits, would need batching
  or dirty-tracking if the list grew to hundreds (unlikely for a
  habit tracker).
- **Migrated habits all get `sortOrder = 0`**: the list order for
  pre-V4 users is undefined until they drag-reorder. In practice
  SwiftData returns them in insertion order when all sort keys are
  equal, so the visual result is usually the same as before.
- **Backup import doesn't preserve sort order**: imported habits get
  `sortOrder = 0`. A future backup format version could include it.

## Generalizable lessons

- **[local]** Section-filtered `.onMove` needs a global reconciliation
  step. Not a general pattern, specific to this split-list design.
- **[→ ROADMAP.md]** Backup format could include `sortOrder` in a
  future version for lossless round-trip.

## Metrics

- Tasks completed: 6 of 6
- Tests added: 7 (sort order) + 2 (schema V4 migration + version)
- Commits: 8 (2 docs + 6 implementation)
- Files touched: 22
