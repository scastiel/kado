import SwiftUI
import KadoCore

/// Settings → Appearance: how Kadō looks, as opposed to how it
/// behaves. Holds the habit colour theme today; the alternate app
/// icon picker joins it later.
struct AppearanceView: View {
    /// Set by a tap on a locked habit theme. The destination is attached
    /// to the `Form` rather than inside the section, because a
    /// `navigationDestination` inside a lazy container like `Form` is
    /// ignored.
    @State private var showsSupporterPack = false

    var body: some View {
        Form {
            HabitThemeSection(showsSupporterPack: $showsSupporterPack)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsSupporterPack) {
            SupporterPackView()
        }
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
