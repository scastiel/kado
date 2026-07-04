# Plan — Tip Jar (IAP)

**Date**: 2026-07-04
**Status**: ready to build
**Research**: [research.md](./research.md)

## Summary

Add a **Tip Jar** so users can support the author with a repeatable,
consumable in-app purchase. Native **StoreKit 2**, zero third-party
dependencies. A new Settings → **Support Kadō** row pushes a dedicated
screen with warm copy, three tip buttons (☕ Coffee $2.99 · 🥐 Croissant
$4.99 · 🍽️ Lunch $9.99), and a calm inline thank-you on success. Tipping
unlocks nothing functional — pure gratitude, no feature gating, no
SwiftData schema change.

## Decisions locked in

- Native StoreKit 2 only, no RevenueCat.
- **Consumable** products; repeatable; no *Restore Purchases*.
- Product IDs: `dev.scastiel.kado.tip.small` / `.medium` / `.large`
  → $2.99 / $4.99 / $9.99.
- Coffee-shop tier labels: ☕ Coffee / 🥐 Croissant / 🍽️ Lunch.
- Dedicated screen from an own `TipJarSection` ("Support Kadō").
- Calm inline thank-you swap (honors `reduceMotion`); no confetti.
- No `@Model` change, no migration, no schema bump.
- View never imports StoreKit — the store exposes view-friendly types so
  the UI stays testable and StoreKit-free.

## Architecture at a glance

```
TipProduct (enum, KadoCore)      — pure: the 3 tiers + IDs + label/emoji
TipJarState (enum)               — .loading / .loaded([TipTier]) / .failed
TipTier (struct)                 — TipProduct + StoreKit displayPrice
TipPurchaseOutcome (enum)        — .success / .cancelled / .pending / .failed
TipJarStore (protocol)           — load() / purchase(_:) / state
 ├ DefaultTipJarStore  (@MainActor @Observable, wraps StoreKit 2)
 └ MockTipJarStore     (Debug, Preview Content — drives previews & UI)
TipJarView                       — dedicated screen, all states + thank-you
TipJarSection                    — Settings row → NavigationLink
Tips.storekit                    — local StoreKit config for sim testing
```

## Task list

### Task 1: `TipProduct` domain enum + tests ✅

**Goal**: Define the three tiers as a pure, testable enum in KadoCore.

**Changes**:
- `Packages/KadoCore/Sources/KadoCore/Monetization/TipProduct.swift` —
  `nonisolated enum TipProduct: String, CaseIterable` with cases
  `.small/.medium/.large`; `rawValue` = full product ID; `orderedTiers`
  (ascending); `emoji` and `labelKey` (label emoji ☕/🥐/🍽️; localized
  name key). Keep display strings as `LocalizedStringResource`/keys, not
  literals baked here.
- `KadoTests/TipProductTests.swift`.

**Tests / verification**:
- `@Test("TipProduct has exactly three tiers, ascending")` — order small→large.
- `@Test("Each tier maps to its reverse-DNS product ID")`.
- `@Test("productID(from:) round-trips every case")`.

**Commit**: `feat(tip-jar): add TipProduct tier enum`

---

### Task 2: Store protocol + view-model types + Mock ✅

**Goal**: Establish the injected boundary and the Debug mock, so the view
can be built and previewed before any StoreKit wiring exists.

**Changes**:
- `Packages/KadoCore/.../Monetization/TipJarStore.swift` — protocol
  `TipJarStoring` (`var state: TipJarState { get }`, `func load() async`,
  `func purchase(_:) async -> TipPurchaseOutcome`), plus `TipJarState`,
  `TipTier`, `TipPurchaseOutcome`. (Protocol + value types in KadoCore so
  the main app + previews share one type; the StoreKit impl lives in the
  app target.)
- `Kado/Preview Content/MockTipJarStore.swift` — Debug-only
  `@Observable` mock: configurable initial state + scripted purchase
  outcome (success/cancel/fail) with an artificial delay for previews.
- Register `@Entry var tipJarStore: any TipJarStoring = MockTipJarStore()`
  in `Kado/App/EnvironmentValues+Services.swift` (mock default so previews
  /tests never hit real StoreKit — same pattern as `notificationScheduler`).

**Tests / verification**:
- `@Test("MockTipJarStore drives .loaded after load()")`.
- `@Test("MockTipJarStore returns the scripted purchase outcome")`.
- Compiles; no StoreKit import yet.

