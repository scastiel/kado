import SwiftUI

/// Settings section for the in-app dev mode toggle.
///
/// Flipping the toggle on replaces the active SwiftData store with a
/// seeded demo sandbox (see `DevModeController`). Flipping it off
/// restores the real data. The real store is never touched — turning
/// dev mode back on wipes and reseeds the sandbox.
///
/// The very first activation shows a confirmation alert so a user who
/// flips the toggle by accident doesn't see their habits disappear
/// without warning. Subsequent activations skip the alert.
struct DevModeSection: View {
    @AppStorage(DevModeDefaults.key) private var isDevMode = false
    @AppStorage(DevModeDefaults.hasConfirmedKey) private var hasConfirmed = false
    @State private var showingConfirmation = false

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
            .onChange(of: isDevMode) { oldValue, newValue in
                // Intercept the first on-flip: revert, prompt, re-flip on confirm.
                if newValue && !oldValue && !hasConfirmed {
                    isDevMode = false
                    showingConfirmation = true
                }
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Replaces your data with a demo dataset. Your real data is safe and returns when you turn this off. Edits made while dev mode is on are discarded the next time you turn it on.")
        }
        .alert("Enable dev mode?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Enable", role: .destructive) {
                hasConfirmed = true
                isDevMode = true
            }
        } message: {
            Text("Your habits will be replaced by a demo dataset while dev mode is on. Your real habits are safe and will return as soon as you turn it off.")
        }
    }
}

#Preview("Off") {
    NavigationStack {
        Form { DevModeSection() }
            .navigationTitle("Settings")
    }
}
