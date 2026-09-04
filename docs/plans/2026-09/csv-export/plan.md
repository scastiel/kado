# Plan — CSV export (lossless round-trip)

**Date**: 2026-09-04
**Status**: done — build complete, awaiting compound
**Research**: [research.md](./research.md)
**Branch / PR**: `feature/csv-export` — [PR #62](https://github.com/scastiel/kado/pull/62)

## Summary

Add a consolidated, lossless CSV serialization of the existing
`BackupDocument`, with both export and import wired into Settings →
Data behind a format picker. The merge pipeline, `ImportSummary`, and
confirmation sheet are reused untouched — the new code is an RFC 4180
reader/writer and the row⇄document mapping. This closes the CSV claim
`docs/PRODUCT.md` and `site/index.html` already make.

No `@Model` change, so no `KadoSchemaV5` and no CloudKit Production
schema deploy.

## Decisions locked in

- Consolidated single file; one row per completion, habit metadata denormalized onto every row.
- Habits with zero completions emit a metadata-only row (empty completion columns) so they survive the round-trip.
- Lossless with respect to **habits and completions**; `exportedAt` / `appVersion` are envelope provenance and are not carried.
- `format_version` is a repeated column on every row, not a header sniff — it survives column reordering and yields `.unsupportedVersion(Int)` for free.
- Union types encode as `kind:payload`; weekdays are pipe-separated so the field never needs quoting.
- Conflicting denormalized metadata across rows: **first row for a `habit_id` wins**.
- Dates are ISO8601 UTC, matching the JSON encoder's `.iso8601` strategy.
- Delimiter is a fixed `,` with `.` decimals — not localized to `;` for French Excel.
- **No CSV-injection escaping.** A leading `=` stays verbatim; losslessness wins. Documented, not silently accepted.
- Empty field decodes to `nil` for both `archived_at` and `note`; the `""`-vs-empty distinction is not preserved (Excel and Numbers destroy it on re-save).
- Export filename stays `kado-backup-<yyyy-MM-dd>.<ext>` for both formats.
- Import means Kadō's own CSV only. Generic column-mapping import and Loop import stay separate roadmap items.

## Task list

### Task 1: RFC 4180 primitives — tests ✅

**Goal**: Pin the quoting and parsing contract before any implementation exists.

**Changes**:
- `KadoTests/CSVWriterTests.swift` (new)
- `KadoTests/CSVReaderTests.swift` (new)

**Tests / verification**:
- `@Test("Field containing a comma is quoted")`
- `@Test("Field containing a quote doubles it")`
- `@Test("Field containing a newline is quoted and round-trips")`
- `@Test("Plain field is written unquoted")`
- `@Test("Reader accepts CRLF and LF line endings")`
- `@Test("Reader handles a quoted field containing the delimiter")`
- `@Test("Reader handles a quoted field spanning multiple lines")`
- `@Test("Trailing newline does not produce a phantom empty row")`
- `test_sim` confirms red.

**Commit message (suggested)**: `test(csv): add RFC 4180 writer and reader cases`

---

### Task 2: RFC 4180 primitives — implementation ✅

**Goal**: Make Task 1 green with a hand-written reader/writer (no third-party deps).

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/CSV/CSVWriter.swift` (new)
- `Packages/KadoCore/Sources/KadoCore/Backup/CSV/CSVReader.swift` (new)

**Tests / verification**:
- Task 1 suite green.
- The reader must be a character-state machine, **not** `split(separator: "\n")` — a note containing a newline is a real case here, not a hypothetical.

**Commit message (suggested)**: `feat(csv): add RFC 4180 reader and writer primitives`

---

### Task 3: Format and error scaffolding ✅

**Goal**: Introduce the two small types the coder and UI both depend on.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupFormat.swift` (new): `.json` | `.csv`, with `fileExtension` and `UTType`.
- `Packages/KadoCore/Sources/KadoCore/Backup/BackupError.swift` (extend): add `.invalidCSV`, `.malformedRow(line: Int)`. Existing cases untouched.

**Tests / verification**:
- Existing 434 tests stay green; `BackupError` is `Equatable`, so confirm no exhaustive-switch break at call sites.

**Commit message (suggested)**: `feat(backup): add BackupFormat and CSV error cases`

---

### Task 4: CSV backup coder — tests ✅

**Goal**: Pin the column contract and every field-encoding rule before implementing.

**Changes**:
- `KadoTests/CSVBackupCoderTests.swift` (new)

**Tests / verification**:
- `@Test("Every Frequency case round-trips through its CSV encoding")`
- `@Test("Every HabitType case round-trips through its CSV encoding")`
- `@Test("Habit with zero completions survives the round-trip")`
- `@Test("Nil archivedAt and nil note decode back as nil")`
- `@Test("Note containing a comma, quote, and newline round-trips")`
- `@Test("Conflicting habit metadata across rows resolves to the first row")`
- `@Test("format_version higher than current throws unsupportedVersion")`
- `@Test("Row with the wrong column count throws malformedRow")`
- `@Test("Unparseable frequency payload throws invalidCSV")`
- `@Test("Canonical CSV shape")` — golden file. **Generate the expected string by running the encoder once and pasting the output.** Per the PR #16 compound, hand-computing an ISO8601 timestamp burned two `test_sim` cycles.
- `test_sim` confirms red.

**Commit message (suggested)**: `test(csv): add backup coder column and encoding cases`

---

### Task 5: CSV backup coder — implementation ✅

**Goal**: `encode(BackupDocument) -> Data` and `decode(Data) throws -> BackupDocument`.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Backup/CSV/CSVBackupCoder.swift` (new)

**Tests / verification**:
- Task 4 suite green.
- Row order: habits by `createdAt`, completions by `date` — same as `DefaultBackupExporter`, so exports stay diffable.

**Commit message (suggested)**: `feat(csv): encode and decode BackupDocument as CSV`

---

### Task 6: Round-trip integration tests ✅

**Goal**: Prove "lossless" at document *and* store level, not just per-field.

**Changes**:
- `KadoTests/CSVRoundTripTests.swift` (new)

**Tests / verification**:
- `@Test("BackupDocument → CSV → BackupDocument preserves every field")` — reuse the `Set<Fingerprint>` comparison from `BackupRoundTripTests.fullRoundTrip`, which enumerates every field explicitly and so catches any future field that ships without CSV coverage.
- `@Test("Store → CSV → empty store restores every habit and completion")` — export from a seeded in-memory container, decode, `apply` into a fresh one, compare fingerprints.
- `@Test("CSV and JSON exports of the same store carry identical habit data")`.

**Commit message (suggested)**: `test(csv): add document and store round-trip coverage`

---

### Task 7: Consolidate BackupSection's presentation stack ✅

**Goal**: Pure refactor, no behavior change — collapse four `.alert` and two `.sheet(item:)` modifiers into single `PresentedAlert` / `PresentedSheet` enums.

**Changes**:
- `Kado/Views/Settings/BackupSection.swift`

**Tests / verification**:
- Manual: exercise all four existing alert paths (export failure, read failure, invalid JSON, unsupported version) and both sheets (share, import confirm) before adding anything new.
- This is the PR #16 compound's standing warning coming due: *"if you add a fifth alert or a third sheet, consolidate into a single `PresentedAlert` / `PresentedSheet` enum before the presentation stack gets confused."* Doing it as its own commit keeps the diff reviewable and makes a regression bisectable.

**Commit message (suggested)**: `refactor(backup): consolidate BackupSection presentation state`

---

### Task 8: Format picker and CSV import routing ✅

**Goal**: Wire CSV into the UI.

**Changes**:
- `Kado/Views/Settings/BackupSection.swift`

**Tests / verification**:
- "Export Data" becomes a `Menu` with JSON and CSV entries; each writes `kado-backup-<date>.<ext>` and presents the existing share sheet.
- `.fileImporter` accepts `[.json, .commaSeparatedText]`; route on `url.pathExtension`, falling back to sniffing a leading `{` for JSON.
- Keep the `startAccessingSecurityScopedResource()` / `defer stopAccessing...` pairing in `handleFileImport` intact.
- CSV import must reach the same `commitImport` path so it inherits `WidgetReloader.reloadAll` for free — verify widgets and reminders refresh after a CSV import.

**Commit message (suggested)**: `feat(backup): add JSON/CSV format picker to export and import`

---

### Task 9: Localization ✅

**Goal**: EN + FR entries for every new user-facing string.

**Changes**:
- `Kado/Resources/Localizable.xcstrings`

**Tests / verification**:
- Hand-author both languages — `.xcstrings` is source code and is **not** auto-populated under `xcodebuild`; only the Xcode IDE runs that sync.
- New keys: the two picker labels, plus the CSV error messages.
- FR conventions per CLAUDE.md: `tu`, `habitude` feminine agreement.
- `LocalizationCoverageTests` must pass — it fails the build on any EN key without a non-empty FR translation.

**Commit message (suggested)**: `feat(l10n): add FR strings for CSV export and import`

---

### Task 10: Previews, build, and visual verification ✅

**Goal**: Meet the project's definition of done.

**Changes**:
- `Kado/Views/Settings/BackupSection.swift` previews (including one `#Preview("Dark")`).

**Tests / verification**:
- `build_sim` clean with no new warnings on iPhone 17 Pro **and** iPad Air (M4).
- `test_sim` fully green.
- `screenshot` of the Data section with the picker open.
- XcodeBuildMCP tap primitives are not enabled on this install, so the picker cannot be driven from the agent — cover the states with previews and ask for one hand-check of an actual CSV export → import cycle on device.

**Commit message (suggested)**: `feat(csv): add previews and verify on iPhone and iPad`

## Notes during build

- **Tasks 1–2 landed as one commit, not two.** The plan proposed a red
  test commit followed by an implementation commit, but tests
  referencing types that don't exist yet don't *compile*, so the
  intermediate commit would have left the branch unbuildable and
  unbisectable. Ran the red/green loop exactly as planned (`test_sim`
  confirmed 22 compile failures, then 455/455 green) — only the commit
  boundary moved. Later tasks with the same shape will do the same.

- **Task 2: Swift clusters `\r\n` into a single `Character`.** It
  equals neither `"\r"` nor `"\n"`, which broke both primitives at
  once: `CSVWriter.escape` didn't quote a field containing a CRLF pair,
  and `CSVReader` fell through to `default` and appended the pair as
  field content instead of ending the row. The two bugs cancelled out
  in the writer/reader round-trip test, which passed for the wrong
  reason — only the reader's standalone CRLF test caught it. Fixed by
  checking line breaks over `unicodeScalars` in the writer and matching
  an explicit `case "\r\n"` in the reader. Added
  `carriageReturnLineFeedIsQuoted` as a regression test.

  This is worth carrying to compound: it's a Swift-specific trap that
  any hand-written text parser in this codebase can hit, and the
  round-trip test masking it is the more interesting half.

- **`CSVParseError` is separate from `BackupError`** (a refinement to
  Task 3's scope): the RFC 4180 layer stays dependency-free and knows
  nothing about backups. The coder in Task 5 maps `CSVParseError` onto
  `BackupError.invalidCSV`.

- **Task 5: the golden canonical-shape test passed on the first run.**
  The PR #16 lesson says to generate the expected string rather than
  compute it. A cheaper variant worked here: write the fixture
  timestamps, then verify them with `date -u -r 1700000000` before
  running anything. Two seconds of shell beats a two-minute
  `test_sim` cycle, and it generalizes to any test asserting a
  serialized timestamp.

- **`Date.ISO8601FormatStyle` over `ISO8601DateFormatter`.** The value-
  type format style needs no shared formatter instance, which keeps
  `CSVBackupCoder` `Sendable` with no static mutable state. Output is
  byte-identical to the JSON encoder's `.iso8601` strategy, so both
  formats drop sub-second precision the same way.

- **Task 7 turned out to be three alerts and two sheets**, not the
  four alerts the compound remembered. The consolidation was worth
  doing regardless — Task 8 adds two more failure cases, which would
  have made five.

- **Tasks 8–9 landed as one commit.** Task 8 alone introduces EN
  catalog keys with no FR translations, which fails
  `LocalizationCoverageTests`. Same reasoning as Tasks 1–2: don't leave
  a red commit on the branch.

- **`CSVBackupCoder` is constructed at the call site, not injected.**
  Every other service here is protocol-defined and injected via
  `@Entry`, but the coder is a pure value type with no collaborators
  and nothing to stub — a preview or test gains nothing from a mock,
  and the round-trip tests use the real type already.

- **Task 10: the format picker could not be visually verified.**
  It's a `Menu`, which a preview cannot open, and this XcodeBuildMCP
  install has no tap primitives, so Settings → Data is unreachable from
  the agent (the limitation CLAUDE.md records from PRs #5 and #8). What
  *was* verified: clean `build_sim` on iPhone 17 Pro and iPad Air
  11-inch (M4) with no new warnings, a clean launch, and two new
  previews covering the CSV failure copy. **The export → import cycle
  still needs one human hand-check.**

- **Test count**: 434 baseline → 455 after Tasks 1–2 → 461 after
  Task 3 → 479 after Tasks 4–5 → 484 after Task 6, holding through
  Tasks 7–10.

## Risks and mitigation

- **The classic CSV bug is a newline inside a quoted field.** Notes are free text and can contain newlines, so this path is live from day one. Mitigation: Task 1 tests it before Task 2 exists, and the reader is specified as a state machine rather than a line split.
- **The Task 7 refactor could regress the shipped JSON flows.** Mitigation: separate commit, no behavior change, all six presentation paths exercised manually before Task 8 adds to them.
- **Golden-file test drift.** Mitigation: generate expected output from the encoder and paste it, never compute it by hand (PR #16 lesson).
- **`BackupError` gaining cases** could break exhaustive switches. Mitigation: Task 3 lands the cases alone so any break surfaces in a tiny diff.
- **No agent-driven UI verification.** Documented XcodeBuildMCP limitation, hit on PRs #5 and #8. Mitigation: previews plus one user hand-check.

## Integration checkpoints

- **SwiftData**: no schema change, no migration, **no CloudKit Production deploy**. If that stops being true, the CLAUDE.md schema-bump checklist applies in full.
- **Widgets**: CSV import routes through the existing `commitImport`, which already calls `WidgetReloader.reloadAll`. Verify rather than re-implement.
- **Localization**: `LocalizationCoverageTests` is the gate.

## Open questions

None. All research open questions were resolved before planning:
delimiter stays fixed, CSV injection stays unescaped and documented,
filename stays `kado-backup-<date>`.

## Out of scope

- Generic CSV import with column mapping (separate roadmap item).
- Loop Habit Tracker and Streaks import (separate roadmap items).
- Per-habit CSV files and zip archives (Alternative C in research).
- Localized delimiter / decimal separator for French Excel.
- CSV-injection escaping.
- Carrying `exportedAt` / `appVersion` through the CSV envelope.
