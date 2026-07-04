import Testing
@testable import KadoCore

struct TipProductTests {
    @Test("Exactly three tiers, in ascending order")
    func orderedTiers() {
        #expect(TipProduct.orderedTiers == [.small, .medium, .large])
        #expect(TipProduct.allCases.count == 3)
    }

    @Test("Each tier maps to its reverse-DNS product ID")
    func productIDs() {
        #expect(TipProduct.small.productID == "dev.scastiel.kado.tip.small")
        #expect(TipProduct.medium.productID == "dev.scastiel.kado.tip.medium")
        #expect(TipProduct.large.productID == "dev.scastiel.kado.tip.large")
    }

    @Test("allIDs lists every tier's identifier in ascending order")
    func allIDs() {
        #expect(TipProduct.allIDs == [
            "dev.scastiel.kado.tip.small",
            "dev.scastiel.kado.tip.medium",
            "dev.scastiel.kado.tip.large",
        ])
    }

    @Test("init(productID:) round-trips every case and rejects unknowns")
    func roundTrip() {
        for tier in TipProduct.allCases {
            #expect(TipProduct(productID: tier.productID) == tier)
        }
        #expect(TipProduct(productID: "dev.scastiel.kado.tip.unknown") == nil)
        #expect(TipProduct(productID: "") == nil)
    }

    @Test("Every tier has a non-empty decorative emoji")
    func emoji() {
        for tier in TipProduct.allCases {
            #expect(!tier.emoji.isEmpty)
        }
    }
}
