import SwiftUI
import KadoCore

/// Small popover body that inspects one (habit × day) cell. Shows the
/// habit identity, the date, and the day's completion status in
/// plain language. For partial counter/timer completions, adds a
/// percentage.
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
            Text(statusLabel)
                .font(.callout.weight(.medium))
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

    private var statusLabel: String {
        switch cell {
        case .future:
            return String(localized: "Upcoming")
        case .notDue:
            return String(localized: "Not scheduled")
        case .scored(let s):
            if s >= 1.0 {
                return String(localized: "Completed")
            } else if s <= 0.0 {
                return String(localized: "Missed")
            } else {
                let percent = Int((s * 100).rounded())
                return String(localized: "\(percent)% complete")
            }
        }
    }
}

#Preview("Completed") {
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
        cell: .scored(1.0)
    )
}

#Preview("Partial") {
    CellPopoverContent(
        habit: Habit(
            name: "Drink water",
            frequency: .daily,
            type: .counter(target: 8),
            createdAt: .now,
            color: .blue,
            icon: "drop.fill"
        ),
        date: .now,
        cell: .scored(0.5)
    )
}

#Preview("Missed") {
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
        cell: .scored(0.0)
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
