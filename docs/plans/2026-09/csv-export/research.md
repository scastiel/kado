# Research — CSV export (lossless round-trip)

**Date**: 2026-09-04
**Status**: ready for plan
**Related**: [ROADMAP v0.2 Import/Export](../../../ROADMAP.md#v02--visible-ios-native) (deferred CSV bullets), [import-export research](../../2026-04/import-export/research.md), [import-export compound](../../2026-04/import-export/compound.md)

## Problem

The v0.2 import/export feature shipped the JSON half and explicitly
deferred CSV: "CSV export, generic CSV import, and Loop CSV import are
the next natural slices" ([import-export
compound](../../2026-04/import-export/compound.md)). Nothing has been
built since — there is no occurrence of the string `csv` in any Swift
file in the repo.

Meanwhile `docs/PRODUCT.md`'s competitive gap table already marks Kadō
✅ for **"Export CSV/JSON (core)"**, and `site/index.html` repeats the
claim. That is currently an overclaim: only JSON exists. Closing it is
the point of this feature — CSV is the format spreadsheets, R/pandas,
and every other habit tracker actually speak, and "you can leave at any
time with all your data" (PRODUCT.md differentiator #5) is weaker when
the only exit is a bespoke JSON shape.

Scope decided with the user at research time:

- **Consolidated**: one file for every habit, not a zip of per-habit files.
- **Lossless**: the CSV must be re-importable by Kadō, not just
  readable in Numbers.
- **Format picker**: one "Export Data" affordance in Settings → Data
  that offers JSON or CSV, rather than a second button.
- **Full round-trip**: export *and* import ship together. Import here
  means *Kadō's own CSV*; generic column-mapping import and Loop import
  remain separate roadmap items.

"Done" from the user's perspective: Settings → Data → Export Data →
**CSV**, share sheet, open the file in Numbers and read it. Then import
that same file into a fresh install and get every habit and completion
back.

## Current state of the codebase

**The backup layer already exists and is well-factored** —
`Packages/KadoCore/Sources/KadoCore/Backup/`:

- `BackupDocument` (`formatVersion: 1`, `exportedAt`, `appVersion`,
  `habits: [HabitBackup]`) — the wire-format root, deliberately
  decoupled from the SwiftData schema.
- `HabitBackup` nests `completions: [CompletionBackup]`, so there are no
  orphan-completion or dangling-`habitID` cases to handle.
- `BackupExporting.export(from:) -> BackupDocument` — one fetch, sorted
  by `createdAt`. `encode(_:)` is the JSON-specific step.
- `BackupImporting.parse(data:) -> BackupDocument` is the JSON-specific
  step; `summary(for:in:)` and `apply(_:to:)` are **format-agnostic**
  merge logic (UUID-keyed upsert, incoming wins, never deletes).
- `ImportSummary` and the `ImportConfirmSheet` dry-run flow are done.
- `BackupError` = `.invalidJSON` | `.unsupportedVersion(Int)`.

**Domain types are already CSV-friendly** — the two hard ones carry
hand-owned, stable `Codable` with a `kind` discriminator:
`Frequency` (`.daily` / `.daysPerWeek(Int)` / `.specificDays(Set<Weekday>)`
/ `.everyNDays(Int)`) and `HabitType` (`.binary` / `.counter(target:)` /
`.timer(targetSeconds:)` / `.negative`). `HabitColor` is a String
raw-value enum, `Weekday` an Int raw-value enum (Sunday = 1 … Saturday = 7),
`icon` is a plain SF Symbol string.

**Settings UI** — `Kado/Views/Settings/BackupSection.swift`: "Export
Data" writes a temp `kado-backup-<yyyy-MM-dd>.json` and presents a
share sheet; "Import Data" is a `.fileImporter` limited to `[.json]`.

**What's missing**: any CSV reader/writer. Zero third-party
dependencies are allowed for v0.x, so RFC 4180 quoting is ours to write.

## Proposed approach

**Reuse `BackupDocument` as the intermediate representation.** CSV is a
new *serialization* of an existing document type, not a new pipeline:

```
export:  ModelContext → [existing] export(from:) → BackupDocument → [new] CSVBackupCoder.encode → Data
import:  Data → [new] CSVBackupCoder.decode → BackupDocument → [existing] summary/apply → ModelContext
```

