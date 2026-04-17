import SwiftUI

/// Current-month calendar grid showing completion state per day.
/// Renders as a 7-column `LazyVGrid` with weekday headers and
/// leading blanks that align the first day of the month to its
/// weekday column.
struct MonthlyCalendarView: View {
    let habit: Habit
    let completions: [Completion]
    var month: Date = .now
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 32)
                }
                ForEach(daysInMonth, id: \.self) { day in
                    cell(for: day)
                        .frame(height: 32)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var monthHeader: some View {
        Text(monthTitle)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(weekdayDisplayOrder, id: \.self) { weekday in
                Text(weekday.localizedShort)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthStart)
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        return range.compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset - 1, to: monthStart)
        }
    }

    private var leadingBlanks: Int {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        // Shift so Monday (2) becomes column 0, Tuesday column 1, ..., Sunday column 6.
        let monStart = (firstWeekday + 5) % 7
        return monStart
    }

    private var weekdayDisplayOrder: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let state = state(for: day)
        let isToday = calendar.isDateInToday(day)
        let dayNumber = calendar.component(.day, from: day)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(fill(for: state))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isToday ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )
            Text("\(dayNumber)")
                .font(.caption.weight(state == .completed ? .bold : .regular))
                .foregroundStyle(foreground(for: state))
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel(for: day, state: state, isToday: isToday))
    }

    private enum CellState {
        case future       // after today
        case completed    // done on this day
        case missed       // past / today, due, not done
        case nonDue       // past / today, not due (schedule skip)
    }

    private func state(for day: Date) -> CellState {
        if day > calendar.startOfDay(for: .now) {
            return .future
        }
        let completedOnDay = completions.contains { c in
            c.habitID == habit.id && calendar.isDate(c.date, inSameDayAs: day)
        }
        // For negative habits, "completed" inverts: presence = failure.
        switch habit.type {
        case .negative:
            return completedOnDay ? .missed : .completed
        case .binary, .counter, .timer:
            if completedOnDay { return .completed }
            return dayIsDue(day) ? .missed : .nonDue
        }
    }

    private func dayIsDue(_ day: Date) -> Bool {
        switch habit.frequency {
        case .daily:
            return true
        case .specificDays(let weekdays):
            let weekdayInt = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayInt) else { return false }
            return weekdays.contains(weekday)
        case .everyNDays(let n):
            guard n > 0 else { return false }
            let createdDay = calendar.startOfDay(for: habit.createdAt)
            let delta = calendar.dateComponents([.day], from: createdDay, to: day).day ?? 0
            return delta >= 0 && delta % n == 0
        case .daysPerWeek:
            // Every day is potentially due; no "non-due" distinction on grid.
            return true
        }
    }

    private func fill(for state: CellState) -> Color {
        switch state {
        case .future: Color(.tertiarySystemFill)
        case .completed: Color.accentColor.opacity(0.9)
        case .missed: Color(.secondarySystemFill)
        case .nonDue: Color(.tertiarySystemFill).opacity(0.4)
        }
    }

    private func foreground(for state: CellState) -> Color {
        switch state {
        case .future: .secondary
        case .completed: .white
        case .missed: .primary
        case .nonDue: .secondary
        }
    }

    private func accessibilityLabel(for day: Date, state: CellState, isToday: Bool) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        let dateString = formatter.string(from: day)
        let stateString: String
        switch state {
        case .completed: stateString = String(localized: "completed")
        case .missed: stateString = String(localized: "missed")
        case .nonDue: stateString = String(localized: "not scheduled")
        case .future: stateString = String(localized: "upcoming")
        }
        if isToday {
            return "\(dateString), today, \(stateString)"
        }
        return "\(dateString), \(stateString)"
    }
}

#Preview("Daily with partial history") {
    let habit = Habit(
        name: "Meditate",
        frequency: .daily,
        type: .binary,
        createdAt: Calendar.current.date(byAdding: .day, value: -20, to: .now)!
    )
    let completions = [1, 2, 3, 5, 7, 8, 10, 12, 13, 14, 18].map { offset in
        Completion(
            habitID: habit.id,
            date: Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        )
    }
    return MonthlyCalendarView(habit: habit, completions: completions)
        .padding()
}

#Preview("Specific days (Mon/Wed/Fri)") {
    let habit = Habit(
        name: "Gym",
        frequency: .specificDays([.monday, .wednesday, .friday]),
        type: .binary,
        createdAt: Calendar.current.date(byAdding: .day, value: -40, to: .now)!
    )
    return MonthlyCalendarView(habit: habit, completions: [])
        .padding()
}

#Preview("Empty history") {
    let habit = Habit(
        name: "Read",
        frequency: .daily,
        type: .binary,
        createdAt: .now
    )
    return MonthlyCalendarView(habit: habit, completions: [])
        .padding()
}
