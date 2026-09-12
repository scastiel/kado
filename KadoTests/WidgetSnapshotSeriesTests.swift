import Foundation
import Testing
import KadoCore

/// The on-disk shape the widgets read: a run of consecutive logical
/// days, each a `WidgetSnapshot` computed "as of that morning". Pins
/// two things the widget cannot afford to get wrong — that a file
/// written by the previous app version still decodes, and which day's
/// snapshot answers for a given instant.
@Suite("WidgetSnapshotSeries")
struct WidgetSnapshotSeriesTests {
    private let calendar = TestCalendar.utc

    /// One recognisable snapshot per day: `completedToday` doubles as
    /// the day's label so a wrong pick reads as the wrong number.
    private func snapshot(day: Date, completed: Int) -> WidgetSnapshot {
        let matrixDays = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: day)
        }
        return WidgetSnapshot(
            generatedAt: TestCalendar.referenceDate,
            habits: [],
            today: [],
            totalDueToday: 3,
            completedToday: completed,
            matrix: [],
            matrixDays: matrixDays,
            logicalDay: day
        )
    }

    private func series(days: Int) -> WidgetSnapshotSeries {
        let first = calendar.startOfDay(for: TestCalendar.referenceDate)
        return WidgetSnapshotSeries(
            generatedAt: TestCalendar.referenceDate,
            days: (0..<days).map { offset in
                snapshot(
                    day: calendar.date(byAdding: .day, value: offset, to: first)!,
                    completed: offset
                )
            }
        )
    }

    private func day(_ offset: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let first = calendar.startOfDay(for: TestCalendar.referenceDate)
        let day = calendar.date(byAdding: .day, value: offset, to: first)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    // MARK: - Codec

    @Test("A series round-trips through the store's codec with every logicalDay intact")
    func seriesRoundTrips() throws {
        let original = series(days: 3)
        let data = try WidgetSnapshotStore.encode(original)
        let decoded = try #require(WidgetSnapshotStore.decode(data))

        #expect(decoded.days.map(\.logicalDay) == original.days.map(\.logicalDay))
        #expect(decoded.days.map(\.completedToday) == [0, 1, 2])
        #expect(decoded.generatedAt == original.generatedAt)
    }

    @Test("A pre-upgrade file — one bare snapshot, no logicalDay — decodes as a one-day series on its trailing matrix day")
    func legacyFileDecodesAsOneDaySeries() throws {
        // The fixture is real encoder output with the new key removed,
        // not a hand-typed blob: what an older build wrote is exactly
        // "the current shape minus the fields it didn't have".
        let legacy = snapshot(day: day(0), completed: 2)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            try JSONSerialization.jsonObject(with: encoder.encode(legacy)) as? [String: Any]
        )
        object.removeValue(forKey: "logicalDay")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try #require(WidgetSnapshotStore.decode(data))
        #expect(decoded.days.count == 1)
        let only = try #require(decoded.days.first)
        #expect(only.completedToday == 2)
        #expect(only.logicalDay == legacy.matrixDays.last)
        #expect(decoded.generatedAt == legacy.generatedAt)
    }

    @Test("A bare snapshot with no matrix days falls back to the calendar midnight of generatedAt")
    func legacyFileWithoutMatrixFallsBackToGeneratedAt() throws {
        let generatedAt = TestCalendar.referenceDate
        let legacy = WidgetSnapshot(
            generatedAt: generatedAt,
            habits: [],
            today: [],
            totalDueToday: 0,
            completedToday: 0,
            matrix: [],
            matrixDays: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            try JSONSerialization.jsonObject(with: encoder.encode(legacy)) as? [String: Any]
        )
        object.removeValue(forKey: "logicalDay")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try #require(WidgetSnapshotStore.decode(data, calendar: calendar))
        #expect(decoded.days.first?.logicalDay == calendar.startOfDay(for: generatedAt))
    }

    @Test("Bytes that are neither shape decode to nil, not to a trap")
    func garbageDecodesToNil() {
        #expect(WidgetSnapshotStore.decode(Data("not json".utf8)) == nil)
        #expect(WidgetSnapshotStore.decode(Data("{}".utf8)) == nil)
    }

    // MARK: - Which day answers

    @Test("snapshot(on:) picks the greatest logical day not after the instant")
    func picksGreatestDayNotAfterNow() {
        let boundary = DayBoundary(calendar: calendar, startHour: 0)
        let three = series(days: 3)

        #expect(three.snapshot(on: day(0, 9), boundary: boundary).completedToday == 0)
        #expect(three.snapshot(on: day(1, 15), boundary: boundary).completedToday == 1)
        #expect(three.snapshot(on: day(2, 23, 59), boundary: boundary).completedToday == 2)
        // Past the horizon: the latest day we have, never the first
        // one's ticks.
        #expect(three.snapshot(on: day(5), boundary: boundary).completedToday == 2)
    }

    @Test("Before the first day, the first day answers")
    func beforeTheSeriesTheFirstDayAnswers() {
        let boundary = DayBoundary(calendar: calendar, startHour: 0)
        #expect(series(days: 3).snapshot(on: day(-1, 12), boundary: boundary).completedToday == 0)
    }

    @Test("An empty series resolves to the empty snapshot")
    func emptySeriesResolvesToEmpty() {
        let boundary = DayBoundary(calendar: calendar, startHour: 0)
        let resolved = WidgetSnapshotSeries.empty.snapshot(on: day(0, 12), boundary: boundary)
        #expect(resolved.habits.isEmpty)
        #expect(resolved.today.isEmpty)
        #expect(resolved.totalDueToday == 0)
        #expect(resolved.matrixDays.isEmpty)
    }

    @Test("Under a 4 AM day start, 02:00 still belongs to the previous day")
    func dayStartHourShiftsSelection() {
        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let three = series(days: 3)

        #expect(three.snapshot(on: day(1, 2), boundary: boundary).completedToday == 0)
        #expect(three.snapshot(on: day(1, 4), boundary: boundary).completedToday == 1)
        #expect(three.snapshot(on: day(2, 3, 59), boundary: boundary).completedToday == 1)
    }
}
