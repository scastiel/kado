import SwiftUI
import KadoCore

/// The Supporter pack screen, pushed from Settings — by its own row,
/// or by tapping a locked habit colour theme.
///
/// What the pack contains, one buy button, and Restore purchases. The
/// copy is careful to say what the pack is *not*: every feature stays
/// free, and so do the Kadō and Classic themes. Owning it swaps the
/// buy button for a thank-you; nothing else on the screen nags.
struct SupporterPackView: View {
    @Environment(\.supporterPack) private var store
    /// One column for the contents' symbols, so their titles line up
    /// whatever each glyph's own width. Scales with Dynamic Type.
    @ScaledMetric(relativeTo: .headline) private var symbolColumn: CGFloat = 28

    /// A purchase or restore in flight. Set synchronously in the button
    /// action, before the `Task`, so a double tap can't start two.
    @State private var activity: Activity?
    @State private var notice: Notice?

    private enum Activity {
        case purchasing
        case restoring
    }

    /// Outcomes worth an alert. Success needs none — the screen itself
    /// changes — and a cancellation is the user's own choice.
    private enum Notice: Identifiable {
        case pending
        case purchaseFailed
        case nothingToRestore
        case restoreFailed

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .pending: "Purchase pending"
            case .purchaseFailed: "Purchase failed"
            case .nothingToRestore: "Nothing to restore"
            case .restoreFailed: "Restore failed"
            }
        }

        var message: LocalizedStringKey {
            switch self {
            case .pending: "Your purchase is waiting for approval. The pack unlocks as soon as it's approved."
            case .purchaseFailed: "The purchase didn't go through. No charge was made."
            case .nothingToRestore: "This Apple Account hasn't bought the Supporter pack yet."
            case .restoreFailed: "Kadō couldn't reach the App Store. Check your connection and try again."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KadoSpace.s6) {
                header
                contents
                if store.isSupporter {
                    owned
                } else {
                    purchase
                }
            }
            .padding(.horizontal, KadoSpace.s5)
            .padding(.vertical, KadoSpace.s6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.kadoBackground.ignoresSafeArea())
        .navigationTitle(Text("Supporter pack"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .loaded = store.offerState { return }
            await store.loadOffer()
        }
        .alert(
            notice?.title ?? "",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
            presenting: notice
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            Text("SUPPORTER PACK").kadoEyebrow()
            Text("A little extra, once")
                .kadoDisplay(size: 30)
                .fixedSize(horizontal: false, vertical: true)
            Text("A one-time purchase that supports Kadō and adds a few cosmetic extras. Every feature stays free — the pack only changes how Kadō looks.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Contents

    private var contents: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s4) {
            contentRow(
                systemImage: "paintpalette",
                title: "More habit colours",
                detail: "Extra colour themes for your habits, on top of the free Kadō and Classic."
            )
            contentRow(
                systemImage: "app.badge",
                title: "Alternate app icons",
                detail: "Pick the icon Kadō wears on your Home Screen."
            )
        }
        .padding(KadoSpace.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kadoBackgroundSecondary, in: RoundedRectangle(cornerRadius: KadoRadius.card))
    }

    private func contentRow(systemImage: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: KadoSpace.s3) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.kadoAccent)
                .frame(width: symbolColumn, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: KadoSpace.s1) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.kadoForeground)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Not owned

    private var purchase: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s4) {
            switch store.offerState {
            case .loading:
                buyButton(price: nil)
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
            case .loaded(let offer):
                buyButton(price: offer.displayPrice)
            case .failed:
                offerFailed
            }
            restoreButton
            Text("One-time purchase — no subscription. Shared with your Family Sharing group.")
                .font(.footnote)
                .foregroundStyle(Color.kadoForegroundTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func buyButton(price: String?) -> some View {
        Button {
            guard activity == nil else { return }
            activity = .purchasing
            Task { await buy() }
        } label: {
            ZStack {
                // Reserve the label's size so the spinner doesn't
                // resize the button.
                Text("Get the pack · \(price ?? "$0.00")")
                    .font(.headline)
                    .opacity(activity == .purchasing ? 0 : 1)
                if activity == .purchasing {
                    // .tint colours the indicator; .foregroundStyle
                    // wouldn't, and it would vanish into the sage fill.
                    ProgressView().tint(Color.kadoBackground)
                }
            }
            // Paper on sage, as on the tip jar's price pill: the two
            // flip inversely between light and dark.
            .foregroundStyle(Color.kadoBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KadoSpace.s4)
            .background(Color.kadoAccent, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(activity != nil)
        .accessibilityLabel(Text("Get the Supporter pack, \(price ?? "")"))
        .accessibilityIdentifier(AccessibilityID.SupporterPack.buyButton)
    }

    private var offerFailed: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            Text("The Supporter pack isn't available right now. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again") {
                Task { await store.loadOffer() }
            }
            .font(.subheadline.weight(.semibold))
            .tint(Color.kadoAccent)
        }
    }

    private var restoreButton: some View {
        Button {
            guard activity == nil else { return }
            activity = .restoring
            Task { await restore() }
        } label: {
            HStack(spacing: KadoSpace.s2) {
                Text("Restore purchases")
                if activity == .restoring {
                    ProgressView().tint(Color.kadoAccent)
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .tint(Color.kadoAccent)
        .disabled(activity != nil)
        .accessibilityIdentifier(AccessibilityID.SupporterPack.restoreButton)
    }

    // MARK: - Owned

    private var owned: some View {
        VStack(alignment: .leading, spacing: KadoSpace.s3) {
            Label("You have the Supporter pack", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.kadoAccent)
            Text("Thank you for supporting Kadō. Your extras are unlocked on every device signed in to this Apple Account.")
                .font(.subheadline)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.SupporterPack.ownedBadge)
    }

    // MARK: - Actions

    private func buy() async {
        let outcome = await store.purchase()
        activity = nil
        switch outcome {
        case .success, .cancelled: break
        case .pending: notice = .pending
        case .failed: notice = .purchaseFailed
        }
    }

    private func restore() async {
        let outcome = await store.restore()
        activity = nil
        switch outcome {
        case .restored, .cancelled: break
        case .nothingToRestore: notice = .nothingToRestore
        case .failed: notice = .restoreFailed
        }
    }
}

#Preview("Not owned") {
    NavigationStack {
        SupporterPackView()
            .environment(\.supporterPack, MockSupporterPackStore())
    }
}

#Preview("Owned") {
    NavigationStack {
        SupporterPackView()
            .environment(\.supporterPack, MockSupporterPackStore(isSupporter: true))
    }
}

#Preview("Loading") {
    NavigationStack {
        SupporterPackView()
            .environment(\.supporterPack, MockSupporterPackStore(offerState: .loading, loadResult: .loading))
    }
}

#Preview("Failed") {
    NavigationStack {
        SupporterPackView()
            .environment(\.supporterPack, MockSupporterPackStore(offerState: .failed, loadResult: .failed))
    }
}

#Preview("Dark") {
    NavigationStack {
        SupporterPackView()
            .environment(\.supporterPack, MockSupporterPackStore())
    }
    .preferredColorScheme(.dark)
}
