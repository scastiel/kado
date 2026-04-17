import Foundation

/// One point in a habit's score history.
struct DailyScore: Hashable, Sendable {
    let date: Date
    let score: Double
}
