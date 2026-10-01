import SwiftUI
import KadoCore

/// A card at the bottom of Today announcing Settings › Appearance: the
/// habit colour themes, and the alternate icons the Supporter pack adds.
///
/// Due from the first launch, so everyone who updates sees it once.
/// `AppearanceAnnouncing` owns whether it is due, and `TodayCard` keeps
/// it and the tip nudge from ever sharing the slot. The copy names the
/// pack because the icons are locked without it — a card promising
/// icons that then show padlocks would be a bait.
struct AppearanceAnnouncementBanner: View {
    /// Opens Appearance — which retires the card on its own.
    let onOpen: () -> Void
    /// Dismisses the card for good.
    let onHide: () -> Void

    var body: some View {
        TodayNoticeCard(
            systemImage: "paintpalette",
            message: "Make Kadō yours: Settings › Appearance has colour themes for your habits and, with the Supporter pack, alternate app icons.",
            primaryTitle: "Open Appearance",
            primaryIdentifier: AccessibilityID.Today.appearanceAnnouncementOpenButton,
            onPrimary: onOpen,
            hideIdentifier: AccessibilityID.Today.appearanceAnnouncementHideButton,
            onHide: onHide
        )
    }
}

// MARK: - Previews

private struct AppearanceAnnouncementPreviewList: View {
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
                AppearanceAnnouncementBanner(onOpen: {}, onHide: {})
                    .todayNoticeCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("In place") {
    AppearanceAnnouncementPreviewList()
}

#Preview("Dark") {
    AppearanceAnnouncementPreviewList()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    AppearanceAnnouncementPreviewList()
        .environment(\.dynamicTypeSize, .accessibility3)
}
