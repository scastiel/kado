import Observation
import KadoCore

/// Test-/preview-only ``TipJarStoring`` that drives every state and
/// purchase outcome deterministically. Never touches StoreKit, so
/// previews and tests never show the system purchase sheet.
///
/// Lives in `Preview Content/` so it ships only with Debug builds, and
/// serves as the `@Entry` default for `\.tipJarStore` (the real
/// `DefaultTipJarStore` is injected at scene build).
@MainActor
@Observable
final class MockTipJarStore: TipJarStoring {
    private(set) var state: TipJarState

    /// The state `load()` should resolve to. Defaults to a fully loaded
    /// three-tier jar with placeholder prices.
    var loadResult: TipJarState

    /// The outcome every `purchase(_:)` call returns.
    var purchaseOutcome: TipPurchaseOutcome

    /// Records the tiers passed to `purchase(_:)`, for test assertions.
    private(set) var purchasedTiers: [TipProduct] = []

    init(
        initialState: TipJarState = .loaded(MockTipJarStore.sampleTiers),
        loadResult: TipJarState = .loaded(MockTipJarStore.sampleTiers),
        purchaseOutcome: TipPurchaseOutcome = .success
    ) {
        self.state = initialState
        self.loadResult = loadResult
        self.purchaseOutcome = purchaseOutcome
    }

    func load() async {
        state = loadResult
    }

    func purchase(_ tier: TipProduct) async -> TipPurchaseOutcome {
        purchasedTiers.append(tier)
        return purchaseOutcome
    }

    /// Three tiers with plausible placeholder prices for previews.
    /// `nonisolated` because it's used as a default-argument expression
    /// in `init` (evaluated outside MainActor) — see CLAUDE.md.
    nonisolated static let sampleTiers: [TipTier] = [
        TipTier(product: .small, displayName: "Coffee", displayPrice: "$2.99"),
        TipTier(product: .medium, displayName: "Croissant", displayPrice: "$4.99"),
        TipTier(product: .large, displayName: "Lunch", displayPrice: "$9.99"),
    ]
}
