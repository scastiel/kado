import SwiftUI

/// Small popover body that inspects one (habit × day) cell. Shows the
/// habit identity, the date, the day's state in plain language, and
/// — for scored cells — the EMA score as a percentage.
struct CellPopoverContent: View {
    let habit: Habit
    let date: Date
    let cell: DayCell
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: habit.icon)
                    .foregroundStyle(habit.color.color)
                Text(habit.name)
                    .font(.headline)
            }
            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(stateLabel)
                    .font(.callout.weight(.medium))
                Spacer()
                if let percent = scorePercent {
                    Text(percent)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(habit.color.color)
                }
            }
        }
        .padding()
        .frame(minWidth: 220, maxWidth: 280)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var stateLabel: String {
        switch cell {
        case .future: String(localized: "Upcoming")
        case .notDue: String(localized: "Not scheduled")
        case .scored: String(localized: "Scored")
        }
    }

    private var scorePercent: String? {
        guard case .scored(let s) = cell else { return nil }
        return "\(Int((s * 100).rounded()))%"
    }
}

#Preview("Scored") {
    CellPopoverContent(
        habit: Habit(
            name: "Morning meditation",
            frequency: .daily,
            type: .binary,
            createdAt: .now,
            color: .purple,
            icon: "figure.mind.and.body"
        ),
        date: .now,
        cell: .scored(0.72)
    )
}

#Preview("Not scheduled") {
    CellPopoverContent(
        habit: Habit(
            name: "Gym",
            frequency: .specificDays([.monday, .wednesday, .friday]),
            type: .binary,
            createdAt: .now,
            color: .orange,
            icon: "dumbbell.fill"
        ),
        date: .now,
        cell: .notDue
    )
}