**Commit**: `feat(tip-jar): add TipJarStore protocol, state types, and mock`

---

### Task 3: `DefaultTipJarStore` (StoreKit 2) ✅

**Goal**: Real StoreKit 2 implementation.

**Changes**:
- `Kado/Monetization/DefaultTipJarStore.swift` — `@MainActor @Observable
  final class DefaultTipJarStore: TipJarStoring`:
  - `load()`: `Product.products(for: TipProduct.allIDs)`, order by
    `TipProduct.orderedTiers`, build `[TipTier]` using each
    `product.displayPrice` → `.loaded`; catch → `.failed`.
  - `purchase(_:)`: look up the `Product`, `try await product.purchase()`,
    switch the `PurchaseResult`: `.success(verification)` →
    `checkVerified` → **`await transaction.finish()`** → `.success`;
    `.userCancelled` → `.cancelled`; `.pending` → `.pending`; unverified →
    `.failed`. Never leaves a consumable transaction unfinished.
  - Small pure helper `mapPurchase(...)`/`checkVerified(...)` factored so
    the verification→outcome mapping is unit-testable without a live
    `Product`.

**Tests / verification**:
- `@Test` on the `checkVerified` / outcome-mapping helper: verified →
  success, `.unverified` → failed, cancelled → cancelled, pending →
  pending.
