import Foundation

/// One point in a habit's score history.
public struct DailyScore: Hashable, Sendable {
    public let date: Date
    public let score: Double
}
