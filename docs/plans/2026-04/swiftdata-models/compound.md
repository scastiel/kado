# Compound — SwiftData persistence layer

**Date**: 2026-04-16
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [feature/swiftdata-models](https://github.com/scastiel/kado/pull/3)

## Summary

Shipped the `KadoSchemaV1` SwiftData layer: `HabitRecord` /
`CompletionRecord` `@Model`s wrapping the existing value types,
`KadoMigrationPlan` with empty stages, `ModelContainer` wired into
`KadoApp`, and a seeded in-memory `PreviewContainer`. CloudKit-shape
compliance from day one; actual CloudKit wiring deferred. **Headline
lesson: research's recommended path (native Codable enum storage on
`@Model`) crashes `ModelContainer.init` at runtime on this toolchain
— the JSON-Data backing fallback works but doubles the value of the
custom `Codable` we ship.**

## Decisions made

- **`HabitRecord` (`@Model`) wraps `Habit` (struct)**: separate
  persistence and domain concerns. The score / frequency services
  stay struct-based and unit-testable without a `ModelContainer`.
- **Top-level `typealias HabitRecord = KadoSchemaV1.HabitRecord`**:
  ergonomic call sites; schema-namespace stays explicit only in
  migration code.
- **Custom `Codable` with discriminator JSON**: `{"kind":"daily"}`,
  `{"kind":"counter","target":8}`, etc. Stable across compiler
  upgrades; locked in via canonical-shape tests.
- **`nonisolated enum` for value types with Codable conformance**:
  the bootstrap project sets
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise
  push the synthesized conformances to MainActor and warn from
  off-MainActor tests.
