import SwiftUI
import KadoCore

/// Horizontal row of 7 toggleable capsules, one week's worth.
/// Each capsule toggles membership in the bound set.
///
/// Laid out from the injected calendar's `firstWeekday` (Settings →
/// Week), so the row reads in the same direction as the calendar grid
/// on a habit's screen.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    @Environment(\.calendar) private var calendar

    private var displayOrder: [Weekday] {
        Weekday.week(startingOn: calendar.firstWeekday)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(displayOrder, id: \.self) { day in
                capsule(for: day)
            }
        }
    }

    private func capsule(for day: Weekday) -> some View {
        let isSelected = selection.contains(day)
        return Button {
            if isSelected {
                selection.remove(day)
            } else {
                selection.insert(day)
            }
        } label: {
            Text(day.localizedShort)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(isSelected ? Color.white : Color.kadoForeground)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.kadoHairline)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.localizedFull)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Mon/Wed/Fri") {
    StatefulPreview(initial: [.monday, .wednesday, .friday])
}

#Preview("Weekends") {
    StatefulPreview(initial: [.saturday, .sunday])
}

#Preview("Empty") {
    StatefulPreview(initial: [])
}

/// The state the previewing Mac never shows on its own: every preview
/// above renders under `Calendar.current`, so on a Monday-first machine
/// they are indistinguishable from the order this row used to hard-code.
#Preview("Week starts on Sunday") {
    StatefulPreview(initial: [.monday, .wednesday, .friday])
        .environment(\.calendar, .sundayFirst)
}

#Preview("Dark") {
    StatefulPreview(initial: [.monday, .wednesday, .friday])
        .preferredColorScheme(.dark)
}

private struct StatefulPreview: View {
    @State var selection: Set<Weekday>

    init(initial: Set<Weekday>) {
        _selection = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 16) {
            WeekdayPicker(selection: $selection)
                .padding(.horizontal)
            Text("Selected: \(selection.count) days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
