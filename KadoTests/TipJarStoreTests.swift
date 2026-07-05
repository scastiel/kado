import Testing
@testable import Kado
@testable import KadoCore

@MainActor
struct TipJarStoreTests {
    @Test("MockTipJarStore resolves to its configured load result")
    func loadResolvesToLoaded() async {
        let store = MockTipJarStore(
            initialState: .loading,
            loadResult: .loaded(MockTipJarStore.sampleTiers)
        )

        if case .loading = store.state {} else {
            Issue.record("expected to start in .loading")
        }

        await store.load()

        guard case .loaded(let tiers) = store.state else {
            Issue.record("expected .loaded after load()")
            return
        }
        #expect(tiers.map(\.product) == TipProduct.orderedTiers)
    }

    @Test("MockTipJarStore surfaces a configured load failure")
    func loadCanFail() async {
        let store = MockTipJarStore(initialState: .loading, loadResult: .failed)
        await store.load()
        if case .failed = store.state {} else {
            Issue.record("expected .failed after load()")
        }
    }

    @Test("MockTipJarStore returns the scripted purchase outcome and records the tier")
    func purchaseReturnsScriptedOutcome() async {
        let store = MockTipJarStore(purchaseOutcome: .cancelled)
        let outcome = await store.purchase(.medium)
        #expect(outcome == .cancelled)
        #expect(store.purchasedTiers == [.medium])
    }

    @Test("Sample tiers cover all three products with non-empty prices")
    func sampleTiersWellFormed() {
        #expect(MockTipJarStore.sampleTiers.map(\.product) == TipProduct.orderedTiers)
        for tier in MockTipJarStore.sampleTiers {
            #expect(!tier.displayPrice.isEmpty)
            #expect(!tier.emoji.isEmpty)
        }
    }
}
