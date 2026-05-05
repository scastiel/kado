import Foundation
import SwiftData

@MainActor
public enum HabitSortOrder {
    public static func nextSortOrder(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<HabitRecord>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let maxOrder = records
            .filter { $0.archivedAt == nil }
            .first?.sortOrder ?? -1
        return maxOrder + 1
    }

    public static func reorder(_ items: inout [Int], from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}
