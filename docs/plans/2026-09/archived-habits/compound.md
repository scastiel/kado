# Compound — Archived habits: view, restore, delete

**Date**: 2026-09-21
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: `feature/archived-habits`, issue #99

## Summary

Archive was a one-way door: the habit left every list and nothing
offered it back, so a user reasonably read it as a badly-named
Delete. The archive now has an address — Settings › Archived habits —
with Unarchive and a confirmed Delete on each row and on the archived
detail's toolbar, and the archive confirmation says where the habit
goes. The build matched the plan; nothing needed a schema change,
because the cascade rule and the optional `archivedAt` were already
in place from day one.

## Decisions made

- **Delete only on archived habits.** Today's menu and the active
  detail keep one destructive action, and it is the recoverable one.
  Two destructive items side by side — one reversible, one not — is
  how a habit gets deleted by mistake.
- **Settings, not an Overview filter.** Archived habits have no cells
  to show in a matrix of recent days; Settings is where Data / Export
  already live, and the issue's own copy named it.
- **The row is always present, with a count badge.** The user who
  wrote in couldn't tell whether an archive *existed*; a row that
  appears only once something is in it wouldn't have told them either.
- **`HabitLifecycle` in `KadoCore`.** The three writes were one line
  each and already duplicated across two views; the `CompletionToggler`
  shape gives them one home and a behavioural test that Delete takes
  the history with it.
- **Unarchive and Delete pop the detail**, as Archive already did: the
  screen was pushed from the list the habit has just left.
- **"Archived habits", not "Archived".** The catalog already carries
  `"Archived"` as the singular badge (`Archivée`), and one EN string
  can only have one FR rendering — so the row, the title, and the
  confirmation all say "Archived habits" (`Habitudes archivées`).
- **FR "Unarchive" → "Désarchiver".** Mirrors "Archiver" exactly;
  "Restaurer" was the alternative. For the native speaker to confirm.

## Surprises and how we handled them

### The disk was full mid-build

- **What happened**: `build_sim` failed with `database or disk is
  full` on the build database; the Data volume had ~1 GB free with
  parallel worktree jobs building at once.
- **What we did**: waited for the other run to release space and
  retried; nothing outside the worktree was deleted. Ran the UI tests
  serially (`-parallel-testing-enabled NO`) rather than with the
  Makefile's three clones, to stay off the disk.
- **Lesson**: parallel worktree jobs each carry a ~400 MB `build/`
  plus a simulator; `make e2e`'s clones triple the simulator side.
  Check `df` before a UI run when several jobs are up.

### `.destructive` on a swipe action that only opens a dialog

- **What happened**: a `Button(role: .destructive)` in `.swipeActions`
  makes the system animate the row away on the tap. When the action
  only presents a confirmation, the row springs back on Cancel.
- **What we did**: the Delete swipe has no role and a `.tint(.red)`
  instead; the long-press menu's Delete keeps `role: .destructive`,
  where the role has no such side effect.
- **Lesson**: in `swipeActions`, reserve the destructive role for a
  button that removes the row itself. Today's Undo swipe qualifies;
  a confirm-first Delete does not.

## What worked well

- Reading `WidgetReloader.reloadAll` before designing anything: it
  already re-syncs reminders, so unarchive and delete needed no
  notification code at all — the plan's "reminders need rescheduling"
  item collapsed to "call the postamble every mutation calls".
- The id-and-snapshot pattern (#63) transferred to the new list
  without thought: `ArchivedHabitRow` is `TodayRow` with a different
  payload, and the delete dialog holds a `UUID?` like Today's archive.
- Hand-authoring catalog entries through a load → edit → dump script
  that round-trips Xcode's serialization byte-for-byte, so the
  catalog diff is only the keys that changed.

## For the next person

- `ArchivedHabitsView` declares `.navigationDestination(for:
  HabitRoute.self)` itself: Settings' `NavigationStack` has no path
  binding and no route table, so the pushed screen registers the
  route it needs. Today declares the same destination on its own stack.
- A habit unarchived keeps its old `sortOrder`, so it lands wherever
  it used to sit on Today, not at the end. Deliberate; the user can
  drag it.
- `"Habits"` in the catalog is now shared by the import summary and
  the Settings section header. Both are "Habitudes"; if one ever
  needs a different rendering, one of them needs a different EN key.
- The detail's Delete lives in the `.secondaryAction` overflow, like
  Archive before it. The UI suite drives the list's Delete (same
  dialog, same `HabitLifecycle.delete`) and the detail's Unarchive;
  the detail's Delete was checked by hand in the "Archived" preview.

## Generalizable lessons

- **[→ CLAUDE.md]** `Button(role: .destructive)` inside `.swipeActions`
  animates the row out on tap; use it only when the action removes
  the row, and `.tint(.red)` without a role when it opens a
  confirmation first.
- **[→ CLAUDE.md]** Before a UI run with several worktree jobs up,
  check `df`: each job's `build/` plus its simulator and `make e2e`'s
  clones can fill a disk mid-build, and the failure surfaces as an
  opaque "database or disk is full" on the build database.
- **[local]** One EN string, one FR rendering: a plural label needs a
  distinct EN key from the singular badge.

## Metrics

- Tasks completed: 6 of 6
- Tests added: 5 unit (`HabitLifecycleTests`), 4 UI
  (`ArchivedHabitsTests`)
- Files touched: 16

## References

- [issue #99](https://github.com/scastiel/kado/issues/99)
- `docs/plans/2026-04/today-row-actions/` — where Archive got its
  context-menu home
- `KadoUITests/CompletionHistoryTests.swift` — the long-press-menu
  driving pattern this suite copies
