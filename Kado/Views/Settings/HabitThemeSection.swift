import SwiftUI
import KadoCore

/// Settings control for the habit colour theme.
///
/// A theme recolours every habit at once, in the app and in the
/// widgets, and touches nothing else — each habit keeps its slot (red …
/// purple), and the theme decides what that slot looks like, so
/// switching back is lossless. Kadō is the default; Classic is the
/// system hues habits wore before #89, brought back for the people who
/// preferred them. Each row draws its own eight slots, so the choice
/// is visible before it's made.
struct HabitThemeSection: View {
    @AppStorage(HabitThemeDefaults.key, store: HabitThemeDefaults.sharedDefaults)
    private var theme: HabitTheme = HabitThemeDefaults.defaultValue

    var body: some View {
        HabitThemePicker(theme: $theme)
    }
}

/// The section itself, over a plain binding so previews can drive it
/// without touching the shared `UserDefaults` suite.
private struct HabitThemePicker: View {
    @Binding var theme: HabitTheme

    var body: some View {
        Section {
            Picker("Habit colours", selection: $theme) {
                ForEach(HabitTheme.allCases, id: \.self) { option in
                    HabitThemeRow(theme: option)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Habit colours")
                .foregroundStyle(Color.kadoForegroundSecondary)
        } footer: {
            Text("Recolours every habit, here and in widgets. Each habit keeps its colour; the theme decides how it looks.")
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
}

/// One option: the theme's name above its eight slots, painted in
/// that theme rather than the current one.
private struct HabitThemeRow: View {
    let theme: HabitTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.name)
                .foregroundStyle(Color.kadoForeground)
            HStack(spacing: 6) {
                ForEach(HabitColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(color.color(in: theme))
                        .frame(width: 18, height: 18)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(theme.name))
        .accessibilityIdentifier(AccessibilityID.Settings.habitThemeRow(theme.rawValue))
    }
}

private extension HabitTheme {
    var name: LocalizedStringKey {
        switch self {
        case .kado: "Kadō"
        case .classic: "Classic"
        }
    }
}

// MARK: - Previews

private struct HabitThemeSectionPreview: View {
    @State var theme: HabitTheme

    var body: some View {
        Form {
            HabitThemePicker(theme: $theme)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("Kadō (default)") {
    HabitThemeSectionPreview(theme: .kado)
}

#Preview("Classic") {
    HabitThemeSectionPreview(theme: .classic)
}

#Preview("Dark") {
    HabitThemeSectionPreview(theme: .classic)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    HabitThemeSectionPreview(theme: .kado)
        .environment(\.dynamicTypeSize, .accessibility3)
}
