import Foundation
import SwiftData
import WidgetKit

/// Timeline entry for the large weekly-grid widget. Pre-computes
/// the OverviewMatrix rows so the widget view stays purely
/// presentational.
struct WeeklyMatrixEntry: TimelineEntry, Sendable {
    let date: Date
    let days: [Date]
    let rows: [MatrixRow]

    static func placeholder() -> WeeklyMatrixEntry {
        WeeklyMatrixEntry(date: .now, days: [], rows: [])
    }
}

extension WeeklyMatrixEntry {
    /// Build an entry for the trailing `windowDays`-long window
    /// ending on `reference`'s day. Reuses `OverviewMatrix.compute`
    /// so the widget and the Overview tab stay identical pixel-for-
    /// pixel for the same date range.
    @MainActor
    static func build(
        from context: ModelContext,
        asOf reference: Date,
        calendar: Calendar,
        frequencyEvaluator: any FrequencyEvaluating,
        windowDays: Int = 7
    ) throws -> WeeklyMatrixEntry {
        let habitDescriptor = FetchDescriptor<HabitRecord>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let habitRecords = try context.fetch(habitDescriptor)
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
