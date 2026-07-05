import Foundation

/// The three Tip Jar tiers.
///
/// These are **consumable** in-app purchases that let a user support
/// Kadō's development. They unlock nothing functional — the app is 100%
/// complete without ever tipping. Because they're consumable, a user can
/// tip any number of times and there is no "restore purchases" concept.
///
/// Raw values are the full reverse-DNS StoreKit product identifiers and
/// **must match App Store Connect exactly**. Identifiers are permanent
/// once a product ships, so tier order lives in ``orderedTiers`` rather
/// than being inferred from the identifier — a future reprice never makes
/// an ID lie.
///
/// The human-readable name and price are **not** defined here: they come
/// from StoreKit's localized `displayName` / `displayPrice`, sourced from
/// the `.storekit` config in the simulator and App Store Connect in
/// production. Only the decorative ``emoji`` lives in code.
nonisolated public enum TipProduct: String, CaseIterable, Sendable, Hashable {
    case small = "dev.scastiel.kado.tip.small"
    case medium = "dev.scastiel.kado.tip.medium"
    case large = "dev.scastiel.kado.tip.large"

    /// The tiers in ascending price order, for stable UI layout.
    public static var orderedTiers: [TipProduct] { [.small, .medium, .large] }

    /// Every product identifier, for a single `Product.products(for:)`
    /// StoreKit request.
    public static var allIDs: [String] { orderedTiers.map(\.rawValue) }

    /// The StoreKit product identifier.
    public var productID: String { rawValue }

    /// Decorative emoji for the tier (coffee-shop metaphor: coffee →
    /// croissant → lunch). The localized name and price come from
    /// StoreKit, never hardcoded here.
    public var emoji: String {
        switch self {
        case .small: "☕"
        case .medium: "🥐"
        case .large: "🍽️"
        }
    }

    /// Resolve a tier from a StoreKit product identifier, or `nil` if the
    /// identifier isn't one of ours.
    public init?(productID: String) {
        self.init(rawValue: productID)
    }
}
