import SwiftData
import SwiftUI
import KadoCore

/// Root view of the app. Hosts the primary TabView shell.
///
/// The TabView shape is intentionally minimal at bootstrap: two tabs
/// (Today, Settings) with empty placeholder contents. Real content
/// lands in v0.1 (Today list) and v1.0 (Settings screens).
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "list.bullet.clipboard") {
                TodayView()
            }
            Tab("Overview", systemImage: "square.grid.2x2") {
                OverviewView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .kadoTheme()
        .reviewPromptOnForeground()
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewContainer.shared)
}

#Preview("Dark") {
    ContentView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
