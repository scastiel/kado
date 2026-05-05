# Research — Habit reordering

**Date**: 2026-05-04
**Status**: ready for plan
**Related**: [Issue #48](https://github.com/scastiel/kado/issues/48), `docs/ROADMAP.md`

## Problem

Users expect to control the display order of their habits in the Today
view. The only current sort is `createdAt` ascending — the user cannot
move a newly created habit above an older one, or group related habits
together. Long-press already triggers a context menu, so drag-to-reorder
feels like the natural missing interaction.

## Current state of the codebase

- **Today view** (`Kado/Views/Today/TodayView.swift`): uses
  `@Query(sort: \HabitRecord.createdAt)` to fetch active habits. The
  list splits into "Scheduled" and "Not scheduled today" sections via
  Swift-side filtering. No `EditMode`, no `.onMove`, no drag support.
- **HabitRecord** (`KadoSchemaV3`): no sort-order field. Current
  properties: `id`, `name`, `frequencyData`, `typeData`, `createdAt`,
  `archivedAt`, `colorRaw`, `icon`, reminder fields, `completions`.
- **Domain Habit struct** (`Packages/KadoCore/.../Habit.swift`): no
  sort-order field.
- **WidgetSnapshotBuilder**: fetches with `sortBy: [SortDescriptor(\.createdAt)]`
  — would need updating to respect the new order.
- **Context menu**: lives in `HabitRowView` via `.contextMenu { }`.
  Does not conflict with drag handles — SwiftUI's `List` supports both
  simultaneously.
- **Schema**: currently V3, migration plan uses lightweight stages only.

## Proposed approach

Add a persisted `sortOrder: Int` field to `HabitRecord` (V4 schema) and
use SwiftUI's built-in `ForEach` + `.onMove` to enable drag-to-reorder.

### Key components

- **KadoSchemaV4**: new schema version with `sortOrder: Int = 0` on
  `HabitRecord`. Lightweight migration (new field has a default).
- **Migration backfill**: a `.custom` migration stage that assigns
  sequential `sortOrder` values based on existing `createdAt` order,
  so existing users keep their current order.
- **Habit domain struct**: add `sortOrder: Int` field.
- **TodayView**: change `@Query` sort to `\.sortOrder`, add `.onMove`
  modifier on `ForEach` within each section.
- **WidgetSnapshotBuilder**: update `FetchDescriptor` to sort by
  `\.sortOrder`.
- **New habit creation**: assign `sortOrder = max(existing) + 1` so new
  habits appear at the bottom by default.

### Data model changes

```swift
// KadoSchemaV4.HabitRecord (additions)
public var sortOrder: Int = 0
```

Lightweight migration won't assign sequential values (all existing
habits get `sortOrder = 0`), so we use a `.custom` stage to:
1. Fetch all habits sorted by `createdAt`.
2. Assign `sortOrder = index` to each.

### UI changes

- **TodayView**: add `@Environment(\.editMode)` support. Use an Edit
  button in the toolbar (or long-press-drag without edit mode if
  possible). Add `.onMove` to `ForEach` in both sections.
- **Reorder logic**: when the user moves a habit, renumber `sortOrder`
  values for affected items and save. Keep ordering per-section — the
  user reorders within "Scheduled" and within "Not scheduled"
  independently, both backed by the single `sortOrder` field.
- **Context menu**: unchanged — `.contextMenu` and `.onMove` coexist
  in SwiftUI Lists.

### Tests to write

```swift
@Test("New habit gets sortOrder = max + 1")
func newHabitSortOrder() { ... }

@Test("Moving habit from index 2 to 0 renumbers correctly")
func moveHabitUp() { ... }

@Test("Custom migration assigns sequential sortOrder from createdAt")
func v3ToV4Migration() { ... }

@Test("CloudKit shape: sortOrder is non-unique, has default")
func cloudKitShape() { ... }
```

## Alternatives considered

### Alternative A: Sort by `createdAt`, allow editing `createdAt`

- Idea: Reuse the existing sort field. Let the user "fake" a creation
  date to reorder.
- Why not: Destroys meaningful data (actual creation date), confusing
  UX, breaks streaks that depend on `createdAt`.

### Alternative B: Fractional ordering (e.g. `sortOrder: Double`)

- Idea: Insert between two items by averaging their sort values. No
  renumbering needed.
- Why not: Precision degrades over time with many reorders. Simpler to
  just renumber integers — the list is small (tens, not thousands).

### Alternative C: Linked-list ordering (prev/next pointers)

- Idea: Each habit points to the next.
- Why not: Overkill for a flat list. Harder to query, harder to sync
  with CloudKit, impossible to use as a SwiftData sort descriptor.

## Risks and unknowns

- **`.onMove` within sectioned Lists**: SwiftUI supports this, but the
  move indices are section-relative. Need to map back to the global
  `sortOrder` correctly.
- **Cross-section moves**: should the user be able to drag a habit from
  "Not scheduled" to "Scheduled"? Probably not — section membership is
  frequency-driven, not user-controlled. `.onMove` is per-`ForEach`, so
  this is naturally prevented.
- **CloudKit sync conflicts**: two devices reordering simultaneously
  could conflict. CloudKit last-writer-wins on `sortOrder` is
  acceptable — worst case the order on one device "resets" to the
  other's, which the user can fix.
- **Custom migration**: first non-lightweight migration in the project.
  Need to verify the custom stage runs correctly with the CloudKit
  container configuration.

## Open questions

- [ ] Should drag-to-reorder require entering an explicit Edit Mode
      (toolbar Edit button), or should it work via long-press-drag
      directly (like Apple Reminders)?
- [ ] Should the sort order be global (one flat ordering for all
      habits) or per-section (separate order for "due today" vs
      "not due")? A global order is simpler and means the habit
      keeps its relative position regardless of which day it is.

## References

- [SwiftUI List onMove](https://developer.apple.com/documentation/swiftui/foreach/onmove(perform:))
- [SwiftData VersionedSchema](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Issue #48](https://github.com/scastiel/kado/issues/48)
