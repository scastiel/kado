# Plan — Habit reordering

**Date**: 2026-05-04
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Add a `sortOrder: Int` field to `HabitRecord` (schema V4) and enable
drag-to-reorder in the Today view via long-press-drag (no edit mode).
The sort order is global — a habit's position is stable regardless of
which day it is or which section it falls into. Resolves issue #48.

## Decisions locked in

- Direct long-press-drag interaction (no Edit button / EditMode).
- Global `sortOrder` — one flat ordering across sections.
- Integer renumbering on move (not fractional).
- Custom migration V3→V4 to backfill sequential values from `createdAt`.
- New habits get `sortOrder = max(existing) + 1`.

## Task list

### Task 1: Schema V4 — add `sortOrder` field

**Goal**: Create `KadoSchemaV4` with the new field and wire the
migration plan.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Models/Persistence/KadoSchemaV4.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Models/Persistence/KadoMigrationPlan.swift`
- Move `HabitRecord` / `CompletionRecord` typealiases to V4
- `Packages/KadoCore/Sources/KadoCore/Models/Habit.swift` — add `sortOrder: Int`
- `SharedStore.productionContainer()` and `DevModeController.makeDevContainer()` — bump schema
- Update `HabitRecord.snapshot` to include `sortOrder`

**Tests / verification**:
- `KadoSchemaTests.v4Version` — schema version resolves
- `CloudKitShapeTests` — `sortOrder` has default, no unique constraint
- V3→V4 migration regression test (custom stage assigns sequential values)
- Existing tests still compile and pass

**Commit message (suggested)**: `feat(schema): add sortOrder field to HabitRecord (V4)`

---

### Task 2: Sort order assignment logic

**Goal**: Extract a reusable helper that handles assigning sort order
on creation and renumbering on move.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Services/HabitSortOrderManager.swift` (new) — protocol + default impl with:
  - `nextSortOrder(in context:) -> Int`
  - `move(habit:from:to:in habits:)` — renumbers affected items

**Tests / verification**:
- `KadoTests/HabitSortOrderManagerTests.swift`:
  - `@Test("nextSortOrder returns max + 1")`
  - `@Test("nextSortOrder returns 0 when no habits exist")`
  - `@Test("move from index 2 to 0 renumbers correctly")`
  - `@Test("move from index 0 to 2 renumbers correctly")`
  - `@Test("move to same index is a no-op")`

**Commit message (suggested)**: `feat(sort-order): add HabitSortOrderManager with tests`

---

### Task 3: Wire sort order into Today view

**Goal**: Change the Today view to sort by `sortOrder` and enable
drag-to-reorder.

**Changes**:
- `Kado/Views/Today/TodayView.swift`:
  - Change `@Query` sort to `\.sortOrder`
  - Add `.onMove` to both `ForEach` blocks
  - Implement move handler that calls `HabitSortOrderManager`
- `Kado/Views/Today/TodayView.swift` or environment: inject
  `HabitSortOrderManager` if needed (or use inline since it's simple)

**Tests / verification**:
- Manual: launch in simulator, long-press-drag a habit, confirm it
  moves and persists position after app restart
- `screenshot` before and after a reorder
- Context menu still works (no regression)

**Commit message (suggested)**: `feat(today): enable drag-to-reorder habits`

---

### Task 4: Wire sort order into new habit creation

**Goal**: New habits appear at the bottom of the list.

**Changes**:
- `Kado/Views/NewHabit/NewHabitFormModel.swift` or the save call site —
  assign `sortOrder = nextSortOrder(in: context)` when creating a new
  `HabitRecord`

**Tests / verification**:
- Create a new habit, confirm it appears last
- Existing habits keep their order

**Commit message (suggested)**: `feat(new-habit): assign sortOrder on creation`

---

### Task 5: Update widget snapshot ordering

**Goal**: Widget displays habits in user-defined order.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Widgets/WidgetSnapshotBuilder.swift` —
  change `FetchDescriptor` sort from `\.createdAt` to `\.sortOrder`

**Tests / verification**:
- `WidgetSnapshotBuilderTests` — verify output order matches `sortOrder`
- Widget preview shows correct order

**Commit message (suggested)**: `fix(widget): respect user sort order in snapshot`

---

### Task 6: Update remaining fetch sites

**Goal**: Every place that lists habits respects the new order.

**Changes**:
- `HabitEntity.fetchSuggestions` (App Intents) — sort by `sortOrder`
- Any other `FetchDescriptor` or `@Query` that sorts by `createdAt`
  for display purposes (grep and fix)

**Tests / verification**:
- `CompleteHabitIntentTests` — suggestions appear in sort order
- Full `test_sim` pass

**Commit message (suggested)**: `fix(intents): respect sort order in habit suggestions`

---

## Risks and mitigation

| Risk | Mitigation |
|---|---|
| Custom migration fails with CloudKit container | Test with both `.none` and `.private` configurations. If custom stage can't run with CloudKit, fall back to a "lazy backfill on first launch" in the app delegate. |
| `.onMove` conflicts with `.contextMenu` on same row | SwiftUI handles this natively — context menu fires on short long-press, drag fires on longer hold. Verify in simulator. |
| Two devices reorder simultaneously → conflict | Accept last-writer-wins. Document in compound if it causes UX issues. |

## Open questions

- [ ] Should the Overview tab also respect `sortOrder`? (Likely yes,
      but confirm during build.)

## Out of scope

- Reordering archived habits (they don't appear in Today).
- Section-level reordering (e.g. moving "Not scheduled" above
  "Scheduled").
- Drag between sections (section membership is frequency-driven).
- Animated reorder feedback beyond SwiftUI's default List animation.
