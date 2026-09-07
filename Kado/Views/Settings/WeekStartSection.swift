import SwiftUI
import KadoCore

/// Settings control for the day a week starts on.
///
/// The calendar on a habit's screen used to open every week on
/// Monday, which is right for most of Europe and wrong for the
/// Americas, Japan, and much of Asia. The default here is
/// ``WeekStart/automatic`` — the region's own answer, by way of
/// `Calendar.firstWeekday` — so the fix needs no visit to Settings;
/// the picker is for people whose habit of reading a week disagrees
/// with their region's.
///
/// Purely a display preference: no completion, score, or streak is
/// computed per week, so changing it moves columns and nothing else.
struct WeekStartSection: View {
    @AppStorage(WeekStartDefaults.key, store: WeekStartDefaults.sharedDefaults)
    private var weekStart: WeekStart = WeekStartDefaults.defaultValue

    var body: some View {
        WeekStartPicker(weekStart: $weekStart)
    }
}

/// The section itself, over a plain binding so previews can drive it
/// without touching the shared `UserDefaults` suite.
private struct WeekStartPicker: View {
    @Binding var weekStart: WeekStart

    /// Deliberately not `@Environment(\.calendar)`: see
    /// ``WeekStartLabel``.
    var localeCalendar: Calendar = .current

    var body: some View {
        Section {
            Picker("Week starts on", selection: $weekStart) {
                ForEach(WeekStart.allCases, id: \.self) { option in
                    Text(WeekStartLabel.text(for: option, localeCalendar: localeCalendar))
                        .tag(option)
                }
            }
        } header: {
            Text("Week")
        } footer: {
            Text("Sets the day the calendar on a habit's screen opens on, and the order of the day pickers. Automatic follows your region.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
}

// MARK: - Previews

private struct WeekStartSectionPreview: View {
    @State private var weekStart: WeekStart
    private let localeCalendar: Calendar

    init(weekStart: WeekStart, regionFirstWeekday: Int = 2) {
        _weekStart = State(initialValue: weekStart)
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = regionFirstWeekday
        self.localeCalendar = calendar
    }

    var body: some View {
        Form {
            WeekStartPicker(weekStart: $weekStart, localeCalendar: localeCalendar)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview("Automatic (default)") {
    WeekStartSectionPreview(weekStart: .automatic)
}

#Preview("Automatic in a Sunday region") {
    WeekStartSectionPreview(weekStart: .automatic, regionFirstWeekday: 1)
}

#Preview("Pinned to Monday") {
    WeekStartSectionPreview(weekStart: .monday)
}

#Preview("Dark") {
    WeekStartSectionPreview(weekStart: .saturday)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    WeekStartSectionPreview(weekStart: .monday)
        .environment(\.dynamicTypeSize, .accessibility3)
}
