# Tip Jar — manual steps before shipping

The code is complete and verified in the simulator against a mock/
`Tips.storekit`. These steps are **human-only** (Xcode project config +
App Store Connect) and must be done before the Tip Jar works in a real
build. Nothing here is automatable via XcodeBuildMCP.

## 1. Xcode — add the In-App Purchase capability

`Kado` target → **Signing & Capabilities** → **+ Capability** →
**In-App Purchase**. (No entitlement-file entry is needed; this just
provisions the capability.)

## 2. Xcode — attach the StoreKit config to the scheme (for local testing)

The repo ships `Tips.storekit` but the project has no persisted scheme,
so the reference must be added by hand:

**Product → Scheme → Edit Scheme… → Run → Options → StoreKit
Configuration → `Tips.storekit`.** Repeat for the **Test** action if you
want purchase flows under `test_sim`.

With this set, the three tiers load and the purchase sheet works in the
simulator with no App Store Connect dependency.

## 3. App Store Connect — create the three consumable products

App Store Connect → Kadō → **In-App Purchases** → create three
**Consumable** products with these exact identifiers, prices, and
localized names (EN + FR):

| Product ID | Price (USD) | EN name | FR name |
|---|---|---|---|
| `dev.scastiel.kado.tip.small` | $2.99 | Coffee | Café |
| `dev.scastiel.kado.tip.medium` | $4.99 | Croissant | Croissant |
| `dev.scastiel.kado.tip.large` | $9.99 | Lunch | Déjeuner |

- Identifiers **must match** `TipProduct` exactly — they're permanent.
- Add a review screenshot of the Tip Jar screen and a short review note
  ("Optional tip jar; unlocks no features").
- Keep copy purely gratitude-based (Guideline 3.1.1 — tips must not imply
  any functional unlock).

## 4. Sandbox test on a device before submitting

Sign into a **Sandbox Apple ID** (Settings → Developer, or the sign-in
prompt during purchase) and run a real purchase of each tier from a
TestFlight/dev build. Confirm:

- All three tiers load with correct localized prices.
- A purchase completes and shows the thank-you.
- Tipping again works (consumables are repeatable — no "already
  purchased").
- Cancelling shows no error; the screen returns to the tiers.

## 5. Submit

Ensure the three products are **"Ready to Submit"** and attached to the
review build. Submit the app; the products are reviewed alongside it.

---

_No SwiftData schema changed, so there is **no** CloudKit schema deploy
step for this feature._
