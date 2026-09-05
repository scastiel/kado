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
///
/// **It draws no background of its own.** The tint and the rounded
/// corners come from `.listRowBackground` at the call site, exactly as
/// `HabitRowView`'s do, so the card is the same width and the same
/// system corner radius as the habit rows above it. Drawing its own
/// `RoundedRectangle` instead made it visibly narrower and squarer —
/// `KadoRadius.card` is 10pt against the list's ~30pt.
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KadoSpace.s4)
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

/// The only context the banner is ever used in, so every preview shows
/// it there — including the `.listRowBackground` that gives it its tint
/// and corners.
private struct TipNudgePreviewList: View {
    var body: some View {
        List {
            Section {
                Text(verbatim: "Meditate")
                    .padding(.vertical, KadoSpace.s2)
                    .listRowBackground(Color.kadoBackgroundSecondary)
                Text(verbatim: "Read")
                    .padding(.vertical, KadoSpace.s2)
                    .listRowBackground(Color.kadoBackgroundSecondary)
            }
            Section {
                TipNudgeBanner(onTip: {}, onHide: {})
                    .listRowBackground(Color.kadoAccentTint)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("In place") {
    TipNudgePreviewList()
}

#Preview("Dark") {
    TipNudgePreviewList()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    TipNudgePreviewList()
        .environment(\.dynamicTypeSize, .accessibility3)
}
