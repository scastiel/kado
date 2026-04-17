import Foundation

/// Days of the week, with raw values aligned to
/// `Calendar.component(.weekday, from:)` (Sunday = 1, Saturday = 7).
enum Weekday: Int, CaseIterable, Hashable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}
