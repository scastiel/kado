# Research — Import/Export (JSON round-trip)

**Date**: 2026-04-18
**Status**: ready for plan
**Related**: [ROADMAP v0.2 Import/Export](../../../ROADMAP.md#v02--visible-ios-native), [WidgetSnapshot](../../../../Packages/KadoCore/Sources/KadoCore/Widgets/WidgetSnapshot.swift), [SettingsView](../../../../Kado/Views/Settings/SettingsView.swift)

## Problem

v0.2's exit criteria include "an export followed by an import restores
100% of the data (automated test)." Today Kadō has no way to get data
out of the app or back in — CloudKit sync is the only persistence
beyond the device, and "I moved from Loop" or "I want a backup I
control" both fall through the cracks.

We're scoping this feature to the **JSON round-trip** slice: a Kadō
JSON export that a future Kadō install can import with no loss, merged
by habit UUID. CSV export, generic CSV import, and Loop CSV import are
deferred to separate features — they each have their own failure
modes (column mapping, Loop's format reverse-engineering) and shipping
them together would balloon scope past a single PR.

"Done" from the user's perspective: two buttons in Settings, **Export
data** and **Import data**. Export produces a `.json` file via the
share sheet. Import accepts a file picker and merges its contents into
the current store.

## Current state of the codebase

**Persistence (schema V3)** — `KadoSchemaV3.swift:16–149`:
- `HabitRecord` holds `id, name, frequencyData, typeData, createdAt,
  archivedAt, colorRaw, icon, remindersEnabled, reminderHour,
  reminderMinute, completions?`.
- `CompletionRecord` holds `id, date, value, note?, habit?`.
- Every record round-trips through value-type snapshots (`Habit`,
  `Completion`) on read/write.

**Domain types** — `Packages/KadoCore/Sources/KadoCore/Models/`:
- `Habit` (Habit.swift:10) and `Completion` (Completion.swift:11) are
  value-type snapshots. **Neither is `Codable`** — they'd need explicit
  conformance or a DTO wrapper.
- `Frequency` (Frequency.swift:22–53) and `HabitType`
  (HabitType.swift:23–52) are discriminated unions with **custom
  stable Codable** (`kind` discriminator). Already round-trip tested
  (`FrequencyCodingTests`, `HabitTypeCodingTests`).
- `HabitColor` (String raw-value), `Weekday` (Int raw-value) are
  auto-Codable.
- `HabitIcon` is a namespace of SF Symbol name strings — already
  trivially serializable (the `icon: String` field).

**Serialization infra** — `WidgetSnapshotStore`:
- Writes `WidgetSnapshot` Codable to the App Group as ISO8601 JSON via
  `FileManager`. Good template for file writing, but the snapshot
  itself is widget-specific (pre-computed scores, streaks, opacity
  curves) — not reusable as an export format.

**Settings UI** — `Kado/Views/Settings/SettingsView.swift:11–38`:
- `Form` with `SyncStatusSection`, `NotificationsSection`,
  `DevModeSection`. Inline comment notes "v1.0 adds About, themes,
  biometrics, and export sections below this one" — the attach point
  is already acknowledged.

**Prior work**: none. No export/import commits, no prior plans.

## Proposed approach

A thin DTO layer + two services + a Settings section.

### File shape

```json
{
  "formatVersion": 1,
  "exportedAt": "2026-04-18T14:30:00Z",
  "appVersion": "0.2.0",
  "habits": [
    {
      "id": "UUID",
      "name": "Meditate",
      "frequency": { "kind": "daily" },
      "type": { "kind": "timer", "targetSeconds": 600 },
      "createdAt": "2026-01-10T09:00:00Z",
      "archivedAt": null,
      "color": "blue",
      "icon": "leaf",
      "remindersEnabled": true,
      "reminderHour": 7,
      "reminderMinute": 30,
      "completions": [
        { "id": "UUID", "date": "2026-04-18T00:00:00Z", "value": 600, "note": null }
      ]
    }
  ]
}
```

- **Nested under habits** rather than flat + `habitID`. Avoids orphan
  completions on import and matches the SwiftData relationship graph.
- **`formatVersion: 1`** — importers reject unknown versions with a
  clear error. Schema-like versioning, separate from
  `KadoSchemaV*`.
- **ISO8601 dates** — matches `WidgetSnapshotStore`'s existing
  convention.
- **Archived habits included** — 100% round-trip requires it.
- **Reuses existing custom Codable** on `Frequency` and `HabitType`.

### Key components

- `BackupDocument` (new, `KadoCore`): Codable root type
  (`formatVersion`, `exportedAt`, `appVersion`, `habits:
  [HabitBackup]`).
- `HabitBackup`, `CompletionBackup` (new, `KadoCore`): Codable DTOs
  that mirror `Habit` / `Completion` with nested completions. DTOs
  rather than making the domain types `Codable` directly — keeps the
  wire format independent of any future domain refactor.
- `BackupExporter` (new, `KadoCore`): reads the live store, builds a
  `BackupDocument`, returns `Data`. Protocol-defined, injectable.
- `BackupImporter` (new, `KadoCore`): parses `Data`, validates
  `formatVersion`, merges into the live store by UUID (habits and
  completions both). Returns a summary (`added`, `updated`, `skipped`).
- `BackupSection` (new, `Kado`): new `SettingsView` section with
  `Export` and `Import` buttons. Export uses `ShareLink` with a
  `FileRepresentation`. Import uses `.fileImporter` with allowed
  content type `.json`.

### Data model changes

None. The SwiftData schema stays at V3. The feature operates on value
snapshots only.

### UI changes

- New `BackupSection` in `SettingsView`, slotted between
  `NotificationsSection` and `DevModeSection`.
- Export path: `ShareLink(item: ...)` that materializes a temp JSON
  file named `kado-backup-YYYY-MM-DD.json`.
- Import path: `.fileImporter(isPresented:allowedContentTypes:
  [.json])`, then a confirmation sheet showing the summary
  (`N habits, M completions — import?`) before committing.
- Error surface: invalid JSON → alert "Not a Kadō backup". Version too
  new → alert "This backup was made by a newer Kadō version."

### Merge semantics (by id)

- **Habits**: for each incoming habit, upsert by UUID. If a habit with
  that id exists, overwrite all fields (incoming wins). If not, insert.
- **Completions**: same, upserted within their parent habit. No cross-
  habit moves — a completion's parent is its exported parent, period.
- **Orphans**: unknown habit id from an orphaned completion (shouldn't
  happen given the nested shape, but guard anyway) → skip with a
  count.
- **Not touched**: habits already in the store whose id isn't in the
  backup stay as-is. Merge doesn't delete. ("Replace all" is a
  different UX and was explicitly deferred by the scoping Q&A.)

### Tests to write

- `@Test("Round-trip preserves every field across export and import")`
- `@Test("Import upserts habit by id — second import doesn't
  duplicate")`
- `@Test("Import inserts new habits and completions without touching
  existing ones")`
- `@Test("Import of newer formatVersion is rejected with a clear
  error")`
- `@Test("Export includes archived habits")`
- `@Test("Canonical JSON shape is stable")` — assert against a fixture
  string, catches accidental breaking changes.
- `@Test("Export orders habits by createdAt for deterministic
  diffs")` — nice-to-have for shell-diffing two backups.
- `@Test("Import preserves Frequency variants and HabitType
  variants")` — belt-and-braces over the existing coding tests, but
  one case through the full backup path.

## Alternatives considered

### Alternative A: flat arrays (`habits`, `completions`) with habitID

- Idea: mirror the SwiftData storage shape exactly.
- Why not: requires a join pass on import, orphan risk if a completion
  references a missing habit, harder to read by eye. Nested wins on
  every axis except database-convenience, and we're not a database.

### Alternative B: make `Habit` and `Completion` directly `Codable`

- Idea: skip the DTO layer, encode domain types.
- Why not: couples the wire format to domain refactors. DTOs cost one
  file each and buy forever-stable on-disk JSON. `Frequency` already
  uses custom Codable for exactly this reason.

### Alternative C: `.kado` custom UTType

- Idea: register `UTType` and file-association so tapping a `.kado`
  in Files opens Kadō.
- Why not: scoping Q&A deferred this to v1.0's backup feature.
  v0.2 ships plain `.json` through `ShareLink` + `fileImporter`.

### Alternative D: include the schema version in the backup

- Idea: record `schemaVersion: 3` so future importers can migrate.
- Why not: the backup is an export of value snapshots, not of the
  `@Model` shape. If the domain changes (e.g. V4 adds a `notes`
  field), add it to `HabitBackup` with a default and bump
  `formatVersion`. Schema version leaking into the wire is the kind
  of thing we'd regret.

## Risks and unknowns

- **Merge-by-id surprises**: if a user exports on device A, edits the
  habit on device B (via CloudKit), then imports the device-A backup
  on device B, the incoming stale copy overwrites device B's edits.
  Mitigation: confirmation sheet shows counts, gives the user an out.
  Acceptable for v0.2; document.
- **Large stores**: users with >1000 completions → multi-MB JSON.
  `ShareLink` and `fileImporter` handle that fine; reminder-sync side
  effects (`WidgetReloader.reloadAll`) should not fire N times mid-
  import. Batch into one post-import reload.
- **`ShareLink` + transient file path**: `ShareLink` with a `URL`
  needs an existing file on disk. We'll write to `FileManager`'s temp
  directory; iOS reaps on its own schedule. Don't cache the URL.
- **`.onChange` + post-import widget reload**: any reminders attached
  to imported habits need `RemindersSync` — which is already
  piggybacked on `WidgetReloader.reloadAll` per the notifications
  compound. Single call after the merge is enough.
- **Archived habits on import**: re-inserting an archived habit
  shouldn't resurface it on Today. `archivedAt` is preserved → Today's
  `@Query` filter keeps it hidden. Confirmed by reading
  `TodayViewModel`.
- **Concurrency**: import is a `ModelContext` mutation. Standard
  MainActor context; no new actor plumbing needed.

## Open questions

- [ ] **Should the Settings section show a last-export timestamp?**
  Persisted preference, stored in `UserDefaults`. Small but visible
  signal "yes, this actually worked." Nice-to-have; not blocking.
- [ ] **Does the confirmation sheet need a per-habit diff?** v0.2
  could ship with just counts ("12 habits, 3 new, 9 updated"). A
  per-habit preview would be a chunk more UI. Default: counts only,
  revisit if the merge semantics bite.
- [ ] **File name convention**: `kado-backup-YYYY-MM-DD.json` is the
  default sketched above. Any reason to include device name or a
  UUID? Probably not — the user can rename in Files.
- [ ] **`exportedAt` and `appVersion` metadata**: `appVersion` is
  cheap (Info.plist read), `exportedAt` is current time. Both are
  read-only metadata on import — no behavior depends on them yet.
  Keep them? My lean: yes, cheap and useful for support.

## References

- [ROADMAP v0.2 Import/Export](../../../ROADMAP.md)
- Prior custom-Codable pattern: `Frequency.swift:22`, `HabitType.swift:23`
- File-I/O template: `WidgetSnapshotStore.swift`
- Settings attach point: `SettingsView.swift:11`
- Apple — [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
- Apple — [fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:))
- Apple — [FileDocument](https://developer.apple.com/documentation/swiftui/filedocument) (alt route for export)
