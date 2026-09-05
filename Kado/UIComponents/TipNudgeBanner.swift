import SwiftUI
import KadoCore

/// A small card at the bottom of Today, shown once the app has been in
/// use for a while, inviting a tip.
///
/// Deliberately quiet: it sits *below* the habits rather than above
/// them, states a fact before it asks for anything, and carries its own
/// dismissal. Whether it should appear at all is not this view's
/// decision — `TipNudging` owns that, and Today only renders the card
/// once the service says yes.
struct TipNudgeBanner: View {
    /// Opens the Tip Jar.
    let onTip: () -> Void
    /// Dismisses the card for good.
    let onHide: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: KadoSpace.s3) {
            Image(systemName: "heart")
                .font(.subheadline)
                .foregroundStyle(Color.kadoAccent)
                // The heart repeats what the copy already says; leaving
                // it in the VoiceOver order would only add noise.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KadoSpace.s2) {
                Text("Kadō is free, with no ads and no subscription. If it has earned a place in your day, you can leave a tip.")
                    .font(.footnote)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onTip) {
                    Text("Leave a tip")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.kadoAccent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityID.Today.tipNudgeTipButton)
            }

            // Only does anything where the copy doesn't already fill
            // the row (iPad, landscape): it keeps the dismiss control
            // pinned to the trailing edge instead of trailing the last
            // word around.
            Spacer(minLength: KadoSpace.s3)

            hideButton
        }
        // Before the padding, so the row expands and carries the hide
        // button out to the trailing edge. Without it the card shrinks
        // to fit its text: on iPhone the copy wraps and fills the width
        // anyway, but on iPad it fits on one line and the card would
        // stop short of the habit rows above it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KadoSpace.s4)
        .background(Color.kadoAccentTint, in: RoundedRectangle(cornerRadius: KadoRadius.card))
    }

    /// A 44pt hit target, pulled back into the card's own padding so it
    /// buys the tap area without visibly inflating the card.
    private var hideButton: some View {
        Button(action: onHide) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.kadoForegroundTertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, -KadoSpace.s3)
        .padding(.trailing, -KadoSpace.s3)
        .accessibilityLabel(Text("Hide this message"))
        .accessibilityIdentifier(AccessibilityID.Today.tipNudgeHideButton)
    }
}

// MARK: - Previews

#Preview("In place") {
    List {
        Section {
            Text(verbatim: "Meditate")
                .padding(.vertical, KadoSpace.s2)
                .listRowBackground(Color.kadoBackgroundSecondary)
        }
        Section {
            TipNudgeBanner(onTip: {}, onHide: {})
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: KadoSpace.s2, leading: 20, bottom: KadoSpace.s5, trailing: 20))
        }
    }
    .scrollContentBackground(.hidden)
    .background(Color.kadoBackground.ignoresSafeArea())
}

#Preview("On its own") {
    TipNudgeBanner(onTip: {}, onHide: {})
        .padding()
        .background(Color.kadoBackground)
}

#Preview("Dark") {
    TipNudgeBanner(onTip: {}, onHide: {})
        .padding()
        .background(Color.kadoBackground)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    TipNudgeBanner(onTip: {}, onHide: {})
        .padding()
        .background(Color.kadoBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}
