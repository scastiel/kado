# Plan — Archived habits: view, restore, delete

**Date**: 2026-09-21
**Status**: in progress
**Research**: [research.md](./research.md)

## Summary

Archiving a habit currently makes it vanish for good: no screen lists
archived habits, nothing restores one, and there is no Delete. This
adds a **Settings › Archived** list that opens the existing read-only
detail, an **Unarchive** on both the list and the detail, and a
confirmed **Delete** on archived habits only. The archive confirmation
now says where the habit goes. No schema change: `archivedAt` is
already optional and the completions relationship already cascades.

## Decisions locked in

- Delete is offered only on archived habits (archive first, then
  delete). Today's menu and the active detail keep Archive as their
  one, recoverable, destructive action.
- The Archived list lives in Settings, in a new **Habits** section
  between Notifications and Data, with a count badge on the row.
- The three writes (archive / unarchive / delete) live in one free
  struct, `HabitLifecycle`, in `KadoCore`, unit-tested; views call it
  then `WidgetReloader.reloadAll`, which also re-syncs reminders.
- Unarchive and Delete from the detail pop the screen, the way Archive
  already does.
- `DevModeSeed` stays at 7 habits; the new list gets a preview
  container of its own, and the UI test archives through the UI.

## Task list

### Task 1: `HabitLifecycle` — tests, then the struct

**Goal**: one tested home for archive / unarchive / delete.

**Changes**:
- `KadoTests/HabitLifecycleTests.swift` (first)
- `Packages/KadoCore/Sources/KadoCore/Services/HabitLifecycle.swift`

**Tests / verification**:
- archive stamps the given instant; unarchive clears it; delete
  removes the habit and cascades its completions, leaving other
  habits' completions alone. In-memory container on `KadoSchemaV4`.
- `test_sim` red → green.

**Commit message (suggested)**: `feat(core): add HabitLifecycle for archive, unarchive and delete`

---

### Task 2: Route the existing archive through it, reword the confirmation

**Goal**: Today and the detail call `HabitLifecycle.archive`; both
confirmations say where archived habits go.

**Changes**:
- `Kado/Views/Today/TodayView.swift` — `archive(_:)`, dialog message,
  identifiers on the menu item and the confirm button.
- `Kado/UIComponents/HabitRowView.swift` — identifier on the Archive
  menu item.
- `Kado/Views/HabitDetail/HabitDetailView.swift` — `archive()`, dialog
  message.
- `Shared/AccessibilityID.swift` — `Today.archiveButton`,
  `Today.archiveConfirmButton`.
- `Kado/Resources/Localizable.xcstrings` — replace the message key (EN
  + FR), drop the old one.

**Tests / verification**: `build_sim`; `LocalizationCoverageTests`.

**Commit message (suggested)**: `feat(archive): say where archived habits go and route archive through HabitLifecycle`

---

### Task 3: `ArchivedHabitsView` + `ArchivedSection`

**Goal**: the list, reachable from Settings.

**Changes**:
- `Kado/Views/Settings/ArchivedHabitRow.swift` — value-type row.
- `Kado/Views/Settings/ArchivedHabitsView.swift` — `List`, empty
  state, `navigationDestination(for: HabitRoute.self)`, swipe +
  context menu + accessibility actions, delete confirmation keyed on
  `UUID?`, previews (populated, empty, dark).
- `Kado/Views/Settings/ArchivedSection.swift` — row with `.badge`.
- `Kado/Views/Settings/SettingsView.swift` — insert the section.
- `Kado/Preview Content/PreviewContainer.swift` —
  `withArchivedHabits()`.
- `Shared/AccessibilityID.swift` — `Settings.archivedRow`, `Archived.*`.
- `Kado/Resources/Localizable.xcstrings` — new keys, EN + FR.

**Tests / verification**: `build_sim`, previews, `screenshot` of the
list; `LocalizationCoverageTests`.

**Commit message (suggested)**: `feat(settings): list archived habits with unarchive and delete`

---

### Task 4: Archived detail toolbar — Unarchive / Delete

**Goal**: the pushed read-only detail can restore or delete the habit.

**Changes**:
- `Kado/Views/HabitDetail/HabitDetailView.swift` — conditional toolbar,
  `unarchive()`, `delete()`, delete confirmation, identifiers.
- `Shared/AccessibilityID.swift` — `HabitDetail.unarchiveButton`,
  `.deleteButton`, `.deleteConfirmButton`.
- `Kado/Resources/Localizable.xcstrings` — keys shared with Task 3
  where the copy is the same.

**Tests / verification**: `build_sim`, "Archived" preview.

**Commit message (suggested)**: `feat(habit-detail): unarchive or delete an archived habit from its toolbar`

---

### Task 5: UI tests

**Goal**: drive the new gestures once, per the CLAUDE.md rule.

**Changes**:
- `KadoUITests/ArchivedHabitsTests.swift` — archive → list → unarchive
  → back on Today; archive → list → delete → confirm → gone.

**Tests / verification**: `make e2e` (iPhone), green.

**Commit message (suggested)**: `test(ui): archive, unarchive and delete a habit end to end`

---

### Task 6: Docs

**Goal**: `docs/PRODUCT.md` / `ROADMAP.md` mention the archive if they
describe it; plan boxes ticked; `compound.md`.

**Commit message (suggested)**: `docs(archived-habits): compound`

## Risks and mitigation

- **`@Query` on `archivedAt != nil` in the main app**: same shape as
  Today's `== nil`, which is fine outside extensions. If it traps,
  fall back to an unfiltered query + Swift-side filter.
- **Toolbar `if` in `ToolbarContentBuilder`**: supported on the target
  OS. If the compiler balks, split into two `ToolbarItemGroup`s with
  `.opacity`/`.disabled` — but prefer the conditional.
- **Swipe + context menu on the same `List` row**: both are used on
  Today's rows already (Undo swipe, long-press menu).
- **CloudKit and cascade delete**: the relationship's inverse is
  explicit, so the mirror deletes completions as their own records. To
  verify on a real two-device pair before release; noted in Next steps.

## Open questions

None carried forward.

## Out of scope

- Delete on active habits (beside Archive). Deferred, see research
  Alternative B.
- Bulk actions on the Archived list.
- Restoring `sortOrder` to a "sensible" position on unarchive; the
  habit keeps its old index and the user can drag it.
- Seeding an archived habit into `DevModeSeed`.

## Notes during build

_(filled in as tasks complete)_
