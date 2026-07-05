import SwiftUI
import KadoCore

/// The Tip Jar screen, pushed from Settings → Support Kadō.
///
/// Warm, no-pressure copy plus three consumable tip tiers. Tipping
/// unlocks nothing — it's pure support. On a successful purchase the tier
/// list fades to a calm thank-you (honoring Reduce Motion); the user can
/// tip again any number of times.
struct TipJarView: View {
    @Environment(\.tipJarStore) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The tier whose purchase is currently in flight (drives the inline
    /// spinner and disables the other buttons).
    @State private var purchasingTier: TipProduct?
    /// Whether the calm thank-you is showing after a successful tip.
    @State private var didThankYou = false
    /// Transient title + message for a failed or pending purchase.
    @State private var noticeTitle: LocalizedStringKey = ""
    @State private var noticeMessage: LocalizedStringKey = ""
    @State private var showingNotice = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KadoSpace.s6) {
                header
                if didThankYou {
                    thankYou
                } else {
                    content
                }
            }
            .padding(.horizontal, KadoSpace.s5)
            .padding(.vertical, KadoSpace.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.kadoBackground.ignoresSafeArea())
        .navigationTitle(Text("Support Kadō"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .alert(noticeTitle, isPresented: $showingNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            Text("SUPPORT").kadoEyebrow()
            Text("If Kadō earns a place in your day")
                .kadoDisplay(size: 30)
                .fixedSize(horizontal: false, vertical: true)
            Text("Kadō is free and open source, with no ads, no subscription, and no tracking. If you'd like to help keep it that way, you can leave a tip.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loading:
            loading
        case .loaded(let tiers):
            tierList(tiers)
        case .failed:
            failed
        }
    }

    private func tierList(_ tiers: [TipTier]) -> some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            ForEach(tiers) { tier in
                tierButton(tier)
            }
            Text("Tips are optional and unlock nothing — you already have the whole app. They just support the time that goes into Kadō. Thank you for being here.")
                .font(.footnote)
                .foregroundStyle(Color.kadoForegroundTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KadoSpace.s2)
        }
    }

    private func tierButton(_ tier: TipTier) -> some View {
        Button {
            Task { await tip(tier) }
        } label: {
            HStack(spacing: KadoSpace.s4) {
                Text(tier.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(tier.displayName)
                    .font(.headline)
                    .foregroundStyle(Color.kadoForeground)
                Spacer(minLength: KadoSpace.s3)
                priceLabel(tier)
            }
            .padding(KadoSpace.s4)
            .background(Color.kadoBackgroundSecondary, in: RoundedRectangle(cornerRadius: KadoRadius.card))
        }
        .buttonStyle(.plain)
        .disabled(purchasingTier != nil)
        .accessibilityLabel(Text("Leave a \(tier.displayName) tip, \(tier.displayPrice)"))
    }

    private func priceLabel(_ tier: TipTier) -> some View {
        ZStack {
            // Reserve the price's width so swapping in the spinner
            // doesn't shift the row.
            Text(tier.displayPrice)
                .font(.subheadline.weight(.semibold))
                .opacity(purchasingTier == tier.product ? 0 : 1)
            if purchasingTier == tier.product {
                ProgressView()
            }
        }
        // Paper-on-accent rather than white-on-accent: kadoBackground
        // flips light/dark inversely to kadoAccent, so contrast stays
        // strong in both modes (kadoAccent is a *light* sage in dark).
        .foregroundStyle(Color.kadoBackground)
        .padding(.horizontal, KadoSpace.s4)
        .padding(.vertical, KadoSpace.s2)
        .background(Color.kadoAccent, in: Capsule())
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            ForEach(TipProduct.orderedTiers, id: \.self) { _ in
                HStack {
                    // Verbatim: redacted placeholders, never read — the
                    // container carries the "Loading tips" a11y label.
                    Text(verbatim: "Coffee").font(.headline)
                    Spacer()
                    Text(verbatim: "$0.00").font(.subheadline.weight(.semibold))
                }
                .padding(KadoSpace.s4)
                .background(Color.kadoBackgroundSecondary, in: RoundedRectangle(cornerRadius: KadoRadius.card))
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel(Text("Loading tips"))
    }

    private var failed: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            Text("Tips aren't available right now. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") {
                Task { await store.load() }
            }
            .font(.subheadline.weight(.semibold))
            .tint(Color.kadoAccent)
        }
    }

    // MARK: - Thank-you

    private var thankYou: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s4) {
            Text(verbatim: "ありがとう")
                .font(.kado(.display, size: 34))
                .foregroundStyle(Color.kadoAccent)
                .accessibilityLabel(Text("Thank you"))
            Text("Thank you — truly.")
                .font(.headline)
                .foregroundStyle(Color.kadoForeground)
            Text("Your support keeps Kadō free and independent. It means a lot.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Leave another tip") {
                withAnimation(reduceMotion ? nil : KadoMotion.base) {
                    didThankYou = false
                }
            }
            .font(.subheadline.weight(.semibold))
            .tint(Color.kadoAccent)
            .padding(.top, KadoSpace.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func tip(_ tier: TipTier) async {
        purchasingTier = tier.product
        let outcome = await store.purchase(tier.product)
        purchasingTier = nil

        switch outcome {
        case .success:
            withAnimation(reduceMotion ? nil : KadoMotion.base) {
                didThankYou = true
            }
        case .cancelled:
            break
        case .pending:
            noticeTitle = "Tip pending"
            noticeMessage = "Your tip is pending approval. Thank you!"
            showingNotice = true
        case .failed:
            noticeTitle = "Purchase failed"
            noticeMessage = "The purchase didn't go through. No charge was made."
            showingNotice = true
        }
    }
}

#Preview("Loaded") {
    NavigationStack {
        TipJarView()
            .environment(\.tipJarStore, MockTipJarStore())
    }
}

#Preview("Loading") {
    NavigationStack {
        TipJarView()
            .environment(\.tipJarStore, MockTipJarStore(initialState: .loading, loadResult: .loading))
    }
}

#Preview("Failed") {
    NavigationStack {
        TipJarView()
            .environment(\.tipJarStore, MockTipJarStore(initialState: .failed, loadResult: .failed))
    }
}

#Preview("Dark") {
    NavigationStack {
        TipJarView()
            .environment(\.tipJarStore, MockTipJarStore())
    }
    .preferredColorScheme(.dark)
}
