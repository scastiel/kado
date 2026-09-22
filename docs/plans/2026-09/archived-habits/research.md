# Research — Archived habits: view, restore, delete

**Date**: 2026-09-21
**Status**: ready for plan
**Related**: [issue #99](https://github.com/scastiel/kado/issues/99),
[issue #63](https://github.com/scastiel/kado/issues/63) (address habits
by id), [issue #87](https://github.com/scastiel/kado/issues/87)
(`.swipeActions` outside a `List`)

## Problem

A user wrote in (2026-09-13) to say that **Archive** looks like a
badly-named **Delete**. They're right about everything they can see:
archiving stamps `archivedAt`, the habit leaves Today and Overview, and
nothing in the app shows it again. There is no Unarchive and no Delete,
so the archive is a one-way door into a room with no window.

What the user needs:

- to **see** their archived habits and open one to read its history;
- to **bring one back** when the archive was a mistake or a pause;
- to **delete** one for good — a habit created by mistake should not
  have to live in the archive forever;
- a confirmation that tells them where the habit is going.

"Done" from the user's chair: Archive is honestly reversible, the
archived habits have an address, and Delete exists and says what it
does.

## Current state of the codebase

**Archive exists twice, inline.** `TodayView.archive(_:)` and
`HabitDetailView.archive()` both do `record.archivedAt = loggingInstant;
try? modelContext.save(); WidgetReloader.reloadAll(using:)`. Neither is
unit-tested. The confirmation copy is duplicated too ("Archived habits
stop appearing on Today but keep their history.").

**Archived habits are already readable, just unreachable.**
`HabitDetailLoader`'s `@Query` is deliberately unfiltered so an archived
habit resolves, and `HabitDetailView` renders it read-only — `Edit` and
`Archive` disabled, quick-log disabled, calendar not selectable, an
"Archived" badge in the header. Only the route into it is missing.

**Every list filters them out.** `TodayView` and `OverviewView`
`@Query` with `#Predicate { $0.archivedAt == nil }`; `HabitSortOrder`,
`OverviewMatrix`, `WidgetSnapshotBuilder`, the notification scheduler,
and both App Intents all skip archived records. Clearing `archivedAt`
is therefore enough to bring a habit back everywhere.

**Delete needs no schema work.** `HabitRecord.completions` is declared
`@Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)`
in every schema version, so `modelContext.delete(record)` takes the
history with it, and CloudKit mirrors a cascade as individual record
deletions. `CloudKitShapeTests` already walks the schema's
relationships.

**Reminders follow widgets.** `WidgetReloader.reloadAll(using:)`
rebuilds the widget snapshot *and* calls `RemindersSync.rescheduleAll`,
which re-fetches every habit and hands the scheduler the ones with
`archivedAt == nil`. Any mutation that calls `reloadAll` afterwards
gets reminder re-scheduling for free — so unarchive and delete just
need to call it, the same as archive does today.

**Patterns to follow.**

- Views address habits by `UUID` and snapshot to value types
  (`TodayRow` / `HabitRoute` / `HabitDetailLoader`, issue #63). The
  Archived list must too, or a dev-mode container swap traps it.
- Mutation logic goes in a free struct, not a ViewModel
  (`CompletionToggler` in `KadoCore/Services`).
- `.swipeActions` only fires on `List` rows (issue #87); the Archived
  list *is* a `List`, so swipe is available, but the gesture still gets
  driven once in `KadoUITests`.
- Accessibility identifiers land on leaves, in the same commit as the
  view (`Shared/AccessibilityID.swift`).
- New EN keys need FR entries in `Kado/Resources/Localizable.xcstrings`
  in the same commit (`LocalizationCoverageTests`). Existing FR:
  "Archive" → "Archiver", "Archived" → "Archivée", "Settings" →
  "Réglages", "Today" → "Aujourd'hui", "Delete" → "Supprimer".

**Seed.** `DevModeSeed` has no archived habit, and
`PreviewContainerTests` pins the seed at 7 habits. Previews of the new
list need a container of their own.

## Proposed approach

Settings gains a **Habits › Archived** row that pushes an
`ArchivedHabitsView` — a `List` of archived habits, newest archive
first, each opening the existing read-only detail through
`HabitDetailLoader`. Each row offers **Unarchive** and **Delete**
(swipe, long-press menu, VoiceOver action). The archived detail's
toolbar swaps its disabled Edit/Archive for **Unarchive** (primary) and
**Delete** (secondary). Delete always confirms. Archive's confirmation
tells the user where to find the habit afterwards.

Delete is offered **only on archived habits**. Today's long-press menu
and the active detail keep Archive as their one destructive action,
and it is the recoverable one. Deleting is two steps by design.

### Key components

- `HabitLifecycle` (`KadoCore/Services`): `archive(_:at:)`,
  `unarchive(_:)`, `delete(_:in:)`. One home for the three writes,
  unit-tested; the views call it and then `WidgetReloader.reloadAll`.
- `ArchivedHabitRow` (value type): `Habit` snapshot + completion count,
  `Identifiable` by habit id. Built from a record at the `@Query`
  boundary, the way `TodayRow` is.
- `ArchivedHabitsView` (`Views/Settings/`): the list. `@Query(filter:
  #Predicate<HabitRecord> { $0.archivedAt != nil })`, Swift-side sort by
  `archivedAt` descending. Empty state via `ContentUnavailableView`.
  Delete confirmation keyed on a `UUID?`, like Today's archive.
- `ArchivedSection` (`Views/Settings/`): the Settings row, with a
  `.badge(count)` so the number of archived habits is visible without
  pushing.
- `HabitDetailView`: archived toolbar (Unarchive / Delete + confirm);
  archive confirmation copy updated.
- `TodayView`: archive confirmation copy updated; archive goes through
  `HabitLifecycle`.
- `AccessibilityID`: `Settings.archivedRow`, `Archived.row(id)`,
  `Archived.unarchiveButton` / `.deleteButton` / `.deleteConfirmButton`,
  `HabitDetail.unarchiveButton` / `.deleteButton` /
  `.deleteConfirmButton`, `Today.archiveButton` / `.archiveConfirmButton`.

### Data model changes

None. `archivedAt` is already optional; the cascade rule is already
there.

### UI changes

- Settings: new **Habits** section between Notifications and Data,
  one row "Archived" with a count badge.
- New screen **Archived**: list rows with icon, name, "Archived on
  <date>", completion count; leading swipe Unarchive, trailing swipe
  Delete (no full-swipe, since it confirms); long-press menu and
  VoiceOver actions carrying the same two.
- Habit detail (archived): toolbar Unarchive + Delete.
- Archive confirmation (Today and detail): "Archived habits leave Today
  but keep their history. You can find them in Settings › Archived."

### Tests to write

```swift
@Suite("HabitLifecycle")
@Test("archive stamps archivedAt with the given instant")
@Test("unarchive clears archivedAt")
@Test("delete removes the habit and cascades its completions")
@Test("delete leaves the other habits' completions alone")
```

UI (`KadoUITests/ArchivedHabitsTests.swift`):

- archive a Today row from its long-press menu → Settings › Archived
  lists it → Unarchive from its long-press menu → it leaves the list
  and is back on Today.
- archive → Settings › Archived → Delete → confirm → it leaves the
  list and Today has one row fewer.

## Alternatives considered

### Alternative A: Archived as an Overview filter

- Idea: a segmented control on Overview toggling active / archived.
- Why not: Overview is a matrix of the last N days; archived habits
  have no cells to show there. The issue's own suggested copy names
  "Settings › Archived". Settings is where Data / Export already live.

### Alternative B: Delete beside Archive in Today's menu

- Idea: offer Delete directly in the long-press menu and the active
  detail toolbar.
- Why not: two destructive items next to each other on the primary
  surface, one recoverable and one not, is how a habit gets deleted by
  mistake. Archive-then-delete keeps the everyday surface to a single,
  reversible destructive action. Deferred, not rejected — revisit if
  users ask.

### Alternative C: Add an archived habit to `DevModeSeed`

- Idea: seed one so previews, dev mode and UI tests have data.
- Why not: `PreviewContainerTests` pins the seed at 7 and a few UI
  tests walk Today's rows; every consumer would need a look. A
  preview-only container and a UI test that archives through the UI
  cover the same ground with no blast radius.

## Risks and unknowns

- `@Query(sort:)` with an optional `Date?` key path — avoided by
  sorting Swift-side after the fetch, which the id-and-snapshot
  pattern needs anyway.
- `ToolbarContentBuilder` `if`/`else` — supported since iOS 16; the
  target is iOS 18.
- The unarchived habit's `sortOrder` is whatever it was; it may land
  mid-list on Today. Acceptable: the user can drag it.
- `dismiss()` after unarchive / delete from the detail: the pushed
  detail sits on Settings' stack; popping back to the Archived list
  is the right landing either way.

## Open questions

- [x] Delete placement → archived-only (issue leans this way; see
  Alternative B).
- [x] Archived list location → Settings (issue's own copy names it;
  see Alternative A).

## References

- `docs/plans/2026-04/today-row-actions/` — how Archive got its
  context-menu home.
- `Kado/Views/HabitDetail/CompletionHistoryList.swift` — long-press
  menu + `accessibilityAction` + footer hint, the outside-a-`List` case.
- `KadoUITests/CompletionHistoryTests.swift` — driving a long-press
  menu item end to end.
