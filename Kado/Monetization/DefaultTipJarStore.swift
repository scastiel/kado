import StoreKit
import Observation
import KadoCore

/// Production ``TipJarStoring`` backed by StoreKit 2.
///
/// Tips are **consumable** and unlock nothing, so there is no entitlement
/// tracking and no "restore purchases" — the only obligation is to
/// `finish()` every verified transaction (skipping this makes StoreKit
/// re-deliver the purchase and re-prompt). A background
/// `Transaction.updates` listener finishes any transaction that arrives
/// outside the purchase flow (e.g. an Ask-to-Buy approval or an
/// interrupted purchase resolved on a later launch).
@MainActor
@Observable
final class DefaultTipJarStore: TipJarStoring {
    private(set) var state: TipJarState = .loading

    /// Loaded StoreKit products, keyed by identifier, for `purchase(_:)`.
    @ObservationIgnored private var products: [String: Product] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        // Finish transactions that arrive outside a `purchase(_:)` call
        // so a deferred/interrupted tip never gets stuck unfinished.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.finishTipTransaction(update)
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func load() async {
        state = .loading
        do {
            let loaded = try await Product.products(for: TipProduct.allIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })

            let resolved: [TipProduct: (name: String, price: String)] = Dictionary(
                uniqueKeysWithValues: loaded.compactMap { product in
                    guard let tier = TipProduct(productID: product.id) else { return nil }
                    return (tier, (product.displayName, product.displayPrice))
                }
            )
            let tiers = Self.tiers(from: resolved)
            state = tiers.isEmpty ? .failed : .loaded(tiers)
        } catch {
            // A cancelled load (user navigated away mid-fetch) isn't a
            // real failure — leave state as-is so the next entry retries.
            if Task.isCancelled { return }
            state = .failed
        }
    }

    func purchase(_ tier: TipProduct) async -> TipPurchaseOutcome {
        guard let product = products[tier.productID] else { return .failed }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Mandatory for consumables — otherwise StoreKit
                    // re-delivers and re-prompts on next launch.
                    await transaction.finish()
                    return .success
                case .unverified(let transaction, _):
                    // A tip unlocks nothing, so we don't grant anything —
                    // but still finish it, or StoreKit re-delivers this
                    // unfinished consumable on every launch.
                    await transaction.finish()
                    return .failed
                }
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

    /// Finish a transaction arriving via `Transaction.updates`, whether
    /// verified or not — but only if it's one of our tip products, so a
    /// future feature's transaction isn't cleared before its owner can
    /// grant the entitlement.
    private func finishTipTransaction(_ result: VerificationResult<Transaction>) async {
        let transaction: Transaction
        switch result {
        case .verified(let value): transaction = value
        case .unverified(let value, _): transaction = value
        }
        guard TipProduct(productID: transaction.productID) != nil else { return }
        await transaction.finish()
    }

    /// Assemble the loaded products into ordered ``TipTier`` values,
    /// dropping any tier StoreKit didn't return and preserving ascending
    /// tier order regardless of the input order. Pure and `nonisolated`
    /// so it's unit-testable without constructing a StoreKit `Product`.
    nonisolated static func tiers(
        from resolved: [TipProduct: (name: String, price: String)]
    ) -> [TipTier] {
        TipProduct.orderedTiers.compactMap { tier in
            guard let info = resolved[tier] else { return nil }
            return TipTier(product: tier, displayName: info.name, displayPrice: info.price)
        }
    }
}
