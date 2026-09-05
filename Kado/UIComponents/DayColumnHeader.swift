import SwiftUI
import KadoCore

/// Column header for one day in the Overview grid: weekday letter
/// above the day-of-month number.
///
/// Takes the same `width` the tiles below it use, and is laid out in
/// the same container with the same spacing — that is the whole reason
/// the two line up. The shipping build sized them separately and they
/// drifted, which turned the grid into a picture that pointed at the
/// wrong dates.
///
/// The weekday label uses Apple's localized single-letter symbols via
/// `Weekday.localizedShort`, so it needs no catalog entries and can't
/// collapse "T" for Tuesday and "T" for Thursday into one string.
struct DayColumnHeader: View {
    let date: Date
    var width: CGFloat = 32
    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today

    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayLetter)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isToday ? Color.kadoBrandSolid : Color.kadoForegroundTertiary)
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isToday ? Color.kadoBrandSolid : Color.kadoForegroundSecondary)
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
    /// the rollover the grid's trailing column *is* the day the user
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
    return HStack(spacing: 5) {
        ForEach(0..<7, id: \.self) { offset in
            DayColumnHeader(
                date: Calendar.current.date(byAdding: .day, value: offset - 3, to: today)!
            )
        }
    }
    .padding()
    .background(Color.kadoBackground)
}

#Preview("Dark") {
    let today = Date()
    return HStack(spacing: 5) {
        ForEach(0..<7, id: \.self) { offset in
            DayColumnHeader(
                date: Calendar.current.date(byAdding: .day, value: offset - 3, to: today)!
            )
        }
    }
    .padding()
    .background(Color.kadoBackground)
    .preferredColorScheme(.dark)
}
