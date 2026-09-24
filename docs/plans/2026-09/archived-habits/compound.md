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

### A value-typed push from a closure-pushed screen doesn't hold

- **What happened**: the Archived rows were
  `NavigationLink(value: HabitRoute(…))`, Today's shape, and tapping
  one left the app on the list. Two attempts, two different failures.
  With the `HabitRoute` destination declared on `ArchivedHabitsView`
  itself, the simulator log said *"A navigationDestination for
  Kado.HabitRoute was declared earlier on the stack. Only the
  destination declared closest to the root view of the stack will be
  used"* and nothing pushed. Declared on `SettingsView` at the root
  instead, the test's screen recording showed the detail push
  *succeed* and, a quarter of a second later, the Archived list slide
  in from the right on top of it — the closure-form link in
  `ArchivedSection` had fired again — leaving the stack on the list.
- **What we did**: made the rows closure-form,
  `NavigationLink { HabitDetailLoader(habitID:) }`, like every other
  push in Settings (the Tip Jar). No destination registration at all.
  The loader still takes an id, so nothing about #63 changes.
- **Lesson**: keep one link style per `NavigationStack`. A value-typed
  push from inside a screen that a closure-form link presented is
  unreliable on this toolchain, and the failure is silent — the row
  looks enabled, the tap fires, and the stack ends where it started.
  The screen recording in the result bundle is what showed the second
  push; a hierarchy dump at failure time only shows where the stack
  ended up.

### XCUITest waits a minute for Today's context menu, twice

- **What happened**: every UI test that archived through Today's
  long-press menu took ~160 s: "App animations complete notification
  not received" after the long-press, and again after the tap on the
  menu item — a 60 s idle timeout each. With four tests that overran
  the Bash tool's 10-minute cap and the run was killed mid-suite.
- **What we did**: one test drives that path end to end; the other
  three launch with `-uiTestArchiveFirstHabit`, which archives the
  first seeded habit right after the seed, and start on the Archived
  list. Same shape as `-uiTestSeedProduction`.
- **Lesson**: a test that opens Today's context menu pays two minutes.
  Drive a menu-reached gesture once; give the other tests their
  starting state through `UITestSupport`.

### The unit suite aborted on a simulator the UI suite had used

- **What happened**: after the UI runs, `test_sim -only-testing:KadoTests`
  on the same simulator reported 300 tests "crashed with signal abrt"
  — one `SIGABRT` in the test host (an Objective-C exception out of a
  SwiftData `performAndWait`), which takes every remaining test with
  it. Suites that had passed an hour earlier, `HabitLifecycleTests`
  included, now aborted alone too. The crashing tests build in-memory
  containers; nothing in the diff touches them.
- **What we did**: `simctl erase` on the worktree's simulator, and
  the full suite passed (664 / 665, the one expected failure). Not
  diagnosed further: the likely suspect is the state the UI runs
  leave in the app's real `UserDefaults` suite (dev mode on, written
  by `UITestSupport.applyLaunchArguments`), which the unit-test host
  then launches into, but that was not confirmed.
- **Lesson**: `make e2e` then `make test` on one simulator is the
  sequence to be suspicious of. If the unit suite aborts wholesale
  after a UI run, erase the simulator before reading the code.

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

- The Archived rows push with a closure-form `NavigationLink`, not
  `HabitRoute`; the comment on `ArchivedHabitsView.row` says why. If
  Settings ever moves to a value-driven stack, move the whole stack
  (the Tip Jar row included) in one go.
- A habit unarchived keeps its old `sortOrder`, so it lands wherever
  it used to sit on Today, not at the end. Deliberate; the user can
  drag it.
- `"Habits"` in the catalog is now shared by the import summary and
  the Settings section header. Both are "Habitudes"; if one ever
  needs a different rendering, one of them needs a different EN key.
- The detail's Delete lives in the `.secondaryAction` overflow, like
  Archive before it. The UI suite drives the list's Delete (same
  dialog, same `HabitLifecycle.delete`) and the detail's Unarchive;
  the detail's Delete is **not** driven by the suite — the overflow
  button has no stable identifier to reach it by — and is on the PR's
  hands-on checklist.

## Generalizable lessons

- **[→ CLAUDE.md]** One link style per `NavigationStack`. A
  `NavigationLink(value:)` inside a screen that a closure-form
  `NavigationLink { … }` presented either finds no usable destination
  ("declared earlier on the stack" in the simulator log) or pushes
  and is immediately covered by the closure link firing again. Push
  with a closure-form link there, or make the whole stack value-driven.
- **[→ CLAUDE.md]** When a UI test says a push didn't happen, export
  the result bundle's screen recording (`xcresulttool export
  attachments`, then `ffmpeg` a filmstrip) before theorising: the
  hierarchy dump shows only where the stack ended up.
- **[→ CLAUDE.md]** A UI test that opens Today's row context menu
  waits 60 s for the app to idle, twice. Drive it in one test; start
  the others from a `UITestSupport` launch argument.
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
- Files touched: 19

## References

- [issue #99](https://github.com/scastiel/kado/issues/99)
- `docs/plans/2026-04/today-row-actions/` — where Archive got its
  context-menu home
- `KadoUITests/CompletionHistoryTests.swift` — the long-press-menu
  driving pattern this suite copies
