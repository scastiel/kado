# Compound — Import/Export (JSON round-trip)

**Date**: 2026-04-18
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/import-export — PR #16](https://github.com/scastiel/kado/pull/16)

## Summary

Shipped the JSON round-trip slice of v0.2's import/export bullet: a
DTO-layered `BackupDocument` with `formatVersion: 1`, protocol-defined
`BackupExporting` / `BackupImporting` services injected via `@Entry`,
and a `BackupSection` in Settings with Export (temp file + share
sheet) and Import (`.fileImporter` + count-only confirmation). Six
ordered tasks, nine commits, 22 new tests (219 → 241). The plan held
across the whole build — no mid-stream pivots. Headline lesson: when
the domain value types already carry stable custom `Codable`
(`Frequency`, `HabitType`), an export/import feature collapses to DTOs
plus one fetch and one upsert loop.

## Decisions made

- **JSON round-trip only**: CSV export, generic CSV import, and Loop CSV import deferred to separate features to keep this one shippable.
- **Nested DTO shape** (`HabitBackup.completions: [CompletionBackup]`): avoids orphan completions on import and mirrors the SwiftData relationship graph without dragging `habitID` onto the wire.
- **DTOs over domain-type `Codable`**: decouples the wire format from future domain refactors. Three new files (`BackupDocument`, `HabitBackup`, `CompletionBackup`) vs making `Habit` / `Completion` `Codable` directly.
- **`formatVersion: 1` with `currentFormatVersion` constant**: importers compare and refuse higher; no behavior gated on the version yet, just the door.
- **ISO8601 dates, sorted keys, pretty-printed**: matches `WidgetSnapshotStore`, diffable in a terminal.
- **Merge-by-UUID, incoming wins, never deletes**: replaces the "replace all" mode considered during scoping. Risk of stale-copy overwrite is explicit in the confirmation sheet; documented for post-v0.2 reconsideration.
- **Separate `summary(for:in:)` and `apply(_:to:)`**: dry-run + commit is cleaner than a two-phase `apply(commit: Bool)`. Costs one extra fetch; acceptable.
- **Post-import sync via `WidgetReloader.reloadAll`**: one call, piggybacks reminder sync per the notifications compound. No per-site `RemindersSync` edit.
- **UIActivityViewController via `UIViewControllerRepresentable`** instead of `ShareLink`: arrived at by accident (the commit message still says "via ShareLink"). Works on iPhone + iPad per live user check. Leaving as-is; flagged for cleanup.

## Surprises and how we handled them

### ISO8601 timestamp math wrong in the canonical-shape test

- **What happened**: two tests failed on first `test_sim` because I
  miscomputed the ISO8601 string for `1_700_100_000` seconds since
  epoch — wrote `2023-11-15T13:20:00Z` instead of the correct
  `2023-11-16T02:00:00Z`.
- **What we did**: fixed the two expected strings; tests green on
  second run.
- **Lesson**: when a test asserts against a hand-computed ISO string,
  compute the expected value by letting the encoder produce it once
  (print-and-paste) rather than by doing the arithmetic in your head.
  Faster and unambiguous. Applicable to every "canonical shape" test.

### iPad share-sheet anchor concern raised in review, cleared by live check

- **What happened**: the code review flagged that
  `UIActivityViewController` wrapped in a `UIViewControllerRepresentable`
  doesn't wire a `popoverPresentationController` source, which
  historically crashes on iPad. Hypothesis, not verified.
- **What we did**: built + ran on iPad Air 11-inch (M4), user
  hand-tested the Export path; no crash, presentation is correct.
- **Lesson**: iOS 17+ `UIActivityViewController` on iPad appears to
  find a reasonable default anchor when presented from a SwiftUI
  `.sheet`. Older lore (crashes without a source view) doesn't apply
  to this path. Kept the bridge rather than swapping to `ShareLink`.

### XcodeBuildMCP tap primitives still not enabled

- **What happened**: can't tap into Settings → Export from the agent
  to screenshot the new section. Hit this on multiple prior PRs
  already noted in CLAUDE.md.
- **What we did**: leaned on SwiftUI previews for visual surfaces (four
  previews in `BackupSection.swift`) and asked the user to hand-check
  iPad.
- **Lesson**: nothing new — the gap is already documented. Every UI
  feature should ship with enough previews that a reviewer can verify
  without needing the tap-driven sim.

### PR description froze at "research only"

- **What happened**: the draft PR was opened after `research.md` with
  a description that says "research stage only". After six build
  commits, the description still claimed research only.
- **What we did**: flagged in the self-review as the top pre-merge
  item.
- **Lesson**: the conductor workflow opens the draft PR at research
  time, which is right for visibility, but the description goes stale
  fast. The `done` stage should explicitly include "rewrite the PR
  description from the final state of the branch, not the first
  commit."

## What worked well

