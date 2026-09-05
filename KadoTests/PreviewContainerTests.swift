import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

@Suite("DevModeSeed seeding")
@MainActor
struct PreviewContainerTests {
    @Test("Seeds seven habits covering each type and every frequency")
    func seededShape() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        DevModeSeed.seed(into: container.mainContext)

        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.count == 7)

        let frequencies = Set(habits.map(\.frequency))
        #expect(frequencies.contains(.daily))
        #expect(frequencies.contains { freq in
            if case .specificDays = freq { return true } else { return false }
        })
        #expect(frequencies.contains { freq in
            if case .daysPerWeek = freq { return true } else { return false }
        })
        #expect(frequencies.contains { freq in
            if case .everyNDays = freq { return true } else { return false }
        })

        let types = Set(habits.map(\.type))
        #expect(types.contains(.binary))
        #expect(types.contains(.negative))
        #expect(types.contains { type in
            if case .counter = type { return true } else { return false }
        })
        #expect(types.contains { type in
            if case .timer = type { return true } else { return false }
        })

        // The every-N-days habit only demonstrates the re-anchoring
        // cycle if it starts on its creation day and is still due
        // today. Both are silent properties of the offset list, and a
        // count assertion alone would not notice either drifting.
        #expect(DevModeSeed.everyNDaysOffsets.first == 30)
        #expect(DevModeSeed.everyNDaysOffsets.last == 2)

        let completions = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        #expect(
            completions.count
                == 5 * DevModeSeed.completionsPerHabit
                    + DevModeSeed.daysPerWeekOffsets.count
                    + DevModeSeed.everyNDaysOffsets.count
        )
    }
}
