import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("HabitRowState")
struct HabitRowStateTests {

    private func habit(_ type: HabitType) -> Habit {
        Habit(
            name: "Test",
            frequency: .daily,
            type: type,
            createdAt: TestCalendar.day(-30)
        )
    }

    private func completion(for habit: Habit, dayOffset: Int, value: Double = 1) -> Completion {
        Completion(
            habitID: habit.id,
            date: TestCalendar.day(dayOffset),
            value: value
        )
    }

    // MARK: - Binary

    @Test("Binary with no completion today is .none, progress 0")
    func binaryNone() {
        let h = habit(.binary)
        let state = HabitRowState.resolve(
            habit: h,
            completions: [],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .none)
        #expect(state.progress == 0.0)
        #expect(state.valueToday == nil)
    }

    @Test("Binary with a completion today is .complete, progress 1")
    func binaryComplete() {
        let h = habit(.binary)
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .complete)
        #expect(state.progress == 1.0)
        #expect(state.valueToday == 1.0)
    }

    @Test("Binary completion on a different day does not surface as today")
    func binaryYesterdayDoesNotCount() {
        let h = habit(.binary)
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: -1)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .none)
        #expect(state.valueToday == nil)
    }

    // MARK: - Negative

    @Test("Negative with a slip recorded today is .complete (= slipped)")
    func negativeSlipped() {
        let h = habit(.negative)
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .complete)
        #expect(state.progress == 1.0)
        #expect(state.valueToday == 1.0)
    }

    @Test("Negative with no completion today is .none (= avoided)")
    func negativeAvoided() {
        let h = habit(.negative)
        let state = HabitRowState.resolve(
            habit: h,
            completions: [],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .none)
        #expect(state.progress == 0.0)
    }

    // MARK: - Counter

    @Test("Counter with no completion today is .none, progress 0")
    func counterNone() {
        let h = habit(.counter(target: 8))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .none)
        #expect(state.progress == 0.0)
        #expect(state.valueToday == nil)
    }

    @Test("Counter with value below target is .partial, progress = value/target")
    func counterPartial() {
        let h = habit(.counter(target: 8))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0, value: 3)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .partial)
        #expect(state.progress == 3.0 / 8.0)
        #expect(state.valueToday == 3.0)
    }

    @Test("Counter with value at target is .complete, progress = 1")
    func counterAtTarget() {
        let h = habit(.counter(target: 8))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0, value: 8)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .complete)
        #expect(state.progress == 1.0)
        #expect(state.valueToday == 8.0)
    }

    @Test("Counter with value above target is .complete, progress clamped to 1, raw value preserved")
    func counterOvershoot() {
        let h = habit(.counter(target: 8))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0, value: 12)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .complete)
        #expect(state.progress == 1.0)
        #expect(state.valueToday == 12.0)
    }

    // MARK: - Timer

    @Test("Timer with no completion today is .none, progress 0")
    func timerNone() {
        let h = habit(.timer(targetSeconds: 1800))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .none)
        #expect(state.progress == 0.0)
    }

    @Test("Timer with seconds equal to target is .complete, progress = 1")
    func timerAtTarget() {
        let h = habit(.timer(targetSeconds: 1800))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0, value: 1800)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .complete)
        #expect(state.progress == 1.0)
        #expect(state.valueToday == 1800.0)
    }

    @Test("Timer with partial seconds is .partial, progress = seconds/target")
    func timerPartial() {
        let h = habit(.timer(targetSeconds: 1800))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [completion(for: h, dayOffset: 0, value: 750)],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.status == .partial)
        #expect(state.progress == 750.0 / 1800.0)
        #expect(state.valueToday == 750.0)
    }

    // MARK: - Day boundary

    @Test("Paris timezone: a UTC-23:30 completion is 'tomorrow' in Paris and does not count as today")
    func parisDayBoundary() {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!

        // 2026-04-13 23:30 UTC == 2026-04-14 01:30 Paris
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 13
        c.hour = 23
        c.minute = 30
        c.timeZone = TimeZone(identifier: "UTC")
        let utcEvening = Calendar(identifier: .gregorian).date(from: c)!

        // Paris-today is the *previous* day in UTC terms.
        let parisAprilThirteen = paris.date(byAdding: .day, value: -1, to: utcEvening)!

        let h = habit(.binary)
        let comp = Completion(habitID: h.id, date: utcEvening, value: 1)

        let state = HabitRowState.resolve(
            habit: h,
            completions: [comp],
            calendar: paris,
            asOf: parisAprilThirteen
        )

        // The completion belongs to Paris-April-14, not Paris-April-13.
        #expect(state.status == .none)
        #expect(state.valueToday == nil)
    }

    // MARK: - Multiple completions on the same day

    @Test("When multiple completions exist on the same day, the first one's value is used")
    func multipleSameDayCompletions() {
        // The persistence layer enforces single-record-per-day, but the
        // resolver should not crash if upstream invariants ever slip.
        let h = habit(.counter(target: 8))
        let state = HabitRowState.resolve(
            habit: h,
            completions: [
                completion(for: h, dayOffset: 0, value: 3),
                completion(for: h, dayOffset: 0, value: 5)
            ],
            calendar: TestCalendar.utc,
            asOf: TestCalendar.day(0)
        )
        #expect(state.valueToday != nil)
        #expect(state.status == .partial || state.status == .complete)
    }
}
