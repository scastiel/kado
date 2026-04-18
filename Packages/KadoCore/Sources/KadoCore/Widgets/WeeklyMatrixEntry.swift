import Foundation
import SwiftData
import WidgetKit

/// Timeline entry for the large weekly-grid widget. Pre-computes
/// the OverviewMatrix rows so the widget view stays purely
/// presentational.
public struct WeeklyMatrixEntry: TimelineEntry, Sendable {
    public let date: Date
    public let days: [Date]
    public let rows: [MatrixRow]

    public init(date: Date, days: [Date], rows: [MatrixRow]) {
        self.date = date
        self.days = days
        self.rows = rows
    }

    public static func placeholder() -> WeeklyMatrixEntry {
        WeeklyMatrixEntry(date: .now, days: [], rows: [])
    }
}

public extension WeeklyMatrixEntry {
    /// Build an entry for the trailing `windowDays`-long window
    /// ending on `reference`'s day. Reuses `OverviewMatrix.compute`
    /// so the widget and the Overview tab stay identical pixel-for-
    /// pixel for the same date range.
    @MainActor
    public static func build(
        from context: ModelContext,
        asOf reference: Date,
        calendar: Calendar,
        frequencyEvaluator: any FrequencyEvaluating,
        windowDays: Int = 7
    ) throws -> WeeklyMatrixEntry {
        // Widget extension can't compile `#Predicate` — see
        // HabitEntity.fetchSuggestions. Filter in Swift.
        let habitDescriptor = FetchDescriptor<HabitRecord>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let habitRecords = try context.fetch(habitDescriptor)
            .filter { $0.archivedAt == nil }
        let habits = habitRecords.map(\.snapshot)

        let completionDescriptor = FetchDescriptor<CompletionRecord>()
        let completionRecords = try context.fetch(completionDescriptor)
        let completions = completionRecords.map(\.snapshot)

        let today = calendar.startOfDay(for: reference)
        let days: [Date] = (0..<windowDays).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        let rows = OverviewMatrix.compute(
            habits: habits,
            completions: completions,
            days: days,
            today: reference,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )

        return WeeklyMatrixEntry(date: reference, days: days, rows: rows)
    }
}
