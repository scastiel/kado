import Testing
import Foundation
import SwiftData
import Observation
@testable import Kado
import KadoCore

/// Why the detail screen resolves records from its own `@Query` and
/// never from a `fetch` (issue #80).
///
/// SwiftUI re-renders a view when a `@Model` property it read in
/// `body` is mutated — Observation. That link turned out to have a
/// hole: a `ModelContext.fetch` performed *between* the tracked read
/// and the mutation detaches the observer, even though the fetch hands
/// back the very same instance. `HabitDetailView` used to resolve its
/// record with exactly such a fetch inside every mutation, in a view
/// with no `@Query` of its own, and a counter stepped a second time
/// landed in the store and never on the screen; only an insert or
/// delete, which changes the query's result set, woke it up.
/// `TodayView` resolves from its `@Query` array and never had the
/// problem, so that is the shape the detail screen has now.
///
/// The first test is the rule we rely on. The second is the toolchain
/// behaviour that makes it necessary, marked as a known issue: the day
/// it stops reproducing, the run says so and the rule can be
/// re-evaluated. (`DayEditPopoverTests` covers the screen itself.)
@Suite("Observation after a fetch")
@MainActor
struct ObservationAfterFetchTests {

    /// The container has to outlive every fetch — SwiftData traps on
    /// the first one after it is deallocated — so callers hold it, not
    /// just its context.
    private func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        container.mainContext.insert(CompletionRecord(date: TestCalendar.day(0), value: 1, habit: habit))
        try container.mainContext.save()
        return container
    }

    /// What a view's `body` does: walk the record's completions and
    /// read their values.
    private func track(_ record: HabitRecord, into fired: Flag) {
        withObservationTracking {
            _ = (record.completions ?? []).compactMap(\.snapshot)
        } onChange: {
            fired.value = true
        }
    }

    @Test("Mutating a completion reached through the tracked record notifies the observer")
    func mutationThroughTheTrackedRecordNotifies() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let record = try #require(try context.fetch(FetchDescriptor<HabitRecord>()).first)
        let fired = Flag()
        track(record, into: fired)

        // Resolved the way `TodayView` and `HabitDetailView` do it:
        // from the array already in hand, no fetch.
        CompletionLogger(calendar: TestCalendar.utc)
            .setCounter(for: record, on: TestCalendar.day(0), to: 5, in: context)
        try context.save()

        #expect(fired.value)
        #expect(record.completions?.first?.value == 5.0)
    }

    @Test("A fetch between the tracked read and the mutation detaches the observer (known SwiftData behaviour)")
    func fetchBetweenReadAndMutationDetaches() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let record = try #require(try context.fetch(FetchDescriptor<HabitRecord>()).first)
        let fired = Flag()
        track(record, into: fired)

        // The shape `HabitDetailView.record` had before #80: a fresh
        // fetch, filtered in Swift. Same instance comes back…
        let refetched = try #require(
            try context.fetch(FetchDescriptor<HabitRecord>()).first { $0.id == record.id }
        )
        #expect(refetched === record)

        CompletionLogger(calendar: TestCalendar.utc)
            .setCounter(for: refetched, on: TestCalendar.day(0), to: 5, in: context)
        try context.save()

        // …the write lands…
        #expect(record.completions?.first?.value == 5.0)
        // …and nobody is told. If this starts passing, SwiftData fixed
        // it: re-evaluate whether the no-fetch rule is still needed.
        withKnownIssue("SwiftData detaches Observation across a fetch (Xcode 26.x, iOS 18.1 and 26.5 simulators)") {
            #expect(fired.value)
        }
    }
}

/// A box the `onChange` closure can write into. Driven sequentially on
/// the main actor by the test; no concurrent access.
private final class Flag: @unchecked Sendable {
    var value = false
}
