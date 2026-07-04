# Research — Tip Jar (IAP)

**Date**: 2026-07-04
**Status**: draft — ready for plan
**Related**: `docs/ROADMAP.md` → Monetization ("Tip Jar (consumable or
non-consumable IAP) without RevenueCat"), `docs/PRODUCT.md` → Business
model ("Tip Jar: for those who want to support without needing Pro").

## Problem

Kadō is free, open source, and privacy-first with **no subscription and
no telemetry**. Some users want to support the author directly. Today
there is no in-app path to do so — Settings offers only *Rate* and *Send
Feedback* (`SupportSection.swift`).

We want a **Tip Jar**: a warm, no-pressure way to leave a monetary tip
via in-app purchase. It must:

- Add **zero third-party dependencies** — native StoreKit 2 only, no
  RevenueCat (honors the roadmap constraint and the privacy DNA).
- Never gate features. Tipping unlocks *nothing* functional; a
  non-tipping user keeps a 100% complete app. This is support, not Pro.
- Feel gracious and on-brand (the calm "稼働 / in operation" tone),
  with a genuine thank-you after purchase.

"Done" from the user's view: Settings → **Support Kadō** opens a screen
with heartfelt copy and three tip buttons; tapping one runs the system
purchase sheet; on success they see a warm thank-you; they can tip again
any number of times.

## Decisions locked with the user (2026-07-04)

- **IAP type: Consumable.** Repeatable tips, no *Restore Purchases*
  needed, no "already purchased" state. Standard tip-jar pattern
  (Overcast, Streaks).
- **3 tiers at $2.99 / $4.99 / $9.99.** (Tier 1 = "Nice" price point 4,
  Tier ~5 = 7, Tier ~10 = 10 in App Store Connect's price matrix — exact
  mapping confirmed at product-creation time.)
- **Placement: dedicated screen**, pushed from a Settings row, with room
  for warm copy + a post-tip thank-you state.

## Decisions locked (2026-07-04, follow-up)

- **Product IDs**: `dev.scastiel.kado.tip.small` / `.medium` / `.large`
  ($2.99 / $4.99 / $9.99). Readable, tier order obvious; a future reprice
  won't make the ID lie.
- **Tier labels: coffee-shop metaphor** — ☕ **Coffee** / 🥐 **Croissant**
  / 🍽️ **Lunch**. Universally understood, translates cleanly to FR
  (café / croissant / déjeuner — croissant + café are already French).
  Emoji are decorative; StoreKit `displayPrice` carries the amount.
