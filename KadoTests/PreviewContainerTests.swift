import Testing
import Foundation
import SwiftData
@testable import Kado

@Suite("DevModeSeed seeding")
@MainActor
struct PreviewContainerTests {
    @Test("Seeds five habits covering each frequency and type")
    func seededShape() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        DevModeSeed.seed(into: container.mainContext)

        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(habits.count == 5)

        let frequencies = Set(habits.map(\.frequency))
        #expect(frequencies.contains(.daily))
        #expect(frequencies.contains { freq in
            if case .specificDays = freq { return true } else { return false }
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

        let completions = try container.mainContext.fetch(FetchDescriptor<CompletionRecord>())
        #expect(completions.count == 5 * 7) // 5 habits × 7 sample completions each
    }
}
