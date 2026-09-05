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

            VStack(alignment: .leading, spacing: KadoSpace.s3) {
                Text("Kadō is free, with no ads and no subscription. If it has earned a place in your day, you can leave a tip.")
                    .font(.footnote)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KadoSpace.s4)
    }

    /// Both actions read as words rather than symbols. The dismiss used
    /// to be an `×` in the corner, which was worse twice over: a glyph
    /// with no label, in `kadoForegroundTertiary` on this tint, comes to
    /// 2.8:1 — under the 3:1 a non-text control needs, and it was the
    /// only way to put the card away.
    private var actions: some View {
        HStack(spacing: KadoSpace.s5) {
            Button(action: onTip) {
                Text("Leave a tip")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.kadoAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Today.tipNudgeTipButton)

            Button(action: onHide) {
                Text("Not now")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Today.tipNudgeHideButton)
        }
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
