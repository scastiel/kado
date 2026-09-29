import Foundation
import StoreKit
import Observation
import WidgetKit
import KadoCore

/// Production ``SupporterPackStoring`` backed by StoreKit 2, entirely
/// on-device: no server, no receipt validation service.
///
/// Ownership is **recomputed** from `Transaction.currentEntitlements`
/// on launch and after every transaction for the pack, rather than
/// derived from the single transaction that arrived. A refund, a
/// revocation, a Family Sharing change and a purchase on another
/// device all converge on the same re-read, so there is one rule
/// (``SupporterPack/isOwned(by:)``) and no bookkeeping to go stale.
@MainActor
@Observable
final class DefaultSupporterPackStore: SupporterPackStoring {
    private(set) var isSupporter: Bool
    private(set) var offerState: SupporterOfferState = .loading

    @ObservationIgnored private var product: Product?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = SupporterDefaults.sharedDefaults) {
        self.defaults = defaults
        // Last known answer, so a supporter's relaunch doesn't show
        // locks for the moment StoreKit takes to answer. The launch
        // `refreshEntitlement()` corrects it either way — which is
        // how a refund granted while the app was closed takes effect.
        isSupporter = SupporterDefaults.isSupporter(in: defaults)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refreshEntitlement() async {
        var entitlements: [SupporterEntitlement] = []
        for await result in Transaction.currentEntitlements {
            entitlements.append(SupporterEntitlement(result))
        }
        apply(SupporterPack.isOwned(by: entitlements))
    }

    func loadOffer() async {
        offerState = .loading
        do {
            guard let loaded = try await Product.products(for: [SupporterPack.productID]).first else {
                offerState = .failed
                return
            }
            product = loaded
            offerState = .loaded(SupporterOffer(displayName: loaded.displayName, displayPrice: loaded.displayPrice))
        } catch {
            // Left alone on cancellation (the screen went away) so the
            // next visit retries rather than showing a failure.
            if Task.isCancelled { return }
            offerState = .failed
        }
    }

    func purchase() async -> SupporterPurchaseOutcome {
        guard let product else { return .failed }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                // Finished either way, so StoreKit stops re-delivering
                // it; only a verified one is believed.
                let transaction = verification.unsafePayloadValue
                await transaction.finish()
                guard case .verified = verification else { return .failed }
                await refreshEntitlement()
                return isSupporter ? .success : .failed
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }

    func restore() async -> SupporterRestoreOutcome {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed
        }
        await refreshEntitlement()
        return isSupporter ? .restored : .nothingToRestore
    }

    /// A transaction that arrived outside `purchase()`: an Ask-to-Buy
    /// approval, a purchase made on another device, a refund. Only the
    /// pack's are touched, so the tip jar's listener still finishes its
    /// own.
    private func handle(_ update: VerificationResult<Transaction>) async {
        let transaction = update.unsafePayloadValue
        guard transaction.productID == SupporterPack.productID else { return }
        await transaction.finish()
        await refreshEntitlement()
    }

    /// Publish a new answer and mirror it into the App Group, reloading
    /// the widgets so a lapsed paid theme falls back there too.
    private func apply(_ owned: Bool) {
        if SupporterDefaults.isSupporter(in: defaults) != owned {
            SupporterDefaults.setSupporter(owned, in: defaults)
            WidgetCenter.shared.reloadAllTimelines()
        }
        if isSupporter != owned {
            isSupporter = owned
        }
    }
}

private extension SupporterEntitlement {
    init(_ result: VerificationResult<Transaction>) {
        let transaction = result.unsafePayloadValue
        let isVerified = if case .verified = result { true } else { false }
        self.init(
            productID: transaction.productID,
            isVerified: isVerified,
            revocationDate: transaction.revocationDate
        )
    }
}
