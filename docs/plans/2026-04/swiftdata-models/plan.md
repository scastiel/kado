# Plan — SwiftData persistence layer

**Date**: 2026-04-16
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Wrap the existing `Habit` / `Completion` value types with `@Model`
classes (`HabitRecord`, `CompletionRecord`) inside a `KadoSchemaV1`
namespace, register a `KadoMigrationPlan` from day one, and wire the
`ModelContainer` into `KadoApp` via SwiftUI's `.modelContainer(_:)`
modifier. CloudKit-shape compliance from the first commit (defaults,
optional relationships, no unique constraints), but no actual
CloudKit wiring — that's a follow-up PR. Custom `Codable` for
`Frequency` and `HabitType` so we own the on-disk format and survive
compiler upgrades.

## Decisions locked in

- **Naming**: `Habit` (struct) + `KadoSchemaV1.HabitRecord` (`@Model`),
  with top-level `typealias HabitRecord = KadoSchemaV1.HabitRecord`
  for ergonomic call sites.
- **TDD strict**: Codable round-trips and projection logic tested
  before implementation. Schema construction tested via in-memory
  `ModelContainer`.
- **Relationships**: `HabitRecord.completions` → `[CompletionRecord]`
  with `@Relationship(deleteRule: .cascade, inverse: \…habit)`.
  `CompletionRecord.habit: HabitRecord?` (nilable per CloudKit).
- **Custom Codable shape**: discriminator-based JSON, e.g.
  `{"kind":"daysPerWeek","count":3}`. Explicit and human-readable;
  one canonical-shape test per case to catch silent compiler regressions.
- **In-memory `ModelContainer` for previews and tests** via
  `ModelConfiguration(isStoredInMemoryOnly: true)`. No
  `PersistenceController` wrapper — `.modelContainer(_:)` modifier
  on `KadoApp` is enough.
- **Schema version identifier**: semver, `Schema.Version(1, 0, 0)`.
  Bump major when a `MigrationStage` is added.
- **CloudKit deferred**: no `cloudKitDatabase:` in `ModelConfiguration`
  this PR. Container ID will be `iCloud.dev.scastiel.kado` when wired.
- **`snapshot` is read-only**: no setter. New records are constructed
  via `init(...)` directly; mutation goes through the `@Model` class's
  own properties.
- **One Codable per type, in the same file as the enum.** The custom
  `Codable` lives in `Frequency.swift` / `HabitType.swift`, not in a
  separate `Models/Persistence/` folder.

## Task list

### Task 1: Custom Codable for Frequency and HabitType ✅

**Goal**: Own the on-disk JSON format for both enums; canonical-shape
tests pin the bytes so a compiler upgrade can't silently break
persisted stores.

**Changes**:
- `Kado/Models/Frequency.swift` — replace synthesized Codable with
  explicit `init(from:)` / `encode(to:)` using a `kind` discriminator.
- `Kado/Models/HabitType.swift` — same pattern.
- `KadoTests/FrequencyCodingTests.swift` — written first.
- `KadoTests/HabitTypeCodingTests.swift` — written first.

**Tests / verification**:
- Round-trip every case (encode → decode → equal).
- Canonical-shape assertion per case, e.g.:
  - `.daily` ↔ `{"kind":"daily"}`
  - `.daysPerWeek(3)` ↔ `{"kind":"daysPerWeek","count":3}`
  - `.specificDays([.monday, .friday])` ↔ `{"kind":"specificDays","days":[2,6]}`
  - `.everyNDays(7)` ↔ `{"kind":"everyNDays","interval":7}`
  - `.binary` ↔ `{"kind":"binary"}`
  - `.counter(target: 8)` ↔ `{"kind":"counter","target":8}`
  - `.timer(targetSeconds: 1800)` ↔ `{"kind":"timer","targetSeconds":1800}`
  - `.negative` ↔ `{"kind":"negative"}`
