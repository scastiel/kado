import CloudKit
import Testing
@testable import Kado

struct CloudSyncHealthTests {
    @Test("a finished event that succeeded reports healthy")
    func successIsHealthy() {
        #expect(CloudSyncEventAssessor.health(after: .unknown, succeeded: true, error: nil) == .healthy)
    }

    @Test("a succeeded event recovers from a previous failure")
    func successRecoversFromFailing() {
        #expect(CloudSyncEventAssessor.health(after: .failing, succeeded: true, error: nil) == .healthy)
    }

    @Test("a persistent CloudKit error reports failing")
    func persistentErrorIsFailing() {
        let error = CKError(.badContainer)
        #expect(CloudSyncEventAssessor.health(after: .unknown, succeeded: false, error: error) == .failing)
        #expect(CloudSyncEventAssessor.health(after: .healthy, succeeded: false, error: error) == .failing)
    }

    @Test("a partial failure (e.g. record type missing in Production) reports failing")
    func partialFailureIsFailing() {
        let error = CKError(.partialFailure)
        #expect(CloudSyncEventAssessor.health(after: .healthy, succeeded: false, error: error) == .failing)
    }

    @Test(
        "transient errors keep the previous assessment",
        arguments: [
            CKError.Code.networkUnavailable,
            .networkFailure,
            .serviceUnavailable,
            .requestRateLimited,
            .zoneBusy,
            .accountTemporarilyUnavailable,
        ]
    )
    func transientErrorKeepsCurrent(code: CKError.Code) {
        let error = CKError(code)
        #expect(CloudSyncEventAssessor.health(after: .healthy, succeeded: false, error: error) == .healthy)
        #expect(CloudSyncEventAssessor.health(after: .unknown, succeeded: false, error: error) == .unknown)
        #expect(CloudSyncEventAssessor.health(after: .failing, succeeded: false, error: error) == .failing)
    }

    @Test("a failed event with a non-CloudKit error reports failing")
    func nonCKErrorIsFailing() {
        struct Boom: Error {}
        #expect(CloudSyncEventAssessor.health(after: .healthy, succeeded: false, error: Boom()) == .failing)
    }

    @Test("a failed event with no error still reports failing")
    func nilErrorFailureIsFailing() {
        #expect(CloudSyncEventAssessor.health(after: .healthy, succeeded: false, error: nil) == .failing)
    }

    @MainActor
    @Test("observer starts with unknown sync health")
    func observerInitialSyncHealth() {
        struct SeededProvider: CKAccountStatusProviding {
            func accountStatus() async throws -> CKAccountStatus { .available }
        }
        let observer = DefaultCloudAccountStatusObserver(provider: SeededProvider())
        #expect(observer.syncHealth == .unknown)
    }
}
