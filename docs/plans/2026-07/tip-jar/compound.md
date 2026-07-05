# Compound — Tip Jar (IAP)

**Date**: 2026-07-04
**Status**: complete
**Research**: [research.md](./research.md)
**Plan**: [plan.md](./plan.md) · **Manual steps**: [manual-steps.md](./manual-steps.md)
**Branch / PR**: `feature/tip-jar` → [#56](https://github.com/scastiel/kado/pull/56)

## Summary

Shipped a native StoreKit 2 Tip Jar: Settings → Support Kadō → a
dedicated screen with three consumable tips (Coffee/Croissant/Lunch) and
a calm inline thank-you. Zero third-party deps, no SwiftData schema
change, no CloudKit surface. The build closely followed the plan; the
headline lessons came from the **code-review pass** (real StoreKit
consumable-finish and SwiftUI-race bugs) and from **Xcode silently
materializing a broken shared scheme** when the StoreKit config was
attached.

## Decisions made

- **Native StoreKit 2, consumable, 3 tiers**: matches the roadmap
  ("without RevenueCat") and the "unlocks nothing" principle.
- **Store types in the app target, not KadoCore**: the KadoCore-sharing
  rule only matters for `@Model` types; these are plain value types with
  no cross-target consumer, so they follow the `CloudAccountStatusObserving`
  precedent. Only `TipProduct` (pure domain enum) lives in KadoCore.
- **Tier name/price come from StoreKit `displayName`/`displayPrice`**,
  never hardcoded — so no catalog entries for tier names and always the
  correct storefront currency.
- **`kadoBackground`-on-`kadoAccent` for the price pill**, not
  `Color.white`: `kadoAccent` flips to a *light* sage in dark mode, so
  white-on-accent fails contrast; `kadoBackground` flips inversely.
- **Scheme StoreKit wiring left as a manual Xcode step**: the project had
  no persisted scheme, and hand-authoring one for a config reference was
  fragile. (Xcode later created it for real — see surprises.)

## Surprises and how we handled them

### Code review found real StoreKit/SwiftUI bugs in "done" code
- **What happened**: after build + 362 green tests + screenshots, a
  recall-biased review surfaced 8 real issues: unverified transactions
  never `finish()`ed (redelivery loop), a double-tap purchase race
  (`purchasingTier` set async, so `.disabled` lagged the tap), an
  invisible purchase spinner (`ProgressView` ignores `.foregroundStyle`;
  it follows `.tint`), a skeleton flash + refetch on every entry
  (`load()` unconditionally resets to `.loading`), and a cancelled-load
  mapped to `.failed`.
- **What we did**: fixed all of them; collapsed the 3-field notice state
  into an enum; reused the real row under `.redacted` for the skeleton.
- **Lesson**: green tests + a screenshot don't catch StoreKit lifecycle
  bugs or SwiftUI timing races — those live below the unit-test line and
  above the pixel line. The review pass earned its keep.

### Xcode materialized a shared scheme with an empty TestAction
- **What happened**: attaching `Tips.storekit` in Edit Scheme made Xcode
  persist `xcshareddata/xcschemes/Kado.xcscheme` — previously the project
  relied on an *autocreated* scheme. The persisted one had an **empty
  `<TestAction>`**, so `xcodebuild test` failed with "Scheme Kado is not
  currently configured for the test action."
- **What we did**: added the missing `<Testables>` entry (KadoTests
  blueprint id from the pbxproj) and committed the shared schemes +
  StoreKit framework link + `Tips.storekit` file reference so the setup
  is reproducible.
- **Lesson**: the first time anyone edits a scheme in a project that
  relied on autocreation, Xcode may persist a scheme that drops the test
  action. If tests suddenly "aren't configured," check for a new
  `xcshareddata` scheme and its `<Testables>`.

### `MockTipJarStore` is Debug-only — can't back a production skeleton
- **What happened**: the obvious way to render the loading skeleton was
  `MockTipJarStore.sampleTiers`, but that lives in `Preview Content/`
  (Debug only) and would break release.
- **What we did**: added a `private static let placeholderTiers` in the
  view itself.
- **Lesson**: anything referenced from shipping code can't come from
  `Preview Content/`.

## What worked well

- **Building the view against the mock first** (Task 2 before Task 3)
  meant the whole screen was previewable/screenshot-able before any
  StoreKit wiring existed.
- **Extracting `tiers(from:)` as a pure `nonisolated static`** gave real
  unit coverage of the only non-trivial store logic without needing a
  constructible `Product`.
- **Temp-root screenshots** (pointing `ContentView` at `TipJarView`,
  reverted) got real light/dark/loaded/skeleton/thank-you pixels despite
  no `idb` for in-sim navigation.

## For the next person

- **Tips unlock nothing** — there is deliberately no entitlement
  tracking, no restore. The only StoreKit obligation is to `finish()`
  every transaction (verified *and* unverified), which the purchase path
  and the `Transaction.updates` listener both now do. The listener is
  filtered to `TipProduct` ids — keep that filter if you add other IAPs.
- **Local testing needs the scheme's StoreKit config** (`Tips.storekit`),
  which only Xcode reads — `simctl`/`build_run_sim` launches show the
  `.failed` state because no products resolve. That empty state is
  correct, not a bug.
- **Product IDs are permanent** and must match App Store Connect exactly:
  `dev.scastiel.kado.tip.{small,medium,large}`.
- Shipping still needs the App Store Connect products + a device sandbox
  test — see `manual-steps.md`.

## Generalizable lessons

- **[→ CLAUDE.md]** `ProgressView`'s indeterminate indicator takes its
  color from `.tint`, **not** `.foregroundStyle`/`.foregroundColor` — a
  spinner on a tinted fill needs `.tint(...)` or it renders in the
  inherited accent and can vanish.
- **[→ CLAUDE.md]** For a SwiftUI control whose `.disabled` guard depends
  on state set inside an async action, set that state **synchronously in
  the action** before spawning the `Task` — otherwise a fast double-tap
  fires twice before the re-render.
- **[→ CLAUDE.md]** When a StoreKit config is first attached to a scheme,
  Xcode may persist a shared scheme with an empty `<TestAction>`, breaking
  `xcodebuild test`. Commit the shared scheme with a `<Testables>` entry.
- **[local]** `kadoAccent` flips light/dark; text on an accent fill
  should use `kadoBackground` (inverse-flipping), not `Color.white`.

## Metrics

- Tasks completed: 7 of 7 (+ 3 review-driven follow-up fixes)
- Tests added: 12 (`TipProductTests` 5, `TipJarStoreTests` 4,
  `DefaultTipJarStoreTests` 3); full suite 362 green
- Commits: 12
- Files touched: 21 (~1,970 insertions)
- Schema/CloudKit changes: none

## References

- Apple — StoreKit 2 `Product`/`Transaction`, testing with `.storekit`
  configuration files.
- In-tree precedents: `EnvironmentValues+Services.swift` (`@Entry` DI),
  `CloudAccountStatusObserving` (app-target `@Observable` protocol),
  `MockNotificationScheduler` (Debug mock convention).
