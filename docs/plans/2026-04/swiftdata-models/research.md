# Research — SwiftData persistence layer

**Date**: 2026-04-16
**Status**: ready for plan
**Related**:
- [docs/ROADMAP.md](../../../ROADMAP.md) v0.1 § Data and domain
- [docs/plans/2026-04/habit-score-calculator/compound.md](../habit-score-calculator/compound.md) — locked in "value types now, SwiftData wrapper next PR"
- [Kado/Models/](../../../../Kado/Models/) — existing value-type structs

## Problem

The score and frequency services already operate on plain
value-type `Habit` and `Completion` structs. We have no persistence:
quitting the app loses everything. v0.1 needs SwiftData-backed storage
that survives launches, plays nicely with CloudKit when iCloud sync
lands later in v0.1, and supports `VersionedSchema` migrations
**from the first commit** (per `CLAUDE.md`'s SwiftData section).

The goal of this PR: ship a fully-tested persistence layer that the
v0.1 Today / Detail / New-Habit views can fetch from. CloudKit
configuration itself (entitlements, container, sync-state UI) is a
separate follow-up — but the schema must be CloudKit-compatible from
day one, because retrofitting CloudKit constraints onto a shipped
schema is data-loss-prone.

## Current state of the codebase

- `Kado/Models/Habit.swift`, `Completion.swift`, `Frequency.swift`,
  `HabitType.swift`, `Weekday.swift`, `DailyScore.swift` — all value
  types, all `Codable`, `Hashable`, `Sendable`. Habit/Completion now
  hash by `id` only (per PR #2 review).
- `Kado/Services/DefaultHabitScoreCalculator.swift` and
  `DefaultFrequencyEvaluator.swift` consume those value types and
  inject a `Calendar`. They do not import SwiftData.
- `Kado/App/KadoApp.swift` — TabView shell, no `ModelContainer`.
- `Kado/App/EnvironmentValues+Services.swift` — `habitScoreCalculator`
  is the only registered service so far.
- No `@Model` classes exist. No `Schema`, no `ModelContainer`, no
  `Persistence/` subfolder.
- Bundle ID is `dev.scastiel.kado` (per project-bootstrap compound).
  CloudKit container will therefore be `iCloud.dev.scastiel.kado`.

## Proposed approach

A separate `@Model` class layer that **wraps** the value types,
projects to them on read, and lives inside a `KadoSchemaV1` namespace
from commit one. The score/frequency services stay purely
struct-based and remain unit-testable without a `ModelContainer`.

### Naming convention

- `Habit`, `Completion` (structs) — domain value types, unchanged.
- `KadoSchemaV1.HabitRecord`, `KadoSchemaV1.CompletionRecord`
  (`@Model` classes) — persistence layer.
- Top-level `typealias HabitRecord = KadoSchemaV1.HabitRecord` so
  call sites read clean. When v2 ships, the typealias points to v2.

The "Record" suffix mirrors common Swift conventions (CKRecord,
RecordValue) and makes the value-type / persistence-type split
unambiguous at every call site.

### Key components

- **`KadoSchemaV1`** (`enum`, `: VersionedSchema`) — declares
  `versionIdentifier = .init(1, 0, 0)` and `models = [HabitRecord.self,
  CompletionRecord.self]`.
- **`KadoMigrationPlan`** (`enum`, `: SchemaMigrationPlan`) —
  `schemas = [KadoSchemaV1.self]`, `stages = []`. v2 will append.
- **`HabitRecord`** (`@Model final class`) — id, name, frequency,
  type, createdAt, archivedAt, `@Relationship(deleteRule: .cascade,
  inverse: \CompletionRecord.habit) var completions = []`.
- **`CompletionRecord`** (`@Model final class`) — id, date, value,
  note, `var habit: HabitRecord?` (the inverse).
- **`snapshot: Habit` / `snapshot: Completion`** computed properties
  on each Record — pure projection, no business logic.
- **`PersistenceController`** struct — owns the `ModelContainer`,
  exposes a `mainContext: ModelContext`, plus an `inMemory()` factory
  for previews and tests.
- **`ModelContainer` injection** via SwiftUI `Environment` (already
  the project's DI pattern). `KadoApp` builds the live container,
  views fetch via `@Query` or via service methods.

### Data model details

```swift
enum KadoSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitRecord.self, CompletionRecord.self]
    }
}

@Model final class HabitRecord {
    var id: UUID = UUID()
    var name: String = ""
    var frequency: Frequency = .daily   // Codable enum — see below
    var type: HabitType = .binary       // Codable enum — see below
    var createdAt: Date = .now
    var archivedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.habit)
    var completions: [CompletionRecord] = []

    init(...) { ... }

    var snapshot: Habit {
        Habit(id: id, name: name, frequency: frequency, type: type,
              createdAt: createdAt, archivedAt: archivedAt)
    }
}
```

### CloudKit-readiness checklist

Confirmed against [Fatbobman 2025-12](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/):

- [x] Every property has a default value or is optional
- [x] All relationships optional (`completions = []` defaults to
      empty; `habit: HabitRecord?` is nilable)
- [x] Explicit `inverse:` on the parent side
- [x] No `@Attribute(.unique)` (CloudKit forbids it; UUID-based
      app-level identity instead)
- [x] No `@Relationship(deleteRule: .deny)` — only `.cascade` /
      `.nullify`
- [x] No ordered relationships
- [x] CloudKit container will be `.private("iCloud.dev.scastiel.kado")`
      when wired (matches bundle ID)

### Codable enums — known fragility, explicit mitigation

SwiftData on iOS 18 stores `Codable` enums with associated values
natively (no `@Attribute(.transformable)` needed). However, **the
storage format depends on the Swift compiler's synthesized Codable
keys**, which are not stability-guaranteed and use positional `_0`,
`_1` keys. CloudKit treats any encoding change as a breaking
schema change.

Mitigation: **implement custom `Codable` with explicit `CodingKeys`
for `Frequency` and `HabitType`**. The format then survives compiler
upgrades and we own the migration path. This was already flagged in
the PR #2 review as a "future export concern" — it's now load-bearing.

Tradeoff: we lose `#Predicate` filtering on these fields anyway
(SwiftData doesn't support enum-case predicates), so storing as
JSON-shaped structures is no worse than a discriminator-style
denormalization.

### UI changes

None in this PR. The `ContentView` placeholder stays; later v0.1
view PRs will inject the `ModelContainer` and use `@Query
[HabitRecord]`.

### Tests to write

- `KadoSchemaTests`:
  - Schema's `versionIdentifier` is `1.0.0`.
  - Container can be created in-memory without throwing.
- `HabitRecordTests`:
  - Round-trip: create a record → snapshot → equals input.
  - Cascade delete: deleting a HabitRecord removes its completions.
  - Optional `archivedAt` defaults to nil.
- `CompletionRecordTests`:
  - Inverse relationship: setting `record.habit = h` populates
    `h.completions`.
- `FrequencyCodingTests`, `HabitTypeCodingTests`:
  - JSON round-trip for every case.
  - Stable JSON shape: assert exact bytes for each canonical case
    (`{"kind":"daily"}`, etc.) so a future compiler change can't
    silently break persistence.
- `PersistenceControllerTests`:
  - In-memory factory works.
  - `save()` is idempotent.

## Alternatives considered

### Alternative A: Drop the value-type structs, use `@Model` everywhere

- Idea: rename `HabitRecord` → `Habit`, delete the struct, change the
  score calculator to take `@Model Habit`.
- Why not: tests would need a `ModelContainer` (slower, requires
  `@MainActor`, ergonomics regression). The compound doc explicitly
  locked in "pure value types stay" as a design invariant — the
  calculator's testability was hard-won.

### Alternative B: Protocol-based unification (`HabitProtocol`)

- Idea: define a `HabitProtocol` with all read-only fields; both
  struct and class conform. Calculator takes `any HabitProtocol`.
- Why not: SwiftData `@Model` + protocol conformance is awkward
  (predicates can't see protocol witnesses, generic `where`
  constraints break). Existential overhead. The value-type struct
  is already small enough that explicit projection is cheaper than a
  shared protocol.

### Alternative C: Store `Frequency` and `HabitType` as JSON-encoded `Data`

- Idea: `var frequencyData: Data` with a get/set wrapper.
- Why not: SwiftData's native Codable support gets us the same
  outcome with less boilerplate, as long as we own the Codable
  format ourselves (which we will). Manual Data wrapping would also
  prevent SwiftData's diff detection from seeing field changes
  cleanly.

### Alternative D: Wire CloudKit in this PR

- Idea: ship persistence + iCloud sync as one PR.
- Why not: CloudKit setup needs entitlements, an Apple Developer
  Account-side container creation in CloudKit Dashboard, and
  entitlement file edits in the Xcode project. Mixed local-only +
  CloudKit configuration is hard to test. Better as a separate PR
  once the local layer is proven.

## Risks and unknowns

- **Custom Codable for enums-with-associated-values has a known
  Xcode-Previews crash on delete**
  ([Fatbobman](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/)).
  Mitigation: previews use `inMemory()` containers and avoid
  delete operations. Tests use the same path.
- **Naming: `HabitRecord` typealias may conflict with Apple
  frameworks.** Quick `grep` in iOS SDK suggests no conflict
  (CloudKit uses `CKRecord`). Worst case rename later.
- **The score calculator's `completions: [Completion]` parameter
  invites callers to project `record.completions.map(\.snapshot)` on
  every render.** For ~20 habits with ~100 completions each, that's
  fine. Caching is post-MVP per spec.

## Open questions

All four pre-plan questions resolved on 2026-04-16:

- **Top-level typealias**: yes —
  `typealias HabitRecord = KadoSchemaV1.HabitRecord` for ergonomic
  call sites. Schema-namespace stays explicit only in migration code.
- **Persistence injection**: SwiftUI's `.modelContainer(_:)` modifier
  on `KadoApp`. No separate `PersistenceController` until we discover
  we need test-time overrides — `ModelContainer` already exposes
  in-memory configurations for previews and tests.
- **Preview seed data**: yes — small helper under `Preview Content/`
  that builds an in-memory `ModelContainer` with a few sample habits.
- **CloudKit wiring**: deferred to a separate PR. Schema must be
  CloudKit-shape from day one (this PR), entitlement / container
  wiring happens later.

(Schema version identifier scheme — semver, `1.0.0` for v1, bump
major when a migration stage is added — moved to Proposed approach
above.)

## References

- [SwiftData VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [SwiftData SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [WWDC23 — Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/)
- [Fatbobman — Codable + enums in SwiftData (caveats)](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/)
- [Fatbobman — CloudKit-ready model rules (Dec 2025)](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [Hacking with Swift — VersionedSchema migrations](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-a-complex-migration-using-versionedschema)
- [SE-0295 — Codable synthesis for enums with associated values](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0295-codable-synthesis-for-enums-with-associated-values.md)
