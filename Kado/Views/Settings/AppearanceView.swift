import SwiftUI
import KadoCore

/// Settings → Appearance: how Kadō looks, as opposed to how it
/// behaves: the habit colour theme and the Home Screen icon.
struct AppearanceView: View {
    /// Set by a tap on a locked habit theme or app icon. The destination is attached
    /// to the `Form` rather than inside the section, because a
    /// `navigationDestination` inside a lazy container like `Form` is
    /// ignored.
    @State private var showsSupporterPack = false
    @Environment(\.appearanceAnnouncement) private var appearanceAnnouncement

    var body: some View {
        Form {
            HabitThemeSection(showsSupporterPack: $showsSupporterPack)
            AppIconSection(showsSupporterPack: $showsSupporterPack)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationDestination(isPresented: $showsSupporterPack) {
            SupporterPackView()
        }
        // Whichever way the user got here — Today's card or Settings —
        // they have found the screen, so Today stops announcing it.
        .onAppear { appearanceAnnouncement.retire() }
    }
}

#Preview("Locked") {
    NavigationStack {
        AppearanceView()
    }
}

#Preview("Supporter") {
    NavigationStack {
        AppearanceView()
    }
    .environment(\.supporterPack, MockSupporterPackStore(isSupporter: true))
}

#Preview("Dark") {
    NavigationStack {
        AppearanceView()
    }
    .environment(\.supporterPack, MockSupporterPackStore(isSupporter: true))
    .preferredColorScheme(.dark)
}
