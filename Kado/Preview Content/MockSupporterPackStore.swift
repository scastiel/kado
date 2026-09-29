import Observation
import KadoCore

/// Test-/preview-only ``SupporterPackStoring``. Never touches StoreKit,
/// so previews never show the system purchase sheet.
///
/// Lives in `Preview Content/` and serves as the `@Entry` default for
/// `\.supporterPack`; the real `DefaultSupporterPackStore` is injected
/// at scene build.
@MainActor
@Observable
final class MockSupporterPackStore: SupporterPackStoring {
    var isSupporter: Bool
    private(set) var offerState: SupporterOfferState

    /// The state `loadOffer()` resolves to.
    var loadResult: SupporterOfferState
    /// What `purchase()` returns. `.success` also makes this a supporter.
    var purchaseOutcome: SupporterPurchaseOutcome
    /// What `restore()` returns. `.restored` also makes this a supporter.
    var restoreOutcome: SupporterRestoreOutcome

    private(set) var purchaseCount = 0

    init(
        isSupporter: Bool = false,
        offerState: SupporterOfferState = .loaded(MockSupporterPackStore.sampleOffer),
        loadResult: SupporterOfferState = .loaded(MockSupporterPackStore.sampleOffer),
        purchaseOutcome: SupporterPurchaseOutcome = .success,
        restoreOutcome: SupporterRestoreOutcome = .nothingToRestore
    ) {
        self.isSupporter = isSupporter
        self.offerState = offerState
        self.loadResult = loadResult
        self.purchaseOutcome = purchaseOutcome
        self.restoreOutcome = restoreOutcome
    }

    func refreshEntitlement() async {}

    func loadOffer() async {
        offerState = loadResult
    }

    func purchase() async -> SupporterPurchaseOutcome {
        purchaseCount += 1
        if purchaseOutcome == .success { isSupporter = true }
        return purchaseOutcome
    }

    func restore() async -> SupporterRestoreOutcome {
        if restoreOutcome == .restored { isSupporter = true }
        return restoreOutcome
    }

    /// `nonisolated` because it's a default-argument expression in
    /// `init` — see CLAUDE.md.
    nonisolated static let sampleOffer = SupporterOffer(displayName: "Supporter pack", displayPrice: "$7.99")
}
