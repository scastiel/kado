import SwiftUI

/// Horizontal row of 7 toggleable capsules, Monday through Sunday.
/// Each capsule toggles membership in the bound set.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    private static let displayOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.displayOrder, id: \.self) { day in
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
            Text(shortLabel(for: day))
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shortLabel(for day: Weekday) -> String {
        switch day {
        case .monday: String(localized: "M", comment: "Short Monday label")
        case .tuesday: String(localized: "T", comment: "Short Tuesday label")
        case .wednesday: String(localized: "W", comment: "Short Wednesday label")
        case .thursday: String(localized: "T", comment: "Short Thursday label")
        case .friday: String(localized: "F", comment: "Short Friday label")
        case .saturday: String(localized: "S", comment: "Short Saturday label")
        case .sunday: String(localized: "S", comment: "Short Sunday label")
        }
    }

    private func accessibilityLabel(for day: Weekday) -> String {
        switch day {
        case .monday: String(localized: "Monday")
        case .tuesday: String(localized: "Tuesday")
        case .wednesday: String(localized: "Wednesday")
        case .thursday: String(localized: "Thursday")
        case .friday: String(localized: "Friday")
        case .saturday: String(localized: "Saturday")
        case .sunday: String(localized: "Sunday")
        }
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
