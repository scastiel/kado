import SwiftUI
import KadoCore

/// Settings → Appearance control for the Home Screen icon (#114).
///
/// Every option is the same mark in other colours. Kadō's own icon is
/// free; the alternates come with the Supporter pack, and a tap on a
/// locked one opens the pack instead of being stored — like the habit
/// colour themes above it. Each row shows the icon in the current
/// appearance, so the dark variant is what a dark-mode user compares.
///
/// The system changes the icon and shows its own alert. If it refuses,
/// the pick is rolled back and the reason shown, so the checkmark never
/// claims an icon the Home Screen doesn't wear.
struct AppIconSection: View {
    @AppStorage(AppIconDefaults.key) private var icon: AppIcon = AppIconDefaults.defaultValue
    @Environment(\.supporterPack) private var store
    @Environment(\.appIconApplier) private var applier

    /// Set when a locked icon is tapped; `AppearanceView` pushes the
    /// Supporter pack from it.
    @Binding var showsSupporterPack: Bool

    @State private var isApplying = false
    @State private var failureMessage: String?

    var body: some View {
        if applier.switcher.supportsAlternateIcons {
            AppIconPicker(
                selection: AppIcon.effective(preferred: icon, isSupporter: store.isSupporter),
                isSupporter: store.isSupporter,
                isApplying: isApplying,
                onPick: pick
            )
            .alert(
                "Couldn't change the icon",
                isPresented: Binding(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                ),
                presenting: failureMessage
            ) { _ in
                Button("OK") {}
            } message: { message in
                Text(verbatim: message)
            }
        }
    }

    /// `isApplying` is set before the `Task` is spawned, so two taps in
    /// one runloop tick can't both reach the system.
    private func pick(_ picked: AppIcon) {
        if picked.isLocked(isSupporter: store.isSupporter) {
            showsSupporterPack = true
            return
        }
        guard !isApplying else { return }
        let previous = icon
        icon = picked
        isApplying = true
        let applier = self.applier
        let isSupporter = store.isSupporter
        Task {
            defer { isApplying = false }
            do {
                try await applier.apply(preferred: picked, isSupporter: isSupporter)
            } catch {
                icon = previous
                failureMessage = error.localizedDescription
            }
        }
    }
}

/// The section itself, over plain values so previews can drive it
/// without touching `UserDefaults` or the Home Screen.
private struct AppIconPicker: View {
    let selection: AppIcon
    let isSupporter: Bool
    let isApplying: Bool
    let onPick: (AppIcon) -> Void

    /// Buttons rather than an inline `Picker`, for the same reason as
    /// the habit colour rows: the lock has to sit in the checkmark's
    /// column.
    var body: some View {
        Section {
            ForEach(AppIcon.allCases, id: \.self) { option in
                let isLocked = option.isLocked(isSupporter: isSupporter)
                Button {
                    onPick(option)
                } label: {
                    AppIconRow(icon: option, isSelected: option == selection, isLocked: isLocked)
                }
                .disabled(isApplying)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(option.displayName), ") + Text(option.subtitle))
                .accessibilityValue(isLocked ? Text("Needs the Supporter pack") : Text(verbatim: ""))
                .accessibilityHint(isLocked ? Text("Opens the Supporter pack.") : Text(verbatim: ""))
                .accessibilityAddTraits(option == selection ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(AccessibilityID.Settings.appIconRow(option.rawValue))
            }
        } header: {
            Text("App icon")
                .foregroundStyle(Color.kadoForegroundSecondary)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("The icon on your Home Screen. Each one follows Light, Dark and Tinted.")
                if !isSupporter {
                    Text("Icons with a lock come with the Supporter pack.")
                }
            }
            .foregroundStyle(Color.kadoForegroundSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
}

/// One option: the icon as the Home Screen draws it, its name and what
/// the name means. A locked icon still shows its artwork — that's what
/// someone deciding on the pack wants to see — with a lock where the
/// checkmark would go.
private struct AppIconRow: View {
    let icon: AppIcon
    let isSelected: Bool
    let isLocked: Bool

    /// Grows with Dynamic Type, but stops short of crowding the name
    /// out of the row at the accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var scaledSide = 48.0
    private var side: CGFloat { min(scaledSide, 80) }

    var body: some View {
        HStack(spacing: 14) {
            let shape = RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous)
            Image(icon.previewImageName)
                .resizable()
                .frame(width: side, height: side)
                .clipShape(shape)
                // The paper icons sit on a paper-coloured row; a hairline
                // keeps their edge.
                .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: icon.displayName)
                    .foregroundStyle(Color.kadoForeground)
                Text(icon.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.kadoAccent)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

extension AppIcon {
    /// The icon's name. Romanised Japanese, like the app's own, so it
    /// reads the same in every language — only ``subtitle`` translates.
    var displayName: String {
        switch self {
        case .kado: "Kadō"
        case .ura: "Ura"
        case .sakura: "Sakura"
        case .momiji: "Momiji"
        case .yuyake: "Yūyake"
        case .umi: "Umi"
        case .hotaru: "Hotaru"
        case .fuji: "Fuji"
        }
    }

    /// What the name means, under it in the row.
    var subtitle: LocalizedStringKey {
        switch self {
        case .kado: "The original"
        case .ura: "Kadō, inverted"
        case .sakura: "Cherry blossom"
        case .momiji: "Autumn maple"
        case .yuyake: "Sunset"
        case .umi: "Sea"
        case .hotaru: "Firefly"
        case .fuji: "Wisteria"
        }
    }
}

// MARK: - Previews

private struct AppIconSectionPreview: View {
    @State var selection: AppIcon
    var isSupporter = false

    var body: some View {
        Form {
            AppIconPicker(selection: selection, isSupporter: isSupporter, isApplying: false) {
                if !$0.isLocked(isSupporter: isSupporter) { selection = $0 }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("Kadō (default), locked") {
    AppIconSectionPreview(selection: .kado)
}

#Preview("Supporter, Yūyake") {
    AppIconSectionPreview(selection: .yuyake, isSupporter: true)
}

#Preview("Dark") {
    AppIconSectionPreview(selection: .ura, isSupporter: true)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    AppIconSectionPreview(selection: .kado)
        .environment(\.dynamicTypeSize, .accessibility3)
}