This is the load-bearing decision of the feature. It means **no new
merge logic, no new confirmation sheet, no new `ImportSummary`**, and
the round-trip test can compare `BackupDocument` values directly. The
only genuinely new code is the RFC 4180 layer and the row⇄document
mapping.

### The format

One row per completion, with habit metadata denormalized onto every
row. A habit with no completions emits a single row with the completion
columns empty, so it survives the round-trip.

```
format_version,habit_id,habit_name,frequency,type,created_at,archived_at,
color,icon,reminders_enabled,reminder_hour,reminder_minute,
completion_id,completion_date,value,note
```

Union types encode as `kind:payload`, mirroring the JSON discriminator:

| Value | Encoding |
|---|---|
| `.daily` | `daily` |
| `.daysPerWeek(5)` | `days_per_week:5` |
| `.specificDays([mon, wed, fri])` | `specific_days:2\|4\|6` |
| `.everyNDays(3)` | `every_n_days:3` |
| `.binary` / `.negative` | `binary` / `negative` |
| `.counter(target: 8)` | `counter:8.0` |
| `.timer(targetSeconds: 600)` | `timer:600.0` |

Pipe (not comma) separates weekdays so the field never needs quoting.
Dates are ISO8601 UTC, matching the JSON encoder's `.iso8601` strategy.
`archived_at` and `note` are empty when nil.

**Rules that need to be written down and tested:**

- `format_version` repeats on every row. Redundant, but it survives
  column reordering and gives `.unsupportedVersion(Int)` for free,
  exactly like the JSON gate.
- Denormalized habit metadata can disagree between rows (a user edited
  the file). **First row for a `habit_id` wins**; later rows contribute
  only their completion.
- Row order: habits by `createdAt`, completions by `date` — same as
  `DefaultBackupExporter`, so exports are diffable.
- `exportedAt` / `appVersion` are **not** carried. They are envelope
  provenance, not user data; a re-export regenerates them. "Lossless"
  in this doc means lossless with respect to habits and completions.

### Key components

- `CSVWriter` / `CSVReader` (new, `KadoCore/Backup/CSV/`): RFC 4180
  primitives — quote a field iff it contains `,` `"` CR or LF, double
  embedded quotes, accept both CRLF and LF on read.
- `CSVBackupCoder` (new): `encode(BackupDocument) -> Data` and
  `decode(Data) throws -> BackupDocument`. Owns the column contract.
- `BackupFormat` enum (new): `.json` | `.csv`, with `fileExtension` and
  `UTType`. Picks the coder and the export filename.
- `BackupError` (extended): `.invalidCSV`, `.malformedRow(line: Int)`.
  Existing cases untouched.
- `BackupSection` (modified): "Export Data" becomes a `Menu` with JSON
  and CSV; `.fileImporter` accepts `[.json, .commaSeparatedText]` and
  routes on the file extension.

### Data model changes

**None.** No `@Model` change, no `KadoSchemaV5`, therefore no CloudKit
Production schema deploy. Given issue #52 cost two App Store reviews,
this being a pure serialization feature is worth stating explicitly.

Existing public signatures stay working: `BackupExporting.encode(_:)`
and `BackupImporting.parse(data:)` remain the JSON path. The coder
abstraction is added alongside, not swapped in.

### UI changes

`BackupSection` only. But note the compound doc's standing warning:
that file already carries **four `.alert` and two `.sheet(item:)`
modifiers**, with an explicit "consolidate into a single
`PresentedAlert` / `PresentedSheet` enum before you add a fifth alert."
Adding CSV error cases crosses that line, so the consolidation is part
of this feature, not a follow-up.

New catalog keys (EN + FR hand-authored — `.xcstrings` is source code
and is not auto-populated under `xcodebuild`): the two picker labels
and the CSV error messages. `LocalizationCoverageTests` fails the build
if FR is missing.

### Tests to write

RFC 4180 is where this feature will actually break, so the writer and
reader get the most coverage:

