import SwiftUI
import KadoCore

/// Settings control for the habit colour theme.
///
/// A theme recolours every habit at once, in the app and in the
/// widgets, and touches nothing else — each habit keeps its slot (red …
/// purple), and the theme decides what that slot looks like, so
/// switching back is lossless. Kadō is the default; Classic is the
/// system hues habits wore before #89, brought back for the people who
/// preferred them. Both are free; the rest come with the Supporter
/// pack (#113). Each row draws its own eight slots, so the choice is
/// visible before it's made — locked ones included.
struct HabitThemeSection: View {
    @AppStorage(HabitThemeDefaults.key, store: HabitThemeDefaults.sharedDefaults)
    private var theme: HabitTheme = HabitThemeDefaults.defaultValue
    @Environment(\.supporterPack) private var store

    /// Set when a locked theme is tapped; `AppearanceView` pushes the
    /// Supporter pack from it.
    @Binding var showsSupporterPack: Bool

    var body: some View {
        HabitThemePicker(
            theme: $theme,
            isSupporter: store.isSupporter,
            onLockedPick: { showsSupporterPack = true }
        )
    }
}

/// The section itself, over a plain binding so previews can drive it
/// without touching the shared `UserDefaults` suite.
private struct HabitThemePicker: View {
    @Binding var theme: HabitTheme
    let isSupporter: Bool
    let onLockedPick: () -> Void

    /// What the picker shows as chosen: the theme habits actually
    /// render in. A paid pick whose pack has lapsed shows Kadō checked,
    /// because that is what the screen is painted in — the pick itself
    /// stays stored and comes back with the pack.
    ///
    /// A tap on a locked theme opens the pack instead of storing it:
    /// storing it would change nothing on screen, and a pick that
    /// silently does nothing reads as a bug.
    private var selection: Binding<HabitTheme> {
        Binding(
            get: { HabitTheme.effective(preferred: theme, isSupporter: isSupporter) },
            set: { picked in
                if picked.isLocked(isSupporter: isSupporter) {
                    onLockedPick()
                } else {
                    theme = picked
                }
            }
        )
    }

    var body: some View {
        Section {
            Picker("Habit colours", selection: selection) {
                ForEach(HabitTheme.allCases, id: \.self) { option in
                    HabitThemeRow(theme: option, isLocked: option.isLocked(isSupporter: isSupporter))
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Habit colours")
                .foregroundStyle(Color.kadoForegroundSecondary)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recolours every habit, here and in widgets. Each habit keeps its colour; the theme decides how it looks.")
                if !isSupporter {
                    Text("Themes with a lock come with the Supporter pack.")
                }
            }
            .foregroundStyle(Color.kadoForegroundSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
}

/// One option: the theme's name above its eight slots, painted in
/// that theme rather than the current one. A locked theme still shows
/// its slots — that's what someone deciding on the pack wants to see —
/// with a lock beside its name.
private struct HabitThemeRow: View {
    let theme: HabitTheme
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(theme.name)
                    .foregroundStyle(Color.kadoForeground)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Color.kadoForegroundSecondary)
                }
            }
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
        .accessibilityValue(isLocked ? Text("Needs the Supporter pack") : Text(verbatim: ""))
        .accessibilityHint(isLocked ? Text("Opens the Supporter pack.") : Text(verbatim: ""))
        .accessibilityIdentifier(AccessibilityID.Settings.habitThemeRow(theme.rawValue))
    }
}

extension HabitTheme {
    /// The theme's display name, shared by the picker rows and the
    /// Appearance row in Settings.
    var name: LocalizedStringKey {
        switch self {
        case .kado: "Kadō"
        case .classic: "Classic"
        case .muted: "Muted"
        case .vivid: "Vivid"
        case .autumn: "Autumn"
        case .monochromeSage: "Monochrome sage"
        }
    }
}

// MARK: - Previews

private struct HabitThemeSectionPreview: View {
    @State var theme: HabitTheme
    var isSupporter = false

    var body: some View {
        Form {
            HabitThemePicker(theme: $theme, isSupporter: isSupporter, onLockedPick: {})
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("Kadō (default), locked") {
    HabitThemeSectionPreview(theme: .kado)
}

#Preview("Supporter, Autumn") {
    HabitThemeSectionPreview(theme: .autumn, isSupporter: true)
}

#Preview("Lapsed Vivid shows Kadō") {
    HabitThemeSectionPreview(theme: .vivid, isSupporter: false)
}

#Preview("Dark") {
    HabitThemeSectionPreview(theme: .monochromeSage, isSupporter: true)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    HabitThemeSectionPreview(theme: .kado)
        .environment(\.dynamicTypeSize, .accessibility3)
}
