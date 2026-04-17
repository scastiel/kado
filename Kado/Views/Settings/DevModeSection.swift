import SwiftUI

/// Settings section for the in-app dev mode toggle.
///
/// Flipping the toggle on replaces the active SwiftData store with a
/// seeded demo sandbox (see `DevModeController`). Flipping it off
/// restores the real data. The real store is never touched — turning
/// dev mode back on wipes and reseeds the sandbox.
struct DevModeSection: View {
    @AppStorage("kado.devMode") private var isDevMode = false

    var body: some View {
        Section {
            Toggle(isOn: $isDevMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dev mode")
                        .font(.body)
                    Text("Use a demo dataset instead of your own data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityHint(Text("Replaces your data with a demo dataset. Your real data is safe and returns when you turn this off."))
        } header: {
            Text("Developer")
        } footer: {
            Text("Replaces your data with a demo dataset. Your real data is safe and returns when you turn this off. Edits made while dev mode is on are discarded the next time you turn it on.")
        }
    }
}

#Preview("Off") {
    NavigationStack {
        Form { DevModeSection() }
            .navigationTitle("Settings")
    }
}
