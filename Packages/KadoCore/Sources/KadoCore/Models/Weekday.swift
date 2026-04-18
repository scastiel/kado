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
