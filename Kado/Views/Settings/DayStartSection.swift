import SwiftUI
import KadoCore

/// Settings control for the hour at which Kadō rolls over to the next
/// day.
///
/// Exists for people whose day doesn't start at midnight: at `04:00`,
/// a tap at 1am still lands on the day that just ended, so the one-tap
/// Today flow survives the part of the night when motivation is
/// lowest. At `14:00`, someone who works nights and wakes in the
/// afternoon gets a Today that rolls over when they do, not mid-shift.
///
/// Any hour is offerable. See ``DayStartDefaults``.
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
            // A pushed list, not the menu "Week starts on" uses: a menu
            // shows about twelve rows before it scrolls, which put every
            // afternoon hour — the ones an overnight worker came for —
            // below the fold. Same rule iOS Settings follows: menus for
            // short sets, a list once the set is long.
            NavigationLink {
                DayStartHourList(hour: $hour)
            } label: {
                LabeledContent("Day starts at") {
                    Text(DayStartHourLabel.text(for: hour))
                }
            }
            .accessibilityIdentifier(AccessibilityID.Settings.dayStartPicker)
        } header: {
            Text("Day")
                .foregroundStyle(Color.kadoForegroundSecondary)
        } footer: {
            Text(footer)
                .foregroundStyle(Color.kadoForegroundSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }

    /// Two footers rather than one: at midnight there is no window to
    /// explain, and describing one would only invite the question of
    /// what it does.
    private var footer: LocalizedStringKey {
        hour == DayStartDefaults.defaultHour
            ? "The day rolls over at midnight. Pick a different hour if your day doesn't start there — in the small hours if you're up past midnight, or in the afternoon if you work nights."
            : "Until this hour, Today still shows the previous day — so a tap before then lands where you expect. Reminders keep their own times, and changing this never moves a completion you've already logged."
    }

}

/// The pushed list of hours, one row each, the current one checked.
///
/// Hand-built rather than `.pickerStyle(.navigationLink)`: the
/// destination SwiftUI generates for that style renders in the system
/// list style — white rows in light, black in dark — with no seam to
/// give it the paper background every other pushed screen has (see
/// `TipJarView`). Selecting a row writes the hour and pops, the way
/// the system picker does.
private struct DayStartHourList: View {
    @Binding var hour: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Array(DayStartDefaults.allowedHours), id: \.self) { candidate in
                Button {
                    hour = candidate
                    dismiss()
                } label: {
                    HStack {
                        Text(DayStartHourLabel.text(for: candidate))
                            .foregroundStyle(Color.kadoForeground)
                        Spacer()
                        if candidate == hour {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.kadoAccent)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityAddTraits(candidate == hour ? .isSelected : [])
                .listRowBackground(Color.kadoBackgroundSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
        .navigationTitle("Day starts at")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

private struct DayStartSectionPreview: View {
    @State private var hour: Int

    init(hour: Int) {
        _hour = State(initialValue: hour)
    }

    var body: some View {
        NavigationStack {
            Form {
                DayStartPicker(hour: $hour)
            }
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
        }
    }
}

private struct DayStartHourListPreview: View {
    @State private var hour: Int

    init(hour: Int) {
        _hour = State(initialValue: hour)
    }

    var body: some View {
        NavigationStack {
            DayStartHourList(hour: $hour)
        }
    }
}

#Preview("Midnight (default)") {
    DayStartSectionPreview(hour: 0)
}

#Preview("4 AM") {
    DayStartSectionPreview(hour: 4)
}

#Preview("2 PM") {
    DayStartSectionPreview(hour: 14)
}

#Preview("Hour list, 2 PM") {
    DayStartHourListPreview(hour: 14)
}

#Preview("Dark") {
    DayStartSectionPreview(hour: 4)
        .preferredColorScheme(.dark)
}

#Preview("Hour list, Dark") {
    DayStartHourListPreview(hour: 14)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    DayStartSectionPreview(hour: 4)
        .environment(\.dynamicTypeSize, .accessibility3)
}
