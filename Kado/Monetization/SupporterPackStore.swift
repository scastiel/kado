import Observation
import KadoCore

/// The Supporter pack as StoreKit sells it: its localized name and
/// storefront-correct price, never hardcoded.
nonisolated struct SupporterOffer: Hashable, Sendable {
    let displayName: String
    let displayPrice: String
}

/// Loading state of the pack's product, for the buy button.
nonisolated enum SupporterOfferState: Sendable, Equatable {
    case loading
    case loaded(SupporterOffer)
    /// The product couldn't be fetched (offline, or not configured yet).
    /// The view offers a retry; ownership is unaffected.
    case failed
}

/// The outcome of one purchase attempt.
nonisolated enum SupporterPurchaseOutcome: Sendable, Equatable {
    /// A verified transaction completed; ``SupporterPackStoring/isSupporter``
    /// is now `true`.
    case success
    /// The user dismissed the purchase sheet. Silent.
    case cancelled
    /// Awaiting external approval (Ask to Buy). It lands later through
    /// `Transaction.updates`.
    case pending
    case failed
}

/// The outcome of a "Restore purchases" tap.
nonisolated enum SupporterRestoreOutcome: Sendable, Equatable {
    case restored
    /// The sync worked, and this Apple Account has no pack to restore.
    case nothingToRestore
    /// The user dismissed the App Store sign-in. Silent.
    case cancelled
    case failed
}

/// Owns the answer to "does this device have the Supporter pack", and
/// runs its purchase and restore.
///
/// ``isSupporter`` is what views gate on. The real implementation,
/// ``DefaultSupporterPackStore``, seeds it from the App Group mirror
/// (so a relaunch doesn't flash locks while StoreKit answers), then
/// keeps it live from `Transaction.currentEntitlements` and
/// `Transaction.updates` — which is how a refund takes effect.
/// Previews and tests use `MockSupporterPackStore`.
@MainActor
protocol SupporterPackStoring: AnyObject, Observable {
    var isSupporter: Bool { get }
    var offerState: SupporterOfferState { get }

    /// Re-read ownership from StoreKit's current entitlements.
    func refreshEntitlement() async

    /// Fetch the pack's product for the buy button. Safe to call again
    /// for retry.
    func loadOffer() async

    func purchase() async -> SupporterPurchaseOutcome

    /// Sync with the App Store (may prompt for the Apple Account
    /// password) and re-read ownership.
    func restore() async -> SupporterRestoreOutcome
}
