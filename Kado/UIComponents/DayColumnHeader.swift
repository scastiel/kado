import SwiftUI
import KadoCore

/// Column header for one day in the Overview matrix: weekday letter
/// above the day-of-month number. The weekday label uses Apple's
/// localized single-letter symbols, already covered by
/// `Weekday.localizedShort`.
struct DayColumnHeader: View {
    let date: Date
    var width: CGFloat = 32
    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today

    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayLetter)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(calendar.component(.day, from: date))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(isToday ? Color.accentColor : .primary)
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var weekdayLetter: String {
        let weekdayInt = calendar.component(.weekday, from: date)
        return Weekday(rawValue: weekdayInt)?.localizedShort ?? ""
    }

    /// Against the logical day rather than `isDateInToday`: before
    /// the rollover the matrix's trailing column *is* the day the user
    /// is still in, and highlighting nothing would read as a bug.
    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: today)
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

#Preview("Week") {
    let today = Date()
    return HStack(spacing: 4) {
        ForEach(0..<7, id: \.self) { offset in
            DayColumnHeader(
                date: Calendar.current.date(byAdding: .day, value: offset - 3, to: today)!
            )
        }
    }
    .padding()
}