- `@Test("Field containing a comma is quoted")`
- `@Test("Field containing a quote doubles it")`
- `@Test("Note containing a newline round-trips")`
- `@Test("Reader accepts CRLF and LF line endings")`
- `@Test("Every Frequency case round-trips through its CSV encoding")`
- `@Test("Every HabitType case round-trips through its CSV encoding")`
- `@Test("Habit with zero completions survives the round-trip")`
- `@Test("Nil archivedAt and nil note decode back as nil")`
- `@Test("Conflicting habit metadata across rows resolves to the first row")`
- `@Test("format_version higher than current throws unsupportedVersion")`
- `@Test("Row with the wrong column count throws malformedRow")`
- `@Test("Canonical CSV shape")` — golden file. Per the compound's
  lesson, generate the expected string by running the encoder once and
  pasting the output; do not hand-compute ISO8601 timestamps.
- `@Test("BackupDocument → CSV → BackupDocument preserves every field")`
  — reuse the `Set<Fingerprint>` comparison from
  `BackupRoundTripTests.fullRoundTrip`.
- `@Test("Store → CSV → empty store restores every habit and completion")`

Current suite: 434 `@Test` cases across 47 files.

## Alternatives considered

### Alternative A: analysis-oriented flat CSV (lossy)

- Idea: `habit_name,date,value,note` only. Human-first, trivially
  parseable, no union encoding.
- Why not: user chose lossless. JSON would remain the only real exit
  path, and the round-trip claim in PRODUCT.md would stay an overclaim.

### Alternative B: version via header sniffing instead of a column

- Idea: validate the header row against the known v1 column list;
  mismatch means unsupported.
- Why not: can't report *which* version was found, and breaks if a
  spreadsheet reorders columns. Kept as a fallback if the repeated
  column proves too noisy in practice.

### Alternative C: one file per habit, zipped

- Idea: Loop's shape — `Habits.csv` plus a file per habit.
- Why not: user chose consolidated. Also needs a zip writer, which
  means either `AppleArchive` or hand-rolling — real work for no gain
  when one file round-trips fine.

### Alternative D: heterogeneous rows with a `record_type` column

- Idea: `habit` rows and `completion` rows in one file, no
  denormalization, no metadata-conflict rule.
- Why not: unusable in a spreadsheet (columns mean different things per
  row), which forfeits the main reason to want CSV at all.

## Risks and unknowns

- **CSV injection vs losslessness.** A habit named `=cmd|...` is a
  formula when opened in Excel. The standard mitigation — prefixing
  `= + - @` fields with `'` — *mutates user data* and breaks the
  lossless guarantee. Recommendation: stay lossless, document the
  behavior. This is a personal data export the user asked for, not a
  file served to third parties.
- **Empty string vs nil `note`.** RFC 4180 can distinguish `""` from an
  empty field, but Excel and Numbers destroy the difference on
  re-save. Recommendation: treat empty as nil, add a test pinning that
  behavior, and confirm the UI can't produce a non-nil empty note.
- **Whole file built in memory.** Same characteristic as the JSON path
  today; fine at realistic store sizes.
- **Import format detection.** Routing on `url.pathExtension` fails if
  a file manager renames on export. Cheap mitigation: fall back to
  sniffing a leading `{` for JSON.

## Open questions

All resolved with the user before the plan stage — carried into
[plan.md](./plan.md) as locked decisions.

- [x] CSV injection: **accept unescaped `=`-leading fields** as the cost
      of losslessness, and document the behavior.
- [x] FR delimiter: **fixed `,` with `.` decimals**, not localized to
      `;` for French Excel. Revisit on user feedback.
- [x] Export filename: **stays `kado-backup-<date>.<ext>`** for both
      formats — no change to the shipped JSON path.
- [x] Empty vs nil `note`: empty field decodes to `nil`; the `""`
      distinction is not preserved, since Excel and Numbers destroy it
      on re-save.

## References

- [RFC 4180 — Common Format and MIME Type for CSV Files](https://www.rfc-editor.org/rfc/rfc4180)
- [Apple — UTType.commaSeparatedText](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/3551586-commaseparatedtext)
- Prior work: `BackupDocument` / `DefaultBackupExporter` / `DefaultBackupImporter`, `BackupRoundTripTests` (`Set<Fingerprint>` pattern), [PR #16](https://github.com/scastiel/kado/pull/16)
