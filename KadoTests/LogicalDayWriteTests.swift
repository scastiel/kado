import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

/// The write half of the "Day starts at" feature: a completion logged
/// before the rollover must land on the logical day the user is
/// looking at, and must keep the one-record-per-day invariant while
/// doing so.
///
/// These tests drive `CompletionToggler` / `CompletionLogger` the same
/// way the views do — with `DayBoundary.loggingInstant(for:)` standing
/// in for the live clock.
@Suite("Logical-day writes")
@MainActor
struct LogicalDayWriteTests {
    let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var calendar: Calendar { TestCalendar.utc }

    private func makeHabit(_ type: HabitType = .binary) throws -> HabitRecord {
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: type)
        container.mainContext.insert(habit)
        try container.mainContext.save()
        return habit
    }

    // MARK: - Bucketing

    @Test("A completion logged at 02:00 buckets to the previous day")
    func logsToThePreviousDayBeforeRollover() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        CompletionToggler(calendar: calendar).toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: atTwoAM),
            in: container.mainContext
        )
        try container.mainContext.save()

        let stored = try #require(habit.completions?.first)
        #expect(calendar.startOfDay(for: stored.date) == TestCalendar.instant(calendar, 2026, 8, 10))
    }

    @Test("The same log under the midnight default stays on the new day")
    func logsToTheNewDayWithoutAnOffset() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 0)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        CompletionToggler(calendar: calendar).toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: atTwoAM),
            in: container.mainContext
        )
        try container.mainContext.save()

        let stored = try #require(habit.completions?.first)
        #expect(calendar.startOfDay(for: stored.date) == TestCalendar.instant(calendar, 2026, 8, 11))
    }

    // MARK: - One record per logical day

    /// The invariant most at risk from this feature: 23:00 and 01:00
    /// are different *calendar* days, so without the shift the second
    /// tap would insert a second record instead of undoing the first.
    @Test("Toggling at 23:00 then 01:00 mutates one record, not two")
    func singleRecordAcrossWallClockMidnight() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let toggler = CompletionToggler(calendar: calendar)

        let evening = TestCalendar.instant(calendar, 2026, 8, 10, 23, 0)
        toggler.toggleToday(for: habit, on: boundary.loggingInstant(for: evening), in: container.mainContext)
        try container.mainContext.save()
        #expect(habit.completions?.count == 1)

        let afterMidnight = TestCalendar.instant(calendar, 2026, 8, 11, 1, 0)
        toggler.toggleToday(for: habit, on: boundary.loggingInstant(for: afterMidnight), in: container.mainContext)
        try container.mainContext.save()

        // Second tap on the same logical day undoes the first.
        #expect(habit.completions?.isEmpty == true)
    }

    @Test("Counter increments at 23:00 and 01:00 accumulate on one day")
    func counterAccumulatesAcrossWallClockMidnight() throws {
        let habit = try makeHabit(.counter(target: 8))
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let logger = CompletionLogger(calendar: calendar)

        let evening = TestCalendar.instant(calendar, 2026, 8, 10, 23, 0)
        logger.incrementCounter(for: habit, on: boundary.loggingInstant(for: evening), in: container.mainContext)
        let afterMidnight = TestCalendar.instant(calendar, 2026, 8, 11, 1, 30)
        logger.incrementCounter(for: habit, on: boundary.loggingInstant(for: afterMidnight), in: container.mainContext)
        try container.mainContext.save()

        #expect(habit.completions?.count == 1)
        let stored = try #require(habit.completions?.first)
        #expect(stored.value == 2.0)
    }

    // MARK: - Reading back what was written

    /// End-to-end: log before the rollover, then ask the row state
    /// what it should render. Both halves go through `DayBoundary`,
    /// and they have to agree — that agreement is the whole feature.
    @Test("A habit logged at 02:00 reads as complete on the Today row")
    func writeThenReadAgree() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        CompletionToggler(calendar: calendar).toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: atTwoAM),
            in: container.mainContext
        )
        try container.mainContext.save()

        let state = HabitRowState.resolve(
            habit: habit.snapshot,
            completions: (habit.completions ?? []).compactMap(\.snapshot),
            calendar: calendar,
            asOf: boundary.startOfDay(for: atTwoAM)
        )

        #expect(state.status == .complete)
    }

    /// …and once the boundary passes, the same habit is due again.
    @Test("After the rollover the same habit reads as not yet done")
    func newLogicalDayStartsFresh() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        CompletionToggler(calendar: calendar).toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: atTwoAM),
            in: container.mainContext
        )
        try container.mainContext.save()

        let afterRollover = TestCalendar.instant(calendar, 2026, 8, 11, 9, 0)
        let state = HabitRowState.resolve(
            habit: habit.snapshot,
            completions: (habit.completions ?? []).compactMap(\.snapshot),
            calendar: calendar,
            asOf: boundary.startOfDay(for: afterRollover)
        )

        #expect(state.status == .none)
    }

    // MARK: - Writes are pinned to the displayed day

    /// The rollover race: the rows were rendered for the previous
    /// logical day, and the tap executes a moment after the boundary.
    /// Pinning the write to the displayed day keeps Undo doing what the
    /// button said — deleting yesterday's record rather than inserting
    /// a new one for today.
    @Test("A tap rendered before the rollover still edits the displayed day")
    func writePinnedToTheDisplayedDay() throws {
        let habit = try makeHabit()
        let boundary = DayBoundary(calendar: calendar, startHour: 4)

        // Rendered at 03:59:59 — the row shows the previous day.
        let renderedAt = TestCalendar.instant(calendar, 2026, 8, 11, 3, 59, 59)
        let displayedDay = boundary.startOfDay(for: renderedAt)
        let toggler = CompletionToggler(calendar: calendar)
        toggler.toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: renderedAt, on: displayedDay),
            in: container.mainContext
        )
        try container.mainContext.save()
        #expect(habit.completions?.count == 1)

        // The tap lands a second later, after the boundary has passed.
        let tappedAt = TestCalendar.instant(calendar, 2026, 8, 11, 4, 0, 0)
        toggler.toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: tappedAt, on: displayedDay),
            in: container.mainContext
        )
        try container.mainContext.save()

        // Undone, not duplicated onto the new day.
        #expect(habit.completions?.isEmpty == true)
    }

    @Test("A pinned write always buckets to the day it was pinned to")
    func pinnedWriteBucketsToThePinnedDay() {
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let displayedDay = TestCalendar.instant(calendar, 2026, 8, 10)

        for hour in 0..<24 {
            let clock = TestCalendar.instant(calendar, 2026, 8, 11, hour, 45)
            let stored = boundary.loggingInstant(for: clock, on: displayedDay)
            #expect(calendar.startOfDay(for: stored) == displayedDay)
        }
    }

    // MARK: - Habit creation

    @Test("A habit created at 02:00 is anchored to the logical day")
    func habitCreatedBeforeRolloverAnchorsToTheLogicalDay() throws {
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        let model = NewHabitFormModel()
        model.name = "Stretch"
        let record = model.save(
            in: container.mainContext,
            createdAt: boundary.loggingInstant(for: atTwoAM)
        )

        #expect(calendar.startOfDay(for: record.createdAt) == TestCalendar.instant(calendar, 2026, 8, 10))
    }

    /// `createdAt` bounds the score and anchors the `everyNDays`
    /// cycle, so a habit created just before the rollover has to be
    /// due on the day it was created — not only from tomorrow.
    @Test("A habit created at 02:00 is due that same logical day")
    func habitCreatedBeforeRolloverIsDueImmediately() throws {
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        let model = NewHabitFormModel()
        model.name = "Stretch"
        let record = model.save(
            in: container.mainContext,
            createdAt: boundary.loggingInstant(for: atTwoAM)
        )

        let isDue = DefaultFrequencyEvaluator(calendar: calendar).isDue(
            habit: record.snapshot,
            on: boundary.startOfDay(for: atTwoAM),
            completions: []
        )

        #expect(isDue)
    }
}