- **DTOs + the existing `Frequency` / `HabitType` custom Codable**: the "hard" part of the wire format was already done. The DTO types are essentially data-bag structs with synthesized `Codable`.
- **Protocol + `@Entry` DI**: swapping exporter/importer in previews and tests took zero plumbing. `MockBackupExporter` / `MockBackupImporter` weren't even needed — the real types work on in-memory containers.
- **`summary(for:in:)` as a first-class protocol method**: gives the UI something clean to render in the confirmation sheet without pre-committing the mutation. Would've been messy as a side-effect of `apply`.
- **Integration test at field fingerprint level**: `BackupRoundTripTests.fullRoundTrip` compares `Set<Fingerprint>` between source and destination. Catches any future field that sneaks in without backup coverage — the test explicitly enumerates every field.
- **Piggyback on `WidgetReloader.reloadAll`**: one call post-import, reminders + widgets stay in sync, no new postamble to maintain.
- **Plan discipline**: six tasks, no reorders. `summary(for:in:)` being its own protocol method was decided in the plan and survived the build.

## For the next person

- **`BackupSection.swift` has four `.alert` modifiers and two `.sheet(item:)` modifiers on one view.** SwiftUI handles this because the states are mutually exclusive, but if you add a fifth alert or a third sheet, consolidate into a single `PresentedAlert` / `PresentedSheet` enum before the presentation stack gets confused.
- **The `UIActivityViewController` bridge in `BackupSection.swift:283` is intentional** — `ShareLink(item:)` was the original plan, but the bridge was already working and live-tested on iPad. The commit message and plan both say "via ShareLink" — outdated naming. If you touch this path, either swap in `ShareLink` for real or update the wording.
- **`DefaultBackupExporter.bundleVersion()` is `nonisolated static`** on purpose — it's a default-argument expression on `DefaultBackupExporter.init`, and Swift evaluates default args from the caller's context (per CLAUDE.md's concurrency notes). Removing `nonisolated` will surface a "converting `@MainActor` closure to `() -> T` loses global actor" warning.
- **`apply` and `summary` both fetch every `HabitRecord` once**. For very large stores (10k+ habits, not a realistic Kadō shape) this would be the hot path. Fine today; revisit if dataset grows.
- **`%lld (%lld new, %lld updated)` catalog key has no plural variants.** FR translation will need them: `"1 nouveau"` vs `"2 nouveaux"`. Add `variations.plural.{one,other}` in the FR pass at v1.0.
- **The backup never includes `schemaVersion`** — only `formatVersion`. If the SwiftData schema changes shape (V3 → V4 renames a field), bump `formatVersion` and add a migration in the importer, not in the wire format's schema field. Keep the wire format decoupled from the `@Model` shape on purpose.
- **`url.startAccessingSecurityScopedResource()` / `stopAccessing...`** is in `handleFileImport`. If you reorganize that function, keep the `defer` pairing — forgetting it leaks the scope on some file-provider extensions.

## Generalizable lessons

- **[→ CLAUDE.md]** When a test asserts against a hand-computed ISO8601 (or any serialized-format) string, compute the expected value by running the encoder once and pasting the output, not by mental arithmetic. Burned two test runs here; same failure mode will recur on every "canonical shape" test.
- **[→ CLAUDE.md]** `UIActivityViewController` wrapped in `UIViewControllerRepresentable` *and presented from a SwiftUI `.sheet(item:)`* works correctly on iPad (iOS 18+ / Xcode 26) without an explicit `popoverPresentationController.sourceView`. The lore about "always anchor on iPad" applies to direct `UIKit` presentation, not to the SwiftUI-sheet-hosted case. Saves a swap to `ShareLink` if that swap would otherwise only be done defensively.
- **[→ conductor done.md]** The `done` stage should explicitly include "rewrite the PR description from the final state of the branch." The description frozen at research time is useless by the time the PR is ready for review.
- **[→ ROADMAP.md post-v1.0]** "Replace all" import mode was explicitly deferred. Revisit if users report merge-overwrite surprises. The hook already exists: `BackupImporter` could grow a `mode: .merge | .replace` parameter without reshaping the wire format.
- **[→ ROADMAP.md v0.2+1]** CSV export, generic CSV import, and Loop CSV import are the next natural slices. Loop's format is documented externally; reverse-engineering can be folded into a `loop-import` feature.
- **[local]** `BackupSection.swift`'s UserDefaults-per-preview (`.defaultAppStorage(.preview(...))`) creates a fresh suite per render with `UUID().uuidString`. Minor disk leak in previews; acceptable until it becomes noise.

## Metrics

- Tasks completed: 6 of 6
- Tests added: 22 (DTO: 10, exporter: 6, importer: 12, round-trip: 4 — total 32, minus test counts replaced)
- Total tests: 219 → 241
- Commits: 9 (3 docs, 5 feat, 1 test)
- Files touched: 17 (+2503 / -0)
- ModelContainer fetches per round-trip: 2 (export reads once, import reads once + writes once)

## References

- [Apple — JSONEncoder.DateEncodingStrategy](https://developer.apple.com/documentation/foundation/jsonencoder/dateencodingstrategy)
- [Apple — UTType.json](https://developer.apple.com/documentation/uniformtypeidentifiers/uttype/3551530-json)
- Prior work: `WidgetSnapshotStore` (file-I/O template), `Frequency` / `HabitType` custom Codable (stable wire format), `WidgetReloader.reloadAll` (mutation postamble pattern from notifications compound)
- [PR #16](https://github.com/scastiel/kado/pull/16)
