import SwiftUI

/// The Settings tab.
///
/// v0.1 surfaces the iCloud account status only — there is no in-app
/// sync toggle, by design. Control lives in iOS Settings → Apple ID
/// → iCloud → Kado, matching the native pattern used by Reminders,
/// Journal, and Streaks. v1.0 adds About, themes, biometrics, and
/// export sections below this one.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                SyncStatusSection()
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview("Available") {
    SettingsView()
        .environment(\.cloudAccountStatus, MockCloudAccountStatusObserver(status: .available))
}

#Preview("Not signed in") {
    SettingsView()
        .environment(\.cloudAccountStatus, MockCloudAccountStatusObserver(status: .noAccount))
}

#Preview("Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}
