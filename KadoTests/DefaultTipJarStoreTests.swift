import Testing
@testable import Kado
@testable import KadoCore

/// Unit coverage for the pure tier-assembly logic in `DefaultTipJarStore`.
/// The StoreKit calls themselves (`Product.products`, `purchase`,
/// `finish`) are exercised manually against `Tips.storekit` in the
/// simulator + a device sandbox before shipping — `Product` can't be
/// constructed in a unit test.
struct DefaultTipJarStoreTests {
    @Test("All three products resolve to ordered tiers")
    func fullResolutionIsOrdered() {
        let resolved: [TipProduct: (name: String, price: String)] = [
            .large: ("Lunch", "$9.99"),
            .small: ("Coffee", "$2.99"),
            .medium: ("Croissant", "$4.99"),
        ]
        let tiers = DefaultTipJarStore.tiers(from: resolved)
        #expect(tiers.map(\.product) == [.small, .medium, .large])
        #expect(tiers.map(\.displayPrice) == ["$2.99", "$4.99", "$9.99"])
        #expect(tiers.map(\.displayName) == ["Coffee", "Croissant", "Lunch"])
    }

    @Test("A missing product is dropped, order preserved")
    func partialResolutionDropsMissing() {
        let resolved: [TipProduct: (name: String, price: String)] = [
            .small: ("Coffee", "$2.99"),
            .large: ("Lunch", "$9.99"),
        ]
        let tiers = DefaultTipJarStore.tiers(from: resolved)
        #expect(tiers.map(\.product) == [.small, .large])
    }

    @Test("No resolved products yields an empty tier list")
    func emptyResolutionIsEmpty() {
        let tiers = DefaultTipJarStore.tiers(from: [:])
        #expect(tiers.isEmpty)
    }
}
