# Plan — Import/Export (JSON round-trip)

**Date**: 2026-04-18
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Ship a JSON round-trip: **Export data** and **Import data** buttons in
Settings, backed by a DTO-layered backup document (`BackupDocument` →
`HabitBackup` → `CompletionBackup`) with `formatVersion: 1`. Export
writes `kado-backup-YYYY-MM-DD.json` via `ShareLink`. Import uses
`.fileImporter`, shows a count-only confirmation sheet, and upserts
habits and completions by UUID (incoming wins; never deletes). No
schema change.

## Decisions locked in

- **Scope**: JSON round-trip only. CSV export, generic CSV import, and
  Loop import deferred to separate features.
- **Wire format**: nested under habits, `formatVersion: 1`, ISO8601
  dates, includes archived habits, keeps `exportedAt` and `appVersion`
  metadata.
- **DTOs rather than domain-type Codable**: `BackupDocument`,
  `HabitBackup`, `CompletionBackup` in `KadoCore`. Decouples wire
  format from any future domain refactor.
- **Merge semantics**: upsert by UUID at both habit and completion
  level. Incoming wins on conflict. Existing habits not in the backup
  stay untouched.
- **File UX**: `ShareLink` for export, `.fileImporter` for import.
  `.json` only (no custom UTType in v0.2).
- **Default filename**: `kado-backup-YYYY-MM-DD.json`.
- **Confirmation sheet**: counts only ("12 habits: 3 new, 9 updated"
  + Import/Cancel). No per-habit diff.
- **Last-export timestamp**: persisted in `UserDefaults` via
  `@AppStorage`, shown under the Export button in Settings.
- **Post-import sync**: one `WidgetReloader.reloadAll` call after the
  merge commits; it already piggybacks reminder sync per the
  notifications compound.
- **DI pattern**: exporter and importer injected via `Environment`
  (matches `HabitScoreCalculator` and `CompletionToggler` patterns).

## Task list

### Task 1: Codable DTOs + canonical JSON fixture test

**Goal**: lock the wire format before any service reads or writes it.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupDocument.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Backup/HabitBackup.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Backup/CompletionBackup.swift` (new)
- `KadoTests/BackupDocumentCodingTests.swift` (new)

**Details**:
- `BackupDocument`: `formatVersion: Int`, `exportedAt: Date`,
  `appVersion: String`, `habits: [HabitBackup]`.
- `HabitBackup`: mirror every `Habit` field + nested `completions:
  [CompletionBackup]`.
- `CompletionBackup`: mirror every `Completion` field except `habitID`
  (parent is the enclosing `HabitBackup`).
- Use synthesized `Codable`; the nested `Frequency` / `HabitType`
  already carry their own custom coders.
- Encoder setup: `dateEncodingStrategy = .iso8601`, `outputFormatting
  = [.prettyPrinted, .sortedKeys]` for deterministic diffs.

**Tests / verification**:
- `@Test("Canonical JSON shape is stable")` — decode a fixture string
  and re-encode it, compare byte-for-byte.
- `@Test("Round-trip preserves every HabitBackup field")` — seed a
  `HabitBackup` with every field set, encode/decode/compare.
- `@Test("Frequency and HabitType variants round-trip through backup")`
  — one case per variant of each enum.
- `@Test("formatVersion defaults to 1")` — sanity.
- `test_sim` green.

**Commit message**: `feat(import-export): backup DTOs with canonical JSON shape`

---

### Task 2: BackupExporter service + tests

**Goal**: read the live store into a `BackupDocument`.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupExporter.swift` (new)
- `KadoTests/BackupExporterTests.swift` (new)

**Details**:
- Protocol `BackupExporting`: `func export(context: ModelContext) throws
  -> Data`.
- `DefaultBackupExporter`: fetches all `HabitRecord` (including
  archived), sorts by `createdAt`, maps to `HabitBackup` via
  `HabitRecord.snapshot` → `HabitBackup.init(habit:completions:)`.
- `appVersion` read from `Bundle.main.infoDictionary` with a "unknown"
  fallback for tests/previews.
- `exportedAt = Date()` at call time.

**Tests / verification**:
- Seed an in-memory `ModelContainer` with 3 habits (one archived) and
  a mix of completions; export; assert counts and ordering.
