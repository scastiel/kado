import SwiftUI
import KadoCore

/// Settings control for the hour at which Kadō rolls over to the next
/// day.
///
/// Exists for people who log habits after midnight: at `04:00`, a tap
/// at 1am still lands on the day that just ended, so the one-tap Today
/// flow survives the part of the night when motivation is lowest.
///
/// The range stops at 6 AM deliberately — the premise is that the
/// cutoff sits inside the user's sleep. See ``DayStartDefaults``.
struct DayStartSection: View {
    @AppStorage(DayStartDefaults.key, store: DayStartDefaults.sharedDefaults)
    private var dayStartHour = DayStartDefaults.defaultHour

    var body: some View {
        DayStartPicker(hour: $dayStartHour)
    }
}

/// The section itself, over a plain binding so previews can drive it
/// without touching the shared `UserDefaults` suite.
private struct DayStartPicker: View {
    @Binding var hour: Int

    var body: some View {
        Section {
            Picker("Day starts at", selection: $hour) {
                ForEach(Array(DayStartDefaults.allowedHours), id: \.self) { candidate in
                    Text(DayStartHourLabel.text(for: candidate)).tag(candidate)
                }
            }
        } header: {
            Text("Day")
        } footer: {
            Text(footer)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }

    /// Two footers rather than one: at midnight there is no window to
    /// explain, and describing one would only invite the question of
    /// what it does.
    private var footer: LocalizedStringKey {
        hour == DayStartDefaults.defaultHour
            ? "The day rolls over at midnight. Set a later hour if you log habits after midnight and still think of it as the same day."
            : "Until this hour, Today still shows the previous day — so a late-night tap lands where you expect. Reminders keep their own times, and changing this never moves a completion you've already logged."
    }

}

// MARK: - Previews

private struct DayStartSectionPreview: View {
    @State private var hour: Int

    init(hour: Int) {
        _hour = State(initialValue: hour)
    }

    var body: some View {
        Form {
            DayStartPicker(hour: $hour)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("Midnight (default)") {
    DayStartSectionPreview(hour: 0)
}

#Preview("4 AM") {
    DayStartSectionPreview(hour: 4)
}

#Preview("Dark") {
    DayStartSectionPreview(hour: 4)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    DayStartSectionPreview(hour: 4)
        .environment(\.dynamicTypeSize, .accessibility3)
}
