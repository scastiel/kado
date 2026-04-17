import Foundation

/// How often a habit is expected to be performed.
enum Frequency: Hashable, Codable, Sendable {
    case daily
    case daysPerWeek(Int)
    case specificDays(Set<Weekday>)
    case everyNDays(Int)
}