- Decode rejects unknown `kind` with a `DecodingError`.
- `.specificDays` decodes a serialized day-set order-independently
  (it's a `Set`, not an `Array`).

**Commit**: `feat(models): own Codable shape for Frequency and HabitType`

---

### Task 2: KadoSchemaV1 + HabitRecord + CompletionRecord

**Goal**: The `@Model` layer with bidirectional relationship and
`snapshot` projection back to value types.

**Changes**:
- `Kado/Models/Persistence/KadoSchemaV1.swift` — `enum KadoSchemaV1:
  VersionedSchema` declaring `versionIdentifier` and `models`.
- `Kado/Models/Persistence/HabitRecord.swift` — `@Model final class`
  inside `KadoSchemaV1`, all properties with defaults, `snapshot:
  Habit` computed property, top-level `typealias HabitRecord =
  KadoSchemaV1.HabitRecord`.
- `Kado/Models/Persistence/CompletionRecord.swift` — same shape, with
  `var habit: HabitRecord?` inverse, `snapshot: Completion`.
- `KadoTests/HabitRecordTests.swift`, `KadoTests/CompletionRecordTests.swift`.

**Tests / verification** (in-memory `ModelContainer` per test):
- `HabitRecord(...)` round-trips through `snapshot` to an equal
  `Habit` value.
- `CompletionRecord(...)` likewise; `habitID` in the snapshot matches
  the parent's `id`.
- Setting `record.habit = h` populates `h.completions` (inverse works).
- Cascade delete: deleting a `HabitRecord` removes its
  `CompletionRecord`s from the context.
- All defaults are CloudKit-compatible: every property has a default
  value or is optional (verified by constructing with no args).

**Commit**: `feat(persistence): add HabitRecord and CompletionRecord under KadoSchemaV1`

---

### Task 3: KadoMigrationPlan + ModelContainer wiring in KadoApp

**Goal**: Persistence is live in the running app; container construction
is exercised by tests.

**Changes**:
- `Kado/Models/Persistence/KadoMigrationPlan.swift` — `enum
  KadoMigrationPlan: SchemaMigrationPlan` with `schemas =
  [KadoSchemaV1.self]`, `stages = []`.
- `Kado/App/KadoApp.swift` — apply `.modelContainer(...)` modifier on
  `WindowGroup`. Use a top-level helper to build the live container
  with `KadoSchemaV1` + `KadoMigrationPlan`.
- `KadoTests/KadoSchemaTests.swift` — written first.

**Tests / verification**:
- `KadoSchemaV1.versionIdentifier == Schema.Version(1, 0, 0)`.
- An in-memory `ModelContainer(for: KadoSchemaV1.self, …)` builds
  without throwing.
- `KadoMigrationPlan.stages.isEmpty` (sanity check until v2 lands).
- App still builds and launches (`build_sim` clean, smoke test passes).

**Commit**: `feat(persistence): wire ModelContainer into KadoApp with KadoMigrationPlan`

---

### Task 4: Preview seed helper

**Goal**: SwiftUI previews and tests can spin up an in-memory
`ModelContainer` populated with a small, realistic habit set.

**Changes**:
- `Kado/Preview Content/PreviewContainer.swift` — static factory
  returning a `ModelContainer` (in-memory) seeded with 3-5 sample
  habits covering each `Frequency` and `HabitType` variant, plus a
  handful of completions per habit.
- One preview added to `ContentView.swift` consuming the seeded
  container so the existing placeholder is no longer empty in the
  Xcode preview.

**Tests / verification**:
- `PreviewContainer.shared` (or whatever the API is) yields a
  container whose main context contains the expected number of
  records.
- `build_sim` passes (preview content can compile under Debug).

**Commit**: `feat(preview): seed an in-memory ModelContainer with sample habits`

## Risks and mitigation

- **Risk**: SwiftData inverse-relationship `KeyPath` syntax is
  finicky. → **Mitigation**: follow Apple's documented exact pattern;
  test that setting `record.habit = h` populates `h.completions`
  before declaring Task 2 done.
- **Risk**: Custom `Codable` test shape too strict — adding a future
  enum case requires updating the canonical-shape test suite. →
  **Mitigation**: this is a feature, not a bug. Schema changes
  *should* require touching these tests; that's how we catch silent
  drift.
- **Risk**: `@Model` test ergonomics with `@MainActor` slow the suite
  down. → **Mitigation**: each test gets its own in-memory container
  in `init()`; no shared state. Swift Testing's `@Suite` parallelizes
  per-instance so isolation is free.
- **Risk**: Naming collision — `HabitRecord` typealias might clash
  with an Apple framework type. → **Mitigation**: confirmed no
  conflict in iOS SDK at research time. Worst case: rename later.
- **Risk**: Xcode Previews crash on delete with associated-value enum
  models (known SwiftData bug). → **Mitigation**: previews use
  in-memory containers and never trigger delete operations. Tests use
  the same path.

## Open questions

None at plan time — all four resolved during research.

## Notes during build

- **Task 1**: The project bootstrap set
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26's
  "approachable concurrency" default), so newly-introduced Codable
  conformances inherit MainActor isolation and warn when used from
  off-MainActor tests. Fixed by marking the value-type enums
  `nonisolated` (`nonisolated enum Frequency`). Likely to need the
  same on `Habit`/`Completion`/`Weekday`/`DailyScore` if/when they
  become cross-actor — flag for compound.

## Out of scope

- **CloudKit wiring**: no `cloudKitDatabase:` parameter, no
  entitlements file edits, no iCloud account UI. Separate PR.
- **`@Query`-based view code**: no view fetches `[HabitRecord]` in
  this PR. The existing `ContentView` placeholder stays. v0.1 view
  PRs (Today, Detail, New Habit) consume the container.
- **Habit / Completion CRUD service**: no `HabitStore` or
  `CompletionStore` yet. Direct `ModelContext` use is fine for the
  view PRs to start; we extract a service if/when patterns repeat.
- **Migration to v2**: empty `stages` list. We'll write the first
  `MigrationStage.lightweight(...)` example when the first schema
  evolution lands.
- **JSON export/import**: separate PR (v0.2 per ROADMAP). The custom
  `Codable` we own here is for SwiftData persistence; export will
  layer a versioned schema on top.