- **`@Relationship(deleteRule: .cascade, inverse:
  \CompletionRecord.habit)`**: explicit inverse on the parent side,
  no attribute on the child side (Apple's documented pattern).
- **`snapshot` is read-only**: no setter. Mutation goes through the
  `@Model` class's own properties.
- **`ModelContainer` wired via `.modelContainer(_:)` modifier** on
  `KadoApp` — no `PersistenceController` wrapper. Failure to
  construct is `fatalError` (the app can't recover).
- **JSON-encoded `Data` blobs for `Frequency` and `HabitType`**
  (forced by SwiftData rough edge — see surprise below). Backed by
  `private` properties; computed `var frequency`/`var type` exposes
  the typed value.
- **Encode helper `try!`, decode helper `try? ?? fallback`**:
  encoding our own Codable types is unreachable (fail loud);
  decoding from disk can hit corruption (fall back to neutral
  default).
- **CloudKit deferred** to its own PR — but the `@Model` shape is
  CloudKit-ready (every property has a default or is optional, no
  unique constraints, the to-many relationship has an explicit
  inverse, no `Deny` delete rule).
- **`KadoMigrationPlan.stages = []`** until v2 schema lands. Empty
  is correct — the first `MigrationStage.lightweight(...)` example
  comes with KadoSchemaV2.
- **PR is invisible in the running app**: this is plumbing only. No
  view consumes the data yet. Today/Settings stay
  `ContentUnavailableView` placeholders. v0.1 view PRs surface the
  data.

## Surprises and how we handled them

### Native Codable enum storage on `@Model` crashes `ModelContainer.init`

- **What happened**: Following research's recommendation, declared
  `var frequency: Frequency = .daily` as a stored property on
  `HabitRecord`. Build was clean, but every test using
  `ModelContainer(for: HabitRecord.self, ...)` crashed at
  container-init time. Tried optional storage (`Frequency? = nil`) —
  same crash. Tried both-no-default — same crash. The crash happens
  the moment a Codable composite enum is declared as a stored property,
  regardless of the default.
- **What we did**: Bisected by stripping `HabitRecord` to
  `id + name + createdAt`, confirmed it built and tested clean, then
  added fields back one at a time. The exact moment of breakage:
  adding the `frequency: Frequency` property. Switched to
  research's Alternative C: store as JSON-encoded `Data` blob with
  computed accessors. Custom `Codable` from Task 1 now backs both
  the on-disk format AND the schema property — earning its keep
  twice.
- **Lesson**: Research helpers can be wrong about toolchain-specific
  behavior. The Hacking with Swift / Fatbobman articles cited say
  native Codable storage works; reality on Xcode 26 / iOS 18.4 (this
  bootstrap) says otherwise. **Always verify load-bearing claims
  with a smoke test before committing the design.** A 2-minute
  experiment up front would have saved a 15-minute mid-build pivot.

### Swift 6 main-actor isolation warnings on Codable conformance

- **What happened**: After custom `Codable` landed on `Frequency` and
  `HabitType`, the test target produced 17 warnings of the form
  `main actor-isolated conformance of 'Frequency' to 'Encodable'
  cannot be used in nonisolated context`. CLAUDE.md's "definition of
  done" forbids new warnings.
- **What we did**: Traced the cause to the bootstrap project's
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting (Xcode 26's
  "approachable concurrency" default), which propagates MainActor
  isolation to every type. Codable conformances inherit it; tests
  off-MainActor warn. Fixed by marking the enums `nonisolated enum
  Frequency` — one keyword cleared all 17.
- **Lesson**: When Swift 6 isolation warnings appear on a value type,
  the fix is `nonisolated` on the type declaration. Worth promoting
  to CLAUDE.md alongside the existing `Calendar` / dependency-injection
  conventions.

### `@Model` macro accepts `private` stored properties

- **What happened**: PR #3 review flagged `frequencyData`/`typeData`
  as unnecessarily public. Wasn't sure whether SwiftData's `@Model`
  macro would accept `private` on stored properties.
- **What we did**: Tried it. Worked first time — 59/59 tests still
  pass.
- **Lesson**: Default to `private` for backing storage of computed
  accessors on `@Model` classes. The macro doesn't fight it.

## What worked well

- **TDD on Codable shapes**: round-trip tests + canonical-shape
  assertions caught the synthesized format mismatch (`{"daily":{}}`
  vs `{"kind":"daily"}`) before any custom impl ran. The custom
  encoder went green on the first pass against red tests.
- **Bisection technique for opaque SwiftData crashes**: stripping
  `HabitRecord` to bare minimum and adding fields back one at a time
  converged to the cause in five iterations. Faster than reading any
  amount of SwiftData documentation would have been.
- **Research stage before plan**: the four pre-plan questions
  (typealias, controller wrapper, preview seed, CloudKit deferral)
  were settled before any code. Zero rework on naming or wiring
  shape during build.
- **Per-task in-memory `ModelContainer` in test `init()`**: complete
  isolation, no shared state. Swift Testing's per-instance
  parallelism comes for free. Did require `@MainActor` on the suite
  struct, which was painless.
- **Chaining the score-calc PR's nonisolated/Calendar lessons**: the
  `nonisolated enum` fix was instinctive because PR #2's compound
  had already promoted similar concurrency rules.

## For the next person

- `HabitRecord` has **two storage layers** for `Frequency` /
  `HabitType`: the `private` JSON-Data blob and the public computed
  accessor. Don't try to "simplify" by removing the Data layer — it
  exists because SwiftData on this toolchain crashes on direct
  composite-Codable storage. Re-test before changing.
- `snapshot` decodes JSON on every call (~2 allocations per habit,
  per render). Fine for v0.1 (≤50 habits). When the Today view feels
  sluggish, cache `snapshot` (or skip it and pass `HabitRecord`
  through a small protocol).
- `KadoApp.container` is built **eagerly at App init** — file-backed
  store, no in-memory. **Don't preview `KadoApp` directly** in
  Xcode; preview individual views with
  `.modelContainer(PreviewContainer.shared)`.
- Adding a new `@Model`: edit `KadoSchemaV1.models` array, add the
  type to in-memory test containers (`HabitRecordTests`,
  `CompletionRecordTests`, `KadoSchemaTests`,
  `PreviewContainerTests`).
- When v2 schema lands: copy v1's models into a `KadoSchemaV2`
  namespace, append a `MigrationStage.lightweight(...)` (or
  `.custom`), append `KadoSchemaV2.self` to
  `KadoMigrationPlan.schemas`. Update the typealiases at the bottom
  of the record files to point at v2.
- The PR is **invisible in the simulator** — verifying wiring means
  launching the app and confirming it doesn't crash, plus running
  tests. Visual changes start with v0.1 view PRs.
- The 4 semantic decisions from PR #2 (rolling 7-day window,
  off-schedule completions ignored, current frequency retroactive,
  negative habit = presence-not-value) carry forward — they live in
  the score calculator and `FrequencyEvaluator`, both of which
  consume `snapshot` outputs unchanged.

## Generalizable lessons

- **[→ CLAUDE.md]** When the project's
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` would otherwise push a
  domain value type's conformances to MainActor (causing warnings
  from off-MainActor tests), mark the type `nonisolated enum X`
  (or `nonisolated struct X`). Apply when adding `Codable` to a
  domain type.
- **[→ CLAUDE.md]** SwiftData on Xcode 26 / iOS 18 does not reliably
  support composite `Codable` enums (associated values) as direct
  stored properties on `@Model` — `ModelContainer.init` crashes at
  runtime even though build is clean. Workaround: store as
  `Data` (private), expose as a computed property with explicit
  encode/decode. Document as the canonical pattern for now;
  re-evaluate when Apple fixes it.
- **[→ CLAUDE.md]** When a research helper's claim is load-bearing
  for a design decision (e.g. "this storage shape works"), verify
  with a 2-minute smoke test before committing the design. Saves
  mid-build pivots.
- **[local]** The bisection technique for opaque SwiftData crashes:
  strip `@Model` to `id` + one trivial property, add back one
  property at a time, find the breakage. Beats reading the SwiftData
  source.
- **[ROADMAP, v0.2]** Schema caching for `snapshot`: when the Today
  view scales past 50 habits, `record.snapshot` becoming a hot path
  is the most likely first perf regression. Profile before
  optimizing.

## Metrics

- Tasks completed: 4 of 4
- Tests added: 22 (FrequencyCoding 5, HabitTypeCoding 4,
  HabitRecord 6, CompletionRecord 2, KadoSchema 4, PreviewContainer 1)
- Commits on branch: 7 (research, plan, 4 build, 1 review-fix)
- Files added: 5 source + 6 test + 3 docs
- Net diff: +1,177 / -2 across 17 files
- Plan revisions during build: 1 (Task 2 storage strategy pivot)
- Mid-build pivots: 1 (native Codable → JSON-Data backing)
- Build time (incremental): ~3-5s; test suite: ~6s

## References

- [SwiftData VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [SwiftData SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Fatbobman — Codable + enums in SwiftData (the article that overstated native support)](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/)
- [Fatbobman — CloudKit-ready model rules (accurate)](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
- [PR #2 compound](../habit-score-calculator/compound.md) — the score-calculator-side context this PR plugs into.
