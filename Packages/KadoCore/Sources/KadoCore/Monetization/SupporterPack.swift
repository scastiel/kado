import Foundation

/// The Supporter pack: one **non-consumable** in-app purchase that
/// unlocks cosmetic extras — paid habit colour themes, alternate app
/// icons — and nothing else.
///
/// `docs/PRODUCT.md` promises no subscription, ever, and no feature
/// taken away from free after the fact, so the pack is bought once,
/// shared with Family Sharing, and never gates something that works.
/// The free Kadō and Classic themes and the default icon are never
/// behind it. What it gates goes through ``SupporterGated``.
///
/// Ownership is decided on-device from StoreKit 2's
/// `Transaction.currentEntitlements` — no server, no receipt service.
/// The app mirrors the answer into ``SupporterDefaults`` so the widget
/// extension, which has no StoreKit observer of its own, can fall back
/// the same way.
nonisolated public enum SupporterPack {
    /// The StoreKit product identifier. **Must match App Store Connect
    /// exactly** and is permanent once the product ships.
    public static let productID = "dev.scastiel.kado.supporter"

    /// Whether a set of StoreKit entitlements adds up to owning the
    /// pack: any verified, unrevoked transaction for ``productID``.
    ///
    /// `currentEntitlements` already leaves out refunded transactions,
    /// but the revocation date is checked anyway — the same rule then
    /// holds for a transaction arriving through `Transaction.updates`,
    /// where a refund shows up *as* a transaction with the date set.
    /// An unverified transaction is never believed.
    public static func isOwned(by entitlements: some Sequence<SupporterEntitlement>) -> Bool {
        entitlements.contains { entitlement in
            entitlement.productID == productID
                && entitlement.isVerified
                && entitlement.revocationDate == nil
        }
    }
}

/// What ``SupporterPack/isOwned(by:)`` needs to know about one StoreKit
/// transaction. A plain value rather than `Transaction`, which can't be
/// constructed outside StoreKit, so the ownership rule is unit-testable.
nonisolated public struct SupporterEntitlement: Hashable, Sendable {
    public let productID: String
    /// Whether StoreKit's JWS verification passed.
    public let isVerified: Bool
    /// Set when Apple refunded the purchase or revoked it (Family
    /// Sharing ended, for instance).
    public let revocationDate: Date?

    public init(productID: String, isVerified: Bool, revocationDate: Date?) {
        self.productID = productID
        self.isVerified = isVerified
        self.revocationDate = revocationDate
    }
}
