import SwiftUI
import KadoCore

/// Settings entry point for ``AppearanceView``. The row names the theme
/// habits are painted in, so the current choice reads without a push.
struct AppearanceSection: View {
    @AppStorage(HabitThemeDefaults.key, store: HabitThemeDefaults.sharedDefaults)
    private var theme: HabitTheme = HabitThemeDefaults.defaultValue
    @Environment(\.supporterPack) private var store

    var body: some View {
        Section {
            NavigationLink {
                AppearanceView()
            } label: {
                Label("Appearance", systemImage: "paintpalette")
                    .badge(Text(HabitTheme.effective(preferred: theme, isSupporter: store.isSupporter).name))
            }
            .accessibilityIdentifier(AccessibilityID.Settings.appearanceRow)
            .listRowBackground(Color.kadoBackgroundSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            AppearanceSection()
        }
    }
}

#Preview("Dark") {
    NavigationStack {
        Form {
            AppearanceSection()
        }
    }
    .preferredColorScheme(.dark)
}
