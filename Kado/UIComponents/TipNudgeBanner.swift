import SwiftUI
import KadoCore

/// A small card at the bottom of Today, shown once the app has been in
/// use for a while, inviting a tip.
///
/// Deliberately quiet: it sits *below* the habits rather than above
/// them, states a fact before it asks for anything, and carries its own
/// dismissal. Whether it should appear at all is not this view's
/// decision — `TipNudging` owns that, `TodayCard` decides between it
/// and the Appearance announcement, and Today only renders the card
/// once both say yes. Layout and row treatment: `TodayNoticeCard`.
struct TipNudgeBanner: View {
    /// Opens the Tip Jar.
    let onTip: () -> Void
    /// Dismisses the card for good.
    let onHide: () -> Void

    var body: some View {
        TodayNoticeCard(
            systemImage: "heart",
            message: "Kadō is free, with no ads and no subscription. If it has earned a place in your day, you can leave a tip.",
            primaryTitle: "Leave a tip",
            primaryIdentifier: AccessibilityID.Today.tipNudgeTipButton,
            onPrimary: onTip,
            hideIdentifier: AccessibilityID.Today.tipNudgeHideButton,
            onHide: onHide
        )
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
                    .todayNoticeCardRow()
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
