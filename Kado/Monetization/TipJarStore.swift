import Observation
import KadoCore

/// A single loaded tip tier, ready to display. Combines our decorative
/// ``TipProduct`` (emoji, stable identity) with StoreKit's localized
/// `displayName` and `displayPrice` — the price string is always the
/// storefront-correct one from StoreKit, never hardcoded.
nonisolated struct TipTier: Identifiable, Hashable, Sendable {
    let product: TipProduct
    /// StoreKit `Product.displayName`, sourced from the `.storekit`
    /// config in the simulator and App Store Connect in production.
    let displayName: String
    /// StoreKit `Product.displayPrice`, already localized to the user's
    /// storefront currency and formatting.
    let displayPrice: String

    var id: String { product.productID }
    var emoji: String { product.emoji }
}

/// View state for the Tip Jar, per CLAUDE.md's enum-over-booleans rule.
nonisolated enum TipJarState: Sendable {
    case loading
    case loaded([TipTier])
    /// Products couldn't be fetched (offline, StoreKit unavailable, or
    /// the products aren't configured yet). The view offers a retry.
    case failed
}

/// The outcome of a single purchase attempt, mapped from StoreKit's
/// `Product.PurchaseResult` + transaction verification.
nonisolated enum TipPurchaseOutcome: Sendable, Equatable {
    /// A verified transaction completed and was finished. Show the
    /// thank-you.
    case success
    /// The user dismissed the purchase sheet. Silent — no error UI.
    case cancelled
    /// Awaiting external approval (e.g. Ask to Buy). No thank-you yet.
    case pending
    /// The purchase failed or the transaction couldn't be verified.
    case failed
}

/// Loads the tip products and runs purchases. `@Observable` so SwiftUI
/// re-renders as ``state`` moves through loading → loaded/failed.
///
/// The real implementation, ``DefaultTipJarStore``, wraps StoreKit 2.
/// Previews and tests use `MockTipJarStore` to drive each state and
/// outcome deterministically without touching StoreKit.
@MainActor
protocol TipJarStoring: AnyObject, Observable {
    var state: TipJarState { get }

    /// Fetch the three tip products. Moves ``state`` to `.loaded` on
    /// success or `.failed` on error. Safe to call again for retry.
    func load() async

    /// Run the system purchase flow for a tier. On a verified success
    /// the transaction is finished (mandatory for consumables) before
    /// returning `.success`.
    func purchase(_ tier: TipProduct) async -> TipPurchaseOutcome
}
