import SwiftUI

/// The Settings tab.
///
/// Placeholder at bootstrap. v0.1 adds the iCloud sync toggle and an
/// "About" entry; v1.0 fills in themes, biometrics, and export.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape",
                description: Text("Preferences will land here as the app grows.")
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}