- **Thank-you: calm inline swap.** On success the tier buttons fade to a
  heartfelt message (ありがとう / "Thank you — truly. Your support keeps
  Kadō free and independent."). No confetti/animation — matches the
  "稼働 / in operation" tone. (Still honor `reduceMotion` for the fade.)
- **Entry point: its own `TipJarSection`** in Settings ("Support Kadō"
  section, ♡ *Leave a tip* row), separate from the Feedback section, so
  tipping carries its own visual weight.

## Current state of the codebase

- **No StoreKit anywhere.** No `.storekit` config file, no
  `import StoreKit`, no IAP entitlement usage. IAP needs *no* entitlement
  file entry — it is enabled by adding the **In-App Purchase capability**
  to the app target in Xcode (a manual project-config step) and creating
  the products in **App Store Connect**. Flag both as human steps.
- **Settings** (`Kado/Views/Settings/SettingsView.swift`) is a `Form` of
  sections: `SyncStatusSection`, `NotificationsSection`, `BackupSection`,
  `SupportSection`, `DevModeSection`, wordmark footer. The tip-jar entry
  point is a new row — cleanest as its own `TipJarSection` (or a row
  appended to `SupportSection`) that `NavigationLink`s to the new screen.
- **DI pattern** (`Kado/App/EnvironmentValues+Services.swift`): protocol
  + default impl, injected via `Environment`. `@MainActor`-isolated
  `@Observable` services use the **`@Entry`** macro (see
  `cloudAccountStatus`, `reviewPromptService`). A StoreKit store is
  MainActor + observable → use `@Entry`, with a **mock default** so
  previews/tests never touch the real StoreKit.
- **Preview/mock convention**: Debug-only mocks live in `Preview
  Content/` (e.g. `MockCloudAccountStatusObserver`,
  `MockNotificationScheduler`). We add a `MockTipJarStore` there.
- **Localization**: every user-facing string goes through the
  `.xcstrings` catalog; new keys must be hand-authored with a `comment`
  and FR translations (`tu`, feminine agreement). `LocalizationCoverageTests`
  fails if any key lacks FR. Tip-jar copy is prominent user-facing text →
  needs careful native FR, not machine translation.
- **Design tokens**: `Color.kadoBackground`, `Color.kadoForegroundTertiary`,
  accent tint — reuse, no new palette constants.

## Proposed approach

Native **StoreKit 2** (`Product`, `Product.PurchaseResult`,
`Transaction`), wrapped in an injected, observable service.

### Key components

- **`TipProduct` (domain enum, KadoCore)** — case-only enum of the three
  tiers mapping to product IDs, e.g.
  `dev.scastiel.kado.tip.small/.medium/.large`. Holds display order and a
  fallback emoji/label. Pure, `nonisolated`, unit-testable.
- **`TipJarStore` protocol + `DefaultTipJarStore` (`@MainActor @Observable`)**
  — the service. Responsibilities:
  - Load `Product`s for the three IDs via `Product.products(for:)`.
  - Expose loaded products (with **localized `displayPrice`** — never
    hardcode "$2.99"; StoreKit gives the storefront-correct string).
  - `purchase(_:)` → runs `product.purchase()`, verifies the
    `Transaction` (`checkVerified`), **`await transaction.finish()`**
    (mandatory for consumables or the sheet re-prompts), returns a
    result the view maps to the thank-you / cancelled / failed states.
  - A `state` enum: `.loading / .loaded([Product]) / .failed(Error)`
    (per CLAUDE.md's enum-over-booleans rule).
  - Because tips are consumable and unlock nothing, **no receipt
    persistence, no entitlement tracking, no `Transaction.currentEntitlements`
    sweep** — just finish the transaction. This keeps it tiny.
- **`TipJarView`** — the dedicated screen: warm intro copy, a "why tips"
  blurb, three tier buttons showing StoreKit `displayPrice`, a purchase
  progress state, and a post-purchase thank-you (e.g. a gentle overlay /
  section swap). Handles `.loading` (redacted placeholders) and `.failed`
  (retry) states.
- **`TipJarSection`** (or a row in `SupportSection`) — Settings entry
  point `NavigationLink` → `TipJarView`.
- **`Tips.storekit`** config file + a **StoreKit testing** scheme option
  so we can build/run/screenshot the purchase flow in the simulator
  without App Store Connect being live.

### Data model changes

**None.** No SwiftData `@Model` changes, no migration, no schema bump.
Consumable tips persist nothing locally. (This keeps the feature entirely
off the schema-bump checklist — a nice property.)

### UI changes

- New `TipJarView` (dedicated screen).
- New Settings row/section linking to it.
- Post-tip thank-you state within `TipJarView`.
- Rich previews: `.loading`, `.loaded`, `.failed`, post-tip, plus a
  `Dark` preview per CLAUDE.md.

### Tests to write

Business logic is thin but the verification/finish path deserves tests
against a fake StoreKit boundary (protocol-injected, no live StoreKit):

- `@Test("TipProduct exposes exactly three tiers in ascending order")`
- `@Test("Store starts in .loading before products resolve")`
- `@Test("Successful verified purchase finishes the transaction and
  yields .thankYou")`
- `@Test("User cancellation yields .cancelled and does not finish")`
- `@Test("Unverified transaction is treated as failure, not success")`
- `@Test("Failed product load surfaces .failed state")`
- Localization: new keys present in FR (covered by the existing
  `LocalizationCoverageTests` sweep).

UI/visual: simulator run against `Tips.storekit`, screenshot the loaded
screen + thank-you state (light + dark), VoiceOver labels on tip buttons.

## Alternatives considered

### Alternative A: Non-consumable "supporter unlock" tiers
- Idea: each tier buyable once; acts like a badge.
- Why not: user chose consumable — repeatable support is the goal, and it
  avoids a *Restore Purchases* button + "already purchased" dead-ends.

### Alternative B: Inline tip buttons in `SupportSection`
- Idea: no navigation; buttons sit in the Feedback section.
- Why not: user chose a dedicated screen — leaves room for the warm copy
  and a proper thank-you moment, which is the emotional point of a tip jar.

### Alternative C: External link (Buy Me a Coffee / GitHub Sponsors)
- Idea: skip IAP entirely, link out.
- Why not: worse UX, and Apple's guidelines forbid steering to external
  purchase for digital "support" from inside the app. Native IAP is the
  compliant, frictionless path. (Also fails the "no network beyond
  CloudKit/HealthKit" spirit — a browser hand-off is jarring.)

## Risks and unknowns

- **Manual project config**: In-App Purchase capability on the target +
  three products in App Store Connect are human steps XcodeBuildMCP can't
  do. Build/test in the sim uses a local `Tips.storekit` file; production
  needs the ASC products live and in "Ready to Submit". Flag in PR "Next
  steps".
- **Consumable + finish()**: forgetting `transaction.finish()` makes the
  system re-surface the purchase and can wedge the StoreKit test session.
  Explicitly covered by a test.
- **App Review**: tip jars are allowed but Review sometimes wants the
  purchase reachable and functional in the build — the `Tips.storekit`
  sim flow + a real sandbox test before submit mitigate this.
- **Guideline 3.1.1**: copy must not imply tips unlock features or
  content. Keep wording purely gratitude-based.
- **No `Math.random`/pricing math in code**: always render StoreKit's
  `displayPrice`; never hardcode currency — protects against wrong
  storefront prices.

## Open questions

_All resolved 2026-07-04 — see "Decisions locked (follow-up)" above._

- [x] Product IDs → `dev.scastiel.kado.tip.small|medium|large`.
- [x] Tier labels → coffee-shop metaphor (☕ Coffee / 🥐 Croissant / 🍽️ Lunch).
- [x] Thank-you treatment → calm inline swap (no celebratory animation).
- [x] Entry point → own `TipJarSection` ("Support Kadō").

## References

- Apple — Meet StoreKit 2 (WWDC21) / `Product`, `Transaction` docs:
  https://developer.apple.com/documentation/storekit/in-app_purchase
- Apple — Testing IAP with StoreKit configuration files:
  https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-storekit-configuration-files-in-xcode
- App Store Review Guidelines 3.1.1 (in-app purchase) & tip-jar allowance.
- Prior art in-tree: `EnvironmentValues+Services.swift` (`@Entry` service
  pattern), `SupportSection.swift` (Settings row pattern),
  `MockNotificationScheduler` (Debug mock convention).
