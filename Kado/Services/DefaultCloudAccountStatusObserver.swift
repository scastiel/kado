import CloudKit
import Foundation
import Observation
import KadoCore

/// Thin protocol around `CKContainer.accountStatus()` so the observer
/// can be unit-tested without hitting CloudKit. Not MainActor-isolated
/// — the async call has no reason to hop actors, and leaving it
/// nonisolated lets the default parameter in `DefaultCloudAccountStatusObserver.init`
/// evaluate outside MainActor context.
protocol CKAccountStatusProviding: Sendable {
    func accountStatus() async throws -> CKAccountStatus
}

/// Production provider wrapping the real CloudKit container keyed by
/// `CloudContainerID.kado`. Shares the container reference across
/// calls so CloudKit's internal caching applies.
///
/// Declared `nonisolated` because the project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; without this the
/// init would inherit MainActor and the default-argument site in
/// `DefaultCloudAccountStatusObserver.init` would emit a warning.
nonisolated final class DefaultCKAccountStatusProvider: CKAccountStatusProviding {
    private let container: CKContainer

    init(containerID: String = CloudContainerID.kado) {
        self.container = CKContainer(identifier: containerID)
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}

/// Production observer: queries the real container via the injected
/// provider, and re-queries whenever iOS posts `.CKAccountChanged`.
/// Errors from the provider collapse to `.couldNotDetermine` so the
/// UI shows a benign "Checking…" state instead of a hard failure.
@MainActor
@Observable
final class DefaultCloudAccountStatusObserver: CloudAccountStatusObserving {
    private(set) var status: CloudAccountStatus = .couldNotDetermine

    @ObservationIgnored private let provider: any CKAccountStatusProviding
    @ObservationIgnored private var observerTask: Task<Void, Never>?

    init(provider: any CKAccountStatusProviding = DefaultCKAccountStatusProvider()) {
        self.provider = provider
        self.observerTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                guard let self else { break }
                await self.refresh()
            }
        }
    }

    deinit {
        observerTask?.cancel()
    }

    func refresh() async {
        do {
            let ckStatus = try await provider.accountStatus()
            self.status = Self.map(ckStatus)
        } catch {
            self.status = .couldNotDetermine
        }
    }

    static func map(_ ckStatus: CKAccountStatus) -> CloudAccountStatus {
        switch ckStatus {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine: return .couldNotDetermine
        case .temporarilyUnavailable: return .temporarilyUnavailable
        @unknown default: return .couldNotDetermine
        }
    }
}