- `StoreKitTest` `SKTestSession` integration test loading `Tips.storekit`
  and asserting `load()` reaches `.loaded` with 3 tiers **if** SKTestSession
  runs headless under `test_sim`; otherwise mark as a manual sandbox check
  and note it (don't fake a green).

**Commit**: `feat(tip-jar): implement DefaultTipJarStore with StoreKit 2`

---

### Task 4: `Tips.storekit` config + scheme wiring ✅ (wiring → manual)

**Goal**: Let the purchase flow run in the simulator with no ASC dependency.

**Changes**:
- `Tips.storekit` — three consumable products with the locked IDs and
  prices, localized display names/descriptions.
- Wire the config into the **Kado** scheme's Run + Test options
  (`StoreKitConfigurationFileReference`). This edits
  `Kado.xcodeproj/xcshareddata/xcschemes/Kado.xcscheme` — a project-file
  change; do it carefully and verify the scheme still opens.

**Tests / verification**:
- `build_sim` succeeds.
- Manual: launch in sim, the tip buttons show prices from the config.

**Commit**: `chore(tip-jar): add StoreKit config for simulator testing`

---

### Task 5: `TipJarView`

**Goal**: The dedicated screen with all states and the thank-you.

**Changes**:
- `Kado/Views/Settings/TipJarView.swift` — reads
  `@Environment(\.tipJarStore)`; on appear `await store.load()`:
  - `.loading` → redacted placeholder buttons.
  - `.loaded` → intro copy, "why tips" blurb, three tier rows
    (emoji + name + `displayPrice`), tappable → `purchase`.
  - `.failed` → gentle message + Retry.
  - Local `@State` for purchase-in-flight (disable buttons, spinner on the
    tapped tier) and a `didThankYou` flag that fades the tier list to the
    ありがとう message. `withAnimation` gated on `!reduceMotion`.
  - Semantic colors only (`Color.kadoBackground`, accent). VoiceOver:
    each button labeled "Leave a <tier> tip, <price>".
- Rich previews: `.loaded`, `.loading`, `.failed`, post-thank-you, + a
  `Dark` preview (per CLAUDE.md).

**Tests / verification**:
- Previews render all states.
- `screenshot` in sim (light + dark) after Task 6 localization lands.
- Dynamic Type XXXL: copy wraps, no clipped buttons.

**Commit**: `feat(tip-jar): add TipJarView screen`

---

### Task 6: `TipJarSection` + Settings wiring + localization

**Goal**: Surface the entry point and localize all new copy.

**Changes**:
- `Kado/Views/Settings/TipJarSection.swift` — `Section("Support Kadō")`
  with a `NavigationLink` (♡ *Leave a tip*) → `TipJarView`.
- `SettingsView.swift` — insert `TipJarSection()` (below
  `SupportSection`, above `DevModeSection`).
- `Localizable.xcstrings` — hand-author every new key (EN + FR) with
  `comment`s: section title, row label, screen title, intro copy, "why
  tips" blurb, three tier names, thank-you message, failed/retry copy,
  VoiceOver labels. FR: `tu`, feminine agreement, coffee-shop terms
  (café/croissant/déjeuner) — draft, review as native speaker, commit.

**Tests / verification**:
- `LocalizationCoverageTests` passes (no missing FR).
- Settings shows the new section; tapping pushes the screen.
- `screenshot` Settings + TipJarView, light + dark, EN + FR.

**Commit**: `feat(tip-jar): add Settings entry point and localize copy`

---

### Task 7: Verify, document manual steps, finalize

**Goal**: End-to-end verification + honest handoff of the human-only steps.

**Changes**:
- Run full `test_sim` + `build_sim` (iPhone + iPad).
- Drive the sim purchase against `Tips.storekit`: tap a tier → StoreKit
  test sheet → success → thank-you appears; tap again works (consumable).
- Add a short **"Manual steps before shipping"** note to the PR body /
  compound: (1) add **In-App Purchase capability** to the Kado target in
  Xcode; (2) create the 3 consumable products in **App Store Connect**
  with the exact IDs + prices + localized names; (3) sandbox-test on a
  device before submit; (4) ensure products are "Ready to Submit" and
  attached to the review build.

**Tests / verification**:
- All tests green; screenshots captured; manual steps written down.

**Commit**: `test(tip-jar): end-to-end sim verification` (+ doc note)

## Integration checkpoints (risk areas)

- **Project-file edits** (Task 4 scheme, plus IAP capability which is
  human-only): `.xcscheme` / `.pbxproj` changes are fragile under
  non-Xcode tooling — change minimally, verify the project still builds
  and the scheme opens. The IAP *capability* itself is flagged as a human
  step, not automated.
- **StoreKit testability**: `Product` can't be constructed in tests. Keep
  business logic in a pure mapper + rely on `MockTipJarStore` for view
  tests and `SKTestSession` (if headless-capable) or manual sandbox for
  the real path. No faked greens.
- **App Review 3.1.1**: copy stays purely gratitude-based — never implies
  tips unlock features/content. Review the final EN + FR strings against
  this before submit.
- **No schema/CloudKit/widget surface touched** — this feature is isolated
  from persistence and sync, which keeps risk low.

## Notes during build

- **Task 2**: Placed `TipJarStoring` + `TipJarState`/`TipTier`/
  `TipPurchaseOutcome` in the **app target** (`Kado/Monetization/`), not
  KadoCore. The plan's KadoCore rationale ("share one type") only matters
  for `@Model` types; these are plain value types with no cross-target
  consumer, so they follow the `CloudAccountStatusObserving` precedent
  (app-target protocol + Preview Content mock as the `@Entry` default).
  `TipProduct` stays in KadoCore (reusable pure domain enum).
- **Task 2**: `TipTier`/`TipJarState`/`TipPurchaseOutcome` marked
  `nonisolated` and `MockTipJarStore.sampleTiers` marked
  `nonisolated static` — the static is a default-argument expression
  evaluated outside MainActor (CLAUDE.md concurrency rule).
- **Task 3**: Added a `Transaction.updates` listener (not in the original
  plan) so a deferred/interrupted tip (e.g. Ask-to-Buy) still gets
  `finish()`ed on a later launch. Standard StoreKit hygiene even though
  tips unlock nothing.
- **Task 4**: The project has **no persisted scheme** (Xcode autocreates
  it), so there's nothing to edit to attach the StoreKit config, and
  hand-authoring a full shared scheme just for a config reference is
  fragile. Created + committed `Tips.storekit`; **wiring it into the
  scheme is now a manual Xcode step** (Edit Scheme → Run/Test → Options →
  StoreKit Configuration → `Tips.storekit`), grouped with the other
  human-only Xcode step (adding the In-App Purchase capability). Moved to
  Task 7's manual-steps list. The `SKTestSession` integration test the
  plan floated is therefore also deferred to manual sandbox verification.

## Open questions

_None — all resolved during research._ New ones will be logged here if
build surfaces them.

## Out of scope

- Kadō **Pro** tier / any feature gating (roadmap: wait-and-see, decide
  after 3 months).
- Restore Purchases (irrelevant for consumables).
- Lifetime-tips total / "you've tipped N times" stats or badges.
- Localizing beyond EN + FR (matches current app scope).
- HealthKit / Watch / widget surfaces.
