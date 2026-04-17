# Compound — CloudKit sync (v0.1)

**Date**: 2026-04-17
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md)
**Branch / PR**: [`claude/competent-northcutt-131f03`](https://github.com/scastiel/kado/pull/10)

## Summary

Wired SwiftData's CloudKit private database into Kadō, surfaced
account status in Settings (no in-app toggle, by design), and added
a pull-to-refresh affordance after live two-device testing showed
sync isn't real-time. Headline lesson: the CloudKit-shape research
from PR #3 missed the rule that **both sides of a relationship must
be optional**, not just the to-one side. The bug only manifested
when `cloudKitDatabase: .private(...)` was flipped on — flagging the
need for a real, runtime-introspection regression test rather than
human review.

## Decisions made

- **No in-app sync toggle**: control lives in iOS Settings → Apple ID
  → iCloud → Kado, matching Reminders/Notes. Keeps the SwiftData
  container shape stable; an in-app toggle would have required
  data migration between local-only and CloudKit-backed stores.
- **Schema deploy stays on Development**: defer Production push to
  v1.0 release prep so v0.1–v0.3 schema iterations don't become
  CloudKit migration ceremonies.
- **Pre-CloudKit local data**: wipe and start clean rather than write
  migration code. Acceptable because Kadō is pre-ship and the only
  user is the author.
- **`@Entry` macro for `\.cloudAccountStatus`**: hand-rolled
  `EnvironmentKey` with a `static let defaultValue` doesn't compose
  with a `@MainActor`-isolated observer; `@Entry` does.
- **Mock observer in `Preview Content/`**: Debug-only, accessible
  to both SwiftUI previews and tests via `@testable import Kado`.
- **Pull-to-refresh added mid-build**: user noticed sync isn't
  real-time during two-device verification. The handler can't
  accelerate CloudKit but rebinds `@Query` and gives a visual cue.

## Surprises and how we handled them

### Schema bug only surfaced under CloudKit

- **What happened**: PR #3's CloudKit-shape checklist read "every
  property has a default value or is optional, the to-many
  relationship has an explicit inverse." That phrasing left
  `HabitRecord.completions: [CompletionRecord] = []` looking valid.
  The first launch with `cloudKitDatabase: .private(...)` crashed
  in `ModelContainer.init` with `NSCocoaErrorDomain 134060`:
  *"CloudKit integration requires that all relationships be
  optional, the following are not: HabitRecord: completions"*.
- **What we did**: split a `fix(schema):` commit before Task 2 —
  made `completions: [CompletionRecord]?`, coalesced 18 call sites
  with `?? []` / `?.`, ran tests green, then re-applied the
  CloudKit wiring. Wrote `CloudKitShapeTests.allRelationshipsOptional`
  introspecting `Schema.Entity.Relationship.isOptional` so a future
  regression fails at `test_sim`, not at first launch.
- **Lesson**: **runtime schema introspection is the only honest
  CloudKit-shape test**. Manual review of `@Model` declarations
  cannot catch this — Swift's type system doesn't enforce it,
  SwiftData doesn't either, and CloudKit only enforces it when
  the CloudKit-backed container mounts.

### `SettingsLink` is macOS-only on iOS-targeted SwiftUI

- **What happened**: plan called for `SettingsLink` to deep-link
  into iOS Settings. Build error: *"'SettingsLink' is unavailable
  in iOS"*.
- **What we did**: switched to a `Button` that opens
  `URL(string: UIApplication.openSettingsURLString)!` via
  `@Environment(\.openURL)`.
- **Lesson**: SettingsLink is a macOS-only public symbol; iOS uses
  the openSettings URL. Don't trust API names that *sound* iOS-y.

### `MainActor` default propagation kept the warnings flowing

- **What happened**: project sets `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`. Three iterations needed to silence warnings:
  `DefaultCKAccountStatusProvider` was implicitly `@MainActor`,
  poisoning its default-argument site; once marked `nonisolated`,
  it referenced `CloudContainerID.kado` which was also implicitly
  `@MainActor`; etc.
- **What we did**: marked both `nonisolated`. Pattern: types that
  cross the actor boundary (used as defaults to MainActor inits,
  consumed from background contexts) need explicit `nonisolated`
  on this codebase.
- **Lesson**: this pattern is already documented in
  [`CLAUDE.md`](../../../../CLAUDE.md) for `Codable` types. CloudKit
  providers join the same club.

### iPhone 16 Pro sim unavailable on Xcode 26 toolchain

- **What happened**: `build_sim` failed because Xcode 26 ships
  iPhone 17 family by default; `CLAUDE.md` named iPhone 16 Pro.
- **What we did**: switched defaults to iPhone 17 Pro for this
  session. CLAUDE.md update is a candidate for a follow-up.
- **Lesson**: device-default lines in `CLAUDE.md` rot fast.

### Sync isn't real-time even when both apps are foregrounded

- **What happened**: two-device verification showed habits created
  on one device take 10–30s to appear on the other. SwiftData's
  `@Query` doesn't always re-fetch when the underlying store
  receives a CloudKit pull while a view is on screen.
- **What we did**: added pull-to-refresh on `TodayView` as visual
  reassurance. Documented that the handler can't actually
  accelerate CloudKit (no public API through SwiftData).
- **Lesson**: this is Apple's documented behavior, not a bug. A
  real "Sync now" path needs `NSPersistentCloudKitContainer.eventChangedNotification`
  bridging — out of scope for v0.1.

### xcstrings auto-regenerates on build

- **What happened**: first commit after the Xcode capability work
  carried 280 lines of xcstrings deltas Xcode added during build —
  unrelated to CloudKit.
- **What we did**: split into a `chore(i18n):` catch-up commit so
  the CloudKit history stays focused.
- **Lesson**: anytime an Xcode IDE build runs against a long-
  unbuilt branch, expect xcstrings churn. Split it.

## What worked well

- **Schema introspection as a regression test.** Pinning
  CloudKit's runtime rules via `Schema.Entity.Relationship.isOptional`
  / `Schema.Entity.Attribute.isUnique` would have caught the bug
  in CI. It took 4 small tests.
- **Splitting the schema fix into its own commit before Task 2.**
  The `fix(schema):` commit stands alone, the `feat(cloudkit):` Task
  2 commit stays minimal, and `git blame` on either remains useful.
- **Profile-based simulator defaults** (`iphone` + `ipad`) made
  the two-device verification frictionless — `session_use_defaults_profile`
  flipped the active target without re-typing IDs.
- **`MockCloudAccountStatusObserver` in `Preview Content/`** rather
  than `KadoTests/Mocks/` — both production previews and tests
  consume it, and it ships only in Debug.

## For the next person

- **`HabitRecord.completions` is `[CompletionRecord]?`, not
  `[CompletionRecord]`.** Coalesce with `?? []` or `?.` at every
  call site. Don't "fix" it back to non-optional — CloudKit will
  reject the schema at first launch.
- **`CloudContainerID.kado` is the single source of truth.** It
  appears in the entitlements file, in `ModelConfiguration`, and
  in `DefaultCKAccountStatusProvider`. If you add a new touch
  point, reference the constant.
- **Schema is on CloudKit Development.** Before TestFlight or App
  Store submission, *Deploy Schema Changes* in CloudKit Console.
  This is a v1.0 release-prep step, not a code task.
- **No in-app sync toggle, by design.** See research.md §"Why no
  in-app toggle" for the rationale before adding one.
- **Pull-to-refresh on Today is cosmetic.** It rebinds the
  `@Query` and adds a 1-second sleep. Don't promise users "force
  sync now" — there is no such API through SwiftData.
- **The `@Entry` macro is the path** for any future environment
  value backed by an `@MainActor`-isolated reference type.

## Generalizable lessons

- **[→ CLAUDE.md]** SwiftData + CloudKit: every relationship must
  be optional on **both** sides. The canonical regression-guard
  pattern is `Schema.Entity.Relationship.isOptional` introspection
  — see `KadoTests/CloudKitShapeTests.swift`.
- **[→ CLAUDE.md]** Default Xcode simulator should be **iPhone 17
  Pro** on the current toolchain (iPhone 16 Pro was dropped).
- **[→ CLAUDE.md]** Use the `@Entry` macro, not hand-rolled
  `EnvironmentKey`, when the value is backed by a `@MainActor`-
  isolated reference type.
- **[→ CLAUDE.md]** Types that cross actor boundaries — used as
  defaults to MainActor inits, consumed from background tasks —
  need explicit `nonisolated` on this codebase. Already documented
  for `Codable` types; same applies to providers and constants.
- **[→ ROADMAP.md, post-v0.1]** Live sync indicator and "Sync now"
  via `NSPersistentCloudKitContainer.eventChangedNotification`.
  v0.2 candidate.
- **[local]** Pull-to-refresh on Today is cosmetic; CloudKit
  cannot be force-pulled through SwiftData.

## Metrics

- Tasks planned: 8 (Task 8 = manual verification, completed by user)
- Tasks added mid-build: 2 (`fix(schema)`, `feat(today)` pull-to-refresh)
- Tests added: 11 (4 shape invariants + 7 account-status mappings)
- Total test count: 117 (was 106)
- Commits on PR: 13 (incl. merge with main)
- Files touched: 16 (Swift) + 3 (config/docs)

## References

- Apple — [Syncing model data across a user's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-users-devices)
- Apple — [`Schema.Entity.Relationship`](https://developer.apple.com/documentation/swiftdata/schema/relationship)
- Apple — [`@Entry` macro](https://developer.apple.com/documentation/swiftui/entry)
- Apple — [`UIApplication.openSettingsURLString`](https://developer.apple.com/documentation/uikit/uiapplication/1623042-opensettingsurlstring)
- Fatbobman — [Rules for Adapting Data Models to CloudKit](https://fatbobman.com/en/snippet/rules-for-adapting-data-models-to-cloudkit/)
  (still recommended reading; the relationship-optional rule is
  the one to read carefully)
