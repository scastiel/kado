import CloudKit
import Testing
@testable import Kado

@MainActor
struct CloudAccountStatusTests {
    private struct SeededProvider: CKAccountStatusProviding {
        let ckStatus: CKAccountStatus
        func accountStatus() async throws -> CKAccountStatus { ckStatus }
    }

    private struct FailingProvider: CKAccountStatusProviding {
        struct Boom: Error {}
        func accountStatus() async throws -> CKAccountStatus { throw Boom() }
    }

    @Test("starts in .couldNotDetermine before the first refresh")
    func initialStatus() {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .available)
        )
        #expect(observer.status == .couldNotDetermine)
    }

    @Test("maps CKAccountStatus.available to .available")
    func mapsAvailable() async {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .available)
        )
        await observer.refresh()
        #expect(observer.status == .available)
    }

    @Test("maps CKAccountStatus.noAccount to .noAccount")
    func mapsNoAccount() async {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .noAccount)
        )
        await observer.refresh()
        #expect(observer.status == .noAccount)
    }

    @Test("maps CKAccountStatus.restricted to .restricted")
    func mapsRestricted() async {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .restricted)
        )
        await observer.refresh()
        #expect(observer.status == .restricted)
    }

    @Test("maps CKAccountStatus.couldNotDetermine to .couldNotDetermine")
    func mapsCouldNotDetermine() async {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .couldNotDetermine)
        )
        await observer.refresh()
        #expect(observer.status == .couldNotDetermine)
    }

    @Test("maps CKAccountStatus.temporarilyUnavailable to .temporarilyUnavailable")
    func mapsTemporarilyUnavailable() async {
        let observer = DefaultCloudAccountStatusObserver(
            provider: SeededProvider(ckStatus: .temporarilyUnavailable)
        )
        await observer.refresh()
        #expect(observer.status == .temporarilyUnavailable)
    }

    @Test("refresh() collapses a provider error to .couldNotDetermine")
    func errorBecomesCouldNotDetermine() async {
        let observer = DefaultCloudAccountStatusObserver(provider: FailingProvider())
        await observer.refresh()
        #expect(observer.status == .couldNotDetermine)
    }
}
