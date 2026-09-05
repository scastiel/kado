import Foundation
import KadoCore

/// The one-line caption under a habit's name on Today —
/// `"2-day streak · 43%"`, `"20/30 min · 35%"`, `"Next Monday · 21%"`.
///
/// Its job is to say the *most useful* thing about this habit right
/// now, in the space of one short line, and to be short enough that it
/// never wraps. Equal row heights are what make the Today card scan as
/// a list rather than a stack of cards, and a wrapped caption breaks
/// that for every row beside it.
///
/// Which fact wins is a strict priority, not a concatenation:
///
/// 1. **Not scheduled today** — when it next comes round. A habit
///    sitting in the "not scheduled" section with no date reads as
///    dormant rather than as waiting.
/// 2. **Slipped** — a negative habit's streak is gone; that outranks
///    the streak count it replaced.
/// 3. **Counter / timer** — today's progress toward the target. The
///    number the user is about to change beats a historical one.
/// 4. **Binary** — the streak, when there is one.
///
/// The percentage is always last and always present. It is the habit
/// score, which the caption under the progress bar labels once for the
/// whole screen rather than repeating "strength" on every row.
enum TodayRowMeta {

    /// Full caption: the lead fact, then the score. The `·` separator
    /// is punctuation rather than prose, so it isn't localized — the
    /// two halves around it are.
    static func line(
        habit: Habit,
        state: HabitRowState,
        streak: Int,
        scorePercent: Int,
        nextDue: Date?,
        calendar: Calendar,
        asOf reference: Date
    ) -> String {
        let score = percent(scorePercent)
        guard let lead = lead(
            habit: habit,
            state: state,
            streak: streak,
            nextDue: nextDue,
            calendar: calendar,
            asOf: reference
        ) else {
            return score
        }
        return "\(lead) · \(score)"
    }

    /// The lead fact, or `nil` when there isn't one worth the space —
    /// a scheduled binary habit with no streak yet, which then shows
    /// its score alone rather than an apologetic "no streak".
    static func lead(
        habit: Habit,
        state: HabitRowState,
        streak: Int,
        nextDue: Date?,
        calendar: Calendar,
        asOf reference: Date
    ) -> String? {
        if let nextDue {
            return nextDueDescription(nextDue, calendar: calendar, asOf: reference)
        }
        if case .negative = habit.type, state.status == .complete {
            return String(
                localized: "Streak reset",
                comment: "Today row caption for a negative habit slipped today."
            )
        }
        switch habit.type {
        case .counter(let target):
            return String(
                localized: "\(Int(state.valueToday ?? 0))/\(Int(target))",
                comment: "Today row caption, counter progress: value over target."
            )
        case .timer(let targetSeconds):
            return String(
                localized: "\(minutes(state.valueToday ?? 0))/\(minutes(targetSeconds)) min",
                comment: "Today row caption, timer progress: minutes over target minutes."
            )
        case .binary, .negative:
            guard streak > 0 else { return nil }
            return String(
                localized: "\(streak)-day streak",
                comment: "Today row caption: the habit's current streak in days."
            )
        }
    }

    /// The score, rendered so French gets its space before the sign.
    static func percent(_ value: Int) -> String {
        String(
            localized: "\(value)%",
            comment: "A habit score as a percentage. FR puts a space before the sign."
        )
    }

    /// `"Next Monday"` inside the coming week, an explicit date beyond
    /// it. A weekday name alone is unambiguous only for the next seven
    /// days — past that, "Next Monday" could be any of several.
    private static func nextDueDescription(
        _ date: Date,
        calendar: Calendar,
        asOf reference: Date
    ) -> String {
        let today = calendar.startOfDay(for: reference)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0

        if days <= 7,
           let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) {
            return String(
                localized: "Next \(weekday.localizedFull.localizedCapitalized)",
                comment: "Today row caption for a habit not scheduled today. Argument: a weekday name."
            )
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return String(
            localized: "Next on \(formatter.string(from: date))",
            comment: "Today row caption for a habit next due more than a week out. Argument: a short date."
        )
    }

    /// Whole minutes, rounded down — the timer caption counts elapsed
    /// minutes, and rounding 59 seconds up to a minute would show
    /// `30/30 min` on a session that hasn't met its target.
    private static func minutes(_ seconds: TimeInterval) -> Int {
        Int(seconds / 60)
    }
}
