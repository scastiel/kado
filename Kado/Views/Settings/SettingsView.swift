import SwiftUI
import KadoCore

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
                NotificationsSection()
                BackupSection()
                SupportSection()
                DevModeSection()
                wordmarkFooter
            }
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }

    /// Decorative wordmark at the bottom of Settings. Rendered as the
    /// footer of an empty Section so it sits below every card with
    /// the same inset as the rest of the Form. `Text(verbatim:)`
    /// skips the localization path — 稼働 is brand art, not a phrase
    /// that translates. The accessibilityLabel carries the
    /// translatable phrasing VoiceOver reads.
    private var wordmarkFooter: some View {
        Section {
            EmptyView()
        } footer: {
            Text(verbatim: "稼 働 · in operation")
                .font(.system(size: 13, design: .serif))
                .tracking(2.0)
                .foregroundStyle(Color.kadoForegroundTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .accessibilityLabel(String(localized: "Kadō — in operation"))
        }
        .listRowBackground(Color.clear)
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