- `@Test("Export includes archived habits")`.
- `@Test("Export orders habits by createdAt")`.
- `@Test("Export produces valid JSON that decodes back to
  BackupDocument")`.
- `test_sim` green.

**Commit message**: `feat(import-export): exporter that serializes the live store`

---

### Task 3: BackupImporter service + merge-by-id tests

**Goal**: parse a `BackupDocument` and merge into the store by UUID.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupImporter.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Backup/ImportSummary.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupError.swift` (new)
- `KadoTests/BackupImporterTests.swift` (new)

**Details**:
- Protocol `BackupImporting`: `func parse(data: Data) throws ->
  BackupDocument`, `func apply(_ document: BackupDocument, to context:
  ModelContext) throws -> ImportSummary`.
- `ImportSummary`: `totalHabits`, `newHabits`, `updatedHabits`,
  `totalCompletions`, `newCompletions`, `updatedCompletions`.
- `BackupError`: `.invalidJSON`, `.unsupportedVersion(Int)`.
- Version check in `parse`: reject `formatVersion > currentVersion`
  with `.unsupportedVersion`. Unknown-but-lower versions don't exist
  yet → treat as-is.
- Merge logic:
  - Fetch all `HabitRecord` into a `[UUID: HabitRecord]` keyed by
    `id`.
  - For each `HabitBackup`: upsert; if existing, overwrite every
    field; if new, `context.insert(...)`.
  - Walk `CompletionRecord` children via the habit's relationship and
    do the same UUID-keyed upsert for completions. Set the `habit`
    back-reference on new inserts.
  - `context.save()` once at the end.

**Tests / verification**:
- `@Test("Fresh store import inserts every habit and completion")`.
- `@Test("Second import of the same backup is a no-op for counts")` —
  summary reports updated counts but store size identical.
- `@Test("Merge leaves untouched habits alone")` — seed A + B,
  import backup of A + C, expect B still present, A updated, C new.
- `@Test("Incoming fields overwrite existing on conflict")` — name
  change survives the merge.
- `@Test("Unsupported formatVersion raises BackupError.unsupportedVersion")`.
- `@Test("Invalid JSON raises BackupError.invalidJSON")`.
- `@Test("Archived habits round-trip through import")`.
- `@Test("Completions preserve their parent habit relationship")`.
- `test_sim` green.

**Commit message**: `feat(import-export): importer with upsert-by-uuid merge`

---

### Task 4: BackupSection UI — export path

**Goal**: ship a working Export button in Settings (import in next task).

**Changes**:
- `Kado/Views/Settings/BackupSection.swift` (new)
- `Kado/Views/Settings/SettingsView.swift` (add section)
- `Kado/App/EnvironmentValues+Services.swift` (add `backupExporter`,
  `backupImporter` entries)
- `Kado/Resources/Localizable.xcstrings` (new entries)

**Details**:
- Section with heading "Data".
- `ShareLink(item: URL, preview:)` — URL is a temp file written by a
  helper that calls `BackupExporting.export`, writes to
  `FileManager.default.temporaryDirectory.appendingPathComponent("kado-backup-<date>.json")`.
- Date formatter pinned to `en_US_POSIX` gregorian so the filename
  stays consistent regardless of locale.
- `@AppStorage("lastExportAt") var lastExportAt: Double = 0` (seconds
  since epoch; `0` sentinel = never). Updated in the `ShareLink`'s
  `onShare`-equivalent — for `ShareLink`, a `.simultaneousGesture` or
  wrapping the URL build in an on-tap closure.
- Previews: mock `BackupExporting` returning a small fixture;
  dark-mode preview.

**Tests / verification**:
- `build_sim` green.
- Preview renders; tap Export in the sim, confirm the share sheet
  shows a JSON file.
- `screenshot` of Settings with the new section in light and dark.

**Commit message**: `feat(import-export): export button in Settings via ShareLink`

---

### Task 5: BackupSection UI — import path + confirmation + errors

**Goal**: complete the round-trip in the UI. Import via `.fileImporter`,
confirm, apply, reload widgets.

**Changes**:
- `Kado/Views/Settings/BackupSection.swift` (extend)
- `Kado/Views/Settings/ImportConfirmSheet.swift` (new)
- `Kado/Resources/Localizable.xcstrings` (additional entries)

**Details**:
- `.fileImporter(isPresented:, allowedContentTypes: [.json])` on the
  Import button.
- On success: read the file data with `try Data(contentsOf: url)`
  wrapped in `url.startAccessingSecurityScopedResource()` /
  `stopAccessing…`. Call `importer.parse(data:)` and present
  `ImportConfirmSheet` with the document (not yet applied).
- `ImportConfirmSheet`: shows `"12 habits: 3 new, 9 updated"` with
  counts computed by a dry-run pass (compute-and-discard). Import /
  Cancel buttons.
- On Import: call `importer.apply(...)`, then `WidgetReloader.reloadAll`
  (which also reschedules reminders per notifications compound). Show
  a brief success confirmation.
- Error paths:
  - `BackupError.invalidJSON` → alert "This doesn't look like a Kadō
    backup."
  - `BackupError.unsupportedVersion` → alert "This backup was made by
    a newer Kadō version."
  - File read failure → alert "Couldn't read the file."
- Dry-run pass: a separate `BackupImporting.summary(for:in:)` helper
  that walks the document against the current store and returns the
  same `ImportSummary` shape without mutating. Alternative: two-phase
  `apply` that returns before committing. Cleaner to have an explicit
  summary method.

**Tests / verification**:
- Add `@Test("summary(for:in:) reports new vs updated accurately")` to
  `BackupImporterTests`.
- Preview the confirmation sheet with mock summary.
- `build_sim` green, sim walkthrough: import a file exported by the
  same app, confirm the counts page shows "N habits: 0 new, N
  updated" (self-import).

**Commit message**: `feat(import-export): import sheet, confirmation, and error paths`

---

### Task 6: Localization pass, previews, and round-trip integration test

**Goal**: hit the v0.2 exit criterion ("export → import restores 100%
of the data, automated test") and finish polish.

**Changes**:
- `KadoTests/BackupRoundTripTests.swift` (new)
- `Kado/Resources/Localizable.xcstrings` (fill FR where possible for
  new keys, EN-only for now is acceptable per v0.1 baseline)
- Dark-mode and Dynamic Type XXXL previews for `BackupSection` and
  `ImportConfirmSheet`

**Details**:
- Integration test: seed a container with 5 habits (one archived, one
  timer, one counter, one binary, one negative) + ~50 completions
  with varied notes. Export. Nuke the container. Import. Assert every
  persisted field is identical across the round-trip.
- Accessibility: Dynamic Type XXXL preview, VoiceOver labels on the
  two buttons and confirmation summary row.
- Final `build_sim` (iPhone + iPad), `test_sim` full suite,
  `screenshot` of the Settings surface.

**Tests / verification**:
- Full suite green.
- Round-trip integration test explicitly asserted at field level, not
  just count level.
- Screenshot captured.

**Commit message**: `test(import-export): round-trip integration + polish`

---

## Risks and mitigation

- **Stale-copy merge overwrites device-B edits** (documented in
  research): confirmation sheet with counts is the user's out.
  Acceptable for v0.2.
- **Large stores (~MB JSON)**: one-shot encode is fine on-device;
  post-import reload runs once, not per habit. Verified by tasks 3
  and 5.
- **`ShareLink` temp file races**: write the file *before* building
  the `ShareLink`, let iOS's temp cleanup handle eviction. Don't cache
  the URL.
- **Security-scoped URL on import**: easy to forget. Wrapped in
  `start/stopAccessingSecurityScopedResource` in Task 5.
- **`.fileImporter` and iPad picker size**: worth a visual check on
  iPad in Task 6.
- **Empty store export + re-import**: edge case — empty `habits: []`
  should round-trip cleanly. Add one assertion in the round-trip test.

## Open questions

None blocking. Two items carried for future consideration:

- [ ] If users report merge surprises, consider adding a "Replace
  all" mode — this was deferred in the scoping Q&A but is the natural
  next knob.
- [ ] `.kado` custom UTType + file association is a v1.0 item per
  scoping.

## Out of scope

- CSV export (per-habit or consolidated).
- Generic CSV import with column mapping.
- Import from Loop Habit Tracker.
- Custom `.kado` UTType or file association.
- Cross-device "merge wins" heuristics beyond "incoming overwrites."
- Delete-by-id on import (never removes existing habits).
- Restore UI showing a diff preview per habit — counts only for v0.2.
