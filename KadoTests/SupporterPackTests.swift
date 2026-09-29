import Foundation
import Testing
@testable import KadoCore

/// The pure half of the Supporter pack: its identifier, the rule that
/// decides whether StoreKit's entitlements add up to owning it, and the
/// App Group mirror the widget reads. The StoreKit calls themselves are
/// exercised by hand against `Tips.storekit` (buy, restore, refund).
@Suite("Supporter pack")
struct SupporterPackTests {
    // MARK: - Product

    @Test("The product identifier is the permanent reverse-DNS one")
    func productID() {
        #expect(SupporterPack.productID == "dev.scastiel.kado.supporter")
    }

    @Test("The pack's identifier is not one of the tips'")
    func productIDIsNotATip() {
        #expect(TipProduct(productID: SupporterPack.productID) == nil)
    }

    // MARK: - Entitlement

    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("No entitlements own nothing")
    func emptyOwnsNothing() {
        #expect(!SupporterPack.isOwned(by: []))
    }

    @Test("A verified, unrevoked pack entitlement owns the pack")
    func verifiedOwns() {
        let record = SupporterEntitlement(productID: SupporterPack.productID, isVerified: true, revocationDate: nil)
        #expect(SupporterPack.isOwned(by: [record]))
    }

    @Test("A refunded or revoked pack no longer owns it")
    func revokedDoesNotOwn() {
        let record = SupporterEntitlement(productID: SupporterPack.productID, isVerified: true, revocationDate: now)
        #expect(!SupporterPack.isOwned(by: [record]))
    }

    @Test("An unverified transaction is not believed")
    func unverifiedDoesNotOwn() {
        let record = SupporterEntitlement(productID: SupporterPack.productID, isVerified: false, revocationDate: nil)
        #expect(!SupporterPack.isOwned(by: [record]))
    }

    @Test("Another product's entitlement doesn't own the pack")
    func otherProductDoesNotOwn() {
        let records = TipProduct.allIDs.map {
            SupporterEntitlement(productID: $0, isVerified: true, revocationDate: nil)
        }
        #expect(!SupporterPack.isOwned(by: records))
    }

    @Test("One good pack entitlement is enough among bad ones")
    func anyGoodRecordOwns() {
        let records = [
            SupporterEntitlement(productID: SupporterPack.productID, isVerified: false, revocationDate: nil),
            SupporterEntitlement(productID: SupporterPack.productID, isVerified: true, revocationDate: now),
            SupporterEntitlement(productID: SupporterPack.productID, isVerified: true, revocationDate: nil),
        ]
        #expect(SupporterPack.isOwned(by: records))
    }

    // MARK: - App Group mirror

    private func makeSuite() -> (UserDefaults, String) {
        let name = "supporter-tests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test("An unset mirror reads as not a supporter")
    func unsetIsNotSupporter() {
        let (suite, name) = makeSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }

        #expect(!SupporterDefaults.isSupporter(in: suite))
    }

    @Test("The mirror round-trips both ways, so a refund clears it")
    func mirrorRoundTrips() {
        let (suite, name) = makeSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }

        SupporterDefaults.setSupporter(true, in: suite)
        #expect(SupporterDefaults.isSupporter(in: suite))
        SupporterDefaults.setSupporter(false, in: suite)
        #expect(!SupporterDefaults.isSupporter(in: suite))
    }
}

/// `effective(preferred:isSupporter:)` over a stand-in for the theme
/// and icon pickers, which adopt ``SupporterGated`` when they land
/// (#111, #113, #114). The rule is the same for all of them.
@Suite("Supporter gate")
struct SupporterGateTests {
    private enum Extra: String, CaseIterable, SupporterGated {
        case kado, classic, dusk, meadow

        var requiresSupporterPack: Bool {
            switch self {
            case .kado, .classic: false
            case .dusk, .meadow: true
            }
        }

        static let freeFallback = Extra.kado
    }

    @Test("A free choice is kept whether or not the pack is owned")
    func freeIsAlwaysKept() {
        for isSupporter in [false, true] {
            #expect(Extra.effective(preferred: .kado, isSupporter: isSupporter) == .kado)
            #expect(Extra.effective(preferred: .classic, isSupporter: isSupporter) == .classic)
        }
    }

    @Test("A supporter keeps every choice")
    func supporterKeepsEverything() {
        for extra in Extra.allCases {
            #expect(Extra.effective(preferred: extra, isSupporter: true) == extra)
        }
    }

    @Test("A revoked purchase falls back to the free default, for every paid choice")
    func revokedFallsBack() {
        for extra in Extra.allCases where extra.requiresSupporterPack {
            #expect(Extra.effective(preferred: extra, isSupporter: false) == Extra.freeFallback)
        }
    }

    @Test("Only paid choices are locked, and only without the pack")
    func lockedMatchesRequirement() {
        for extra in Extra.allCases {
            #expect(extra.isLocked(isSupporter: true) == false)
            #expect(extra.isLocked(isSupporter: false) == extra.requiresSupporterPack)
        }
    }

    @Test("The App Group mirror drives the answer outside the app")
    func readsTheMirror() {
        let name = "supporter-gate-tests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { UserDefaults().removePersistentDomain(forName: name) }

        #expect(Extra.effective(preferred: .dusk, in: suite) == .kado)
        SupporterDefaults.setSupporter(true, in: suite)
        #expect(Extra.effective(preferred: .dusk, in: suite) == .dusk)
    }
}
