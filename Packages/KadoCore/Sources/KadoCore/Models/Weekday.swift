import Foundation

/// Days of the week, with raw values aligned to
/// `Calendar.component(.weekday, from:)` (Sunday = 1, Saturday = 7).
public enum Weekday: Int, CaseIterable, Hashable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

public extension Weekday {
    /// One-letter standalone weekday symbol for picker cells and
    /// calendar headers (e.g. "M" on Monday in EN, "L" in FR).
    /// Sourced from `Calendar.veryShortStandaloneWeekdaySymbols`, so
    /// it auto-localizes via the system without catalog entries.
    public var localizedShort: String {
        symbol(from: Calendar.current.veryShortStandaloneWeekdaySymbols)
    }

    /// Three-letter standalone weekday abbreviation for frequency
    /// subtitles and compact lists (e.g. "Mon" in EN, "lun." in FR).
    public var localizedMedium: String {
        symbol(from: Calendar.current.shortStandaloneWeekdaySymbols)
    }

    /// Full standalone weekday name for accessibility labels and
    /// contexts where the day appears on its own.
    public var localizedFull: String {
        symbol(from: Calendar.current.standaloneWeekdaySymbols)
    }

    private func symbol(from symbols: [String]) -> String {
        guard symbols.indices.contains(rawValue - 1) else { return "" }
        return symbols[rawValue - 1]
    }
}

public extension Weekday {
    /// The seven days in the order a week starting on `firstWeekday`
    /// lays them out — `firstWeekday` being a `Calendar.firstWeekday`
    /// value (1 = Sunday, 2 = Monday).
    ///
    /// Every surface that renders a week horizontally goes through
    /// this rather than hard-coding `[.monday, ..., .sunday]`: the
    /// calendar grid on a habit's screen, the day picker in the new
    /// habit form, and the "Mon · Wed · Fri" frequency subtitles.
    /// Keeping one implementation is what stops them disagreeing
    /// after the user changes the preference.
    static func week(startingOn firstWeekday: Int) -> [Weekday] {
        let start = normalize(firstWeekday)
        return (0..<7).compactMap { offset in
            Weekday(rawValue: (start - 1 + offset) % 7 + 1)
        }
    }

    /// Zero-based column this day occupies in a week starting on
    /// `firstWeekday` — i.e. how many blank cells a month grid needs
    /// before the day that opens the month.
    func column(inWeekStartingOn firstWeekday: Int) -> Int {
        (rawValue - Weekday.normalize(firstWeekday) + 7) % 7
    }

    /// Folds any integer into `1...7`. The value arrives from
    /// `UserDefaults` by way of `Calendar.firstWeekday`, so a build
    /// that wrote something nonsensical must not shift the grid or
    /// trap — it lands on a real weekday instead.
    private static func normalize(_ firstWeekday: Int) -> Int {
        ((firstWeekday - 1) % 7 + 7) % 7 + 1
    }
}
