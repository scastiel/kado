import Foundation
import Testing
import KadoCore

/// Specifies the entries a widget hands WidgetKit: one per pre-computed
/// day, dated at the instant that day begins, so the render server
/// turns the page at the boundary with neither process awake.
///
/// The invariant sweep at the end matters more than the examples: a
/// rollover that lands a second off a DST edge shows yesterday for a
/// day, and the example-shaped tests only cover the shapes already
/// thought of.
@Suite("WidgetTimelinePlan")
struct WidgetTimelinePlanTests {

    /// Seven consecutive logical days from `first`, each labelled by
    /// `completedToday` so a misdated slot reads as the wrong number.
    private func series(from first: Date, calendar: Calendar, days: Int = 7) -> WidgetSnapshotSeries {
        WidgetSnapshotSeries(
            generatedAt: first,
            days: (0..<days).map { offset in
                // Re-anchored like the builder does: adding a day to a
                // midnight does not always land on one (Havana).
                let day = calendar.startOfDay(
                    for: calendar.date(byAdding: .day, value: offset, to: first)!
                )
                return WidgetSnapshot(
                    generatedAt: first,
                    habits: [],
                    today: [],
                    totalDueToday: 3,
                    completedToday: offset,
                    matrix: [],
                    matrixDays: [day],
                    logicalDay: day
                )
            }
        )
    }

    private let utc = TestCalendar.utc
    private var d0: Date { utc.startOfDay(for: TestCalendar.referenceDate) }
    private func day(_ offset: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        let day = utc.date(byAdding: .day, value: offset, to: d0)!
        return utc.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    // MARK: - Examples

    @Test("Seven days: one slot at now, then one at each following midnight")
    func oneSlotPerDay() {
        let boundary = DayBoundary(calendar: utc, startHour: 0)
        let now = day(0, 10)
        let plan = WidgetTimelinePlan.make(series: series(from: d0, calendar: utc), now: now, boundary: boundary)

        #expect(plan.slots.count == 7)
        #expect(plan.slots.first?.date == now)
        #expect(plan.slots.map(\.snapshot.completedToday) == [0, 1, 2, 3, 4, 5, 6])
        for (offset, slot) in plan.slots.enumerated().dropFirst() {
            #expect(slot.date == day(offset), "slot \(offset) is dated at its own midnight")
        }
    }

    @Test("Days already over are dropped; the current day is slot 0 at now")
    func pastDaysAreDropped() {
        let boundary = DayBoundary(calendar: utc, startHour: 0)
        let now = day(2, 9)
        let plan = WidgetTimelinePlan.make(series: series(from: d0, calendar: utc), now: now, boundary: boundary)

        #expect(plan.slots.map(\.snapshot.completedToday) == [2, 3, 4, 5, 6])
        #expect(plan.slots.first?.date == now)
        #expect(plan.slots[1].date == day(3))
    }

    @Test("Past the horizon: a single slot with the latest day, never the first day's ticks")
    func beyondHorizonShowsLatestDay() {
        let boundary = DayBoundary(calendar: utc, startHour: 0)
        let now = day(9, 8)
        let plan = WidgetTimelinePlan.make(series: series(from: d0, calendar: utc), now: now, boundary: boundary)

        #expect(plan.slots.count == 1)
        #expect(plan.slots.first?.date == now)
        #expect(plan.slots.first?.snapshot.completedToday == 6)
    }

    @Test("An empty series still yields one slot, the empty snapshot, at now")
    func emptySeriesYieldsOneEmptySlot() {
        let boundary = DayBoundary(calendar: utc, startHour: 0)
        let now = day(0, 12)
        let plan = WidgetTimelinePlan.make(series: .empty, now: now, boundary: boundary)

        #expect(plan.slots.count == 1)
        #expect(plan.slots.first?.date == now)
        #expect(plan.slots.first?.snapshot.today.isEmpty == true)
        #expect(plan.slots.first?.snapshot.totalDueToday == 0)
    }

    @Test("Under a 4 AM day start, 02:00 is still yesterday and the page turns at 04:00")
    func dayStartHourShiftsTheSwitch() {
        let boundary = DayBoundary(calendar: utc, startHour: 4)
        let now = day(1, 2)
        let plan = WidgetTimelinePlan.make(series: series(from: d0, calendar: utc), now: now, boundary: boundary)

        #expect(plan.slots.map(\.snapshot.completedToday) == [0, 1, 2, 3, 4, 5, 6])
        #expect(plan.slots.first?.date == now)
        #expect(plan.slots[1].date == day(1, 4))
        #expect(plan.slots[2].date == day(2, 4))
    }

    @Test("The reload lands one hour after now — the safety net the providers always had")
    func reloadAfterIsOneHour() {
        let boundary = DayBoundary(calendar: utc, startHour: 0)
        let now = day(0, 10, 30)
        let plan = WidgetTimelinePlan.make(series: series(from: d0, calendar: utc), now: now, boundary: boundary)

        #expect(plan.reloadAfter == utc.date(byAdding: .hour, value: 1, to: now))
    }

    // MARK: - Invariants

    /// Instants that exist in their zone, chosen around the transitions
    /// `TestCalendar` documents: the evening before, the small hours
    /// after, and a plain day for contrast.
    private var probes: [(Calendar, Date)] {
        let p = TestCalendar.paris
        let h = TestCalendar.havana
        return [
            (utc, TestCalendar.instant(utc, 2026, 4, 13, 10)),
            (p, TestCalendar.instant(p, 2026, 3, 28, 22)),
            (p, TestCalendar.instant(p, 2026, 3, 29, 1, 30)),
            (p, TestCalendar.instant(p, 2026, 3, 29, 3, 30)),
            (p, TestCalendar.instant(p, 2026, 10, 24, 23)),
            (p, TestCalendar.instant(p, 2026, 10, 25, 1, 30)),
            (p, TestCalendar.instant(p, 2026, 10, 25, 3, 30)),
            (h, TestCalendar.instant(h, 2026, 3, 7, 23, 30)),
            (h, TestCalendar.instant(h, 2026, 3, 8, 1, 30)),
            (h, TestCalendar.instant(h, 2026, 3, 8, 12)),
        ]
    }

    @Test("Across zones, day starts and DST edges: every slot begins its own logical day and sits at the rollover after the one before")
    func slotsAlignWithRolloversEverywhere() {
        for (calendar, now) in probes {
            for startHour in [0, 4] {
                let boundary = DayBoundary(calendar: calendar, startHour: startHour)
                let first = boundary.startOfDay(for: now)
                let plan = WidgetTimelinePlan.make(
                    series: series(from: first, calendar: calendar),
                    now: now,
                    boundary: boundary
                )
                let label = "\(calendar.timeZone.identifier) start \(startHour) at \(now)"

                #expect(plan.slots.count == 7, "\(label): every day gets a slot")
                #expect(plan.slots.first?.date == now, "\(label): slot 0 is now")
                for slot in plan.slots {
                    #expect(
                        boundary.startOfDay(for: slot.date) == slot.snapshot.logicalDay,
                        "\(label): slot at \(slot.date) shows its own day"
                    )
                }
                for (previous, next) in zip(plan.slots, plan.slots.dropFirst()) {
                    #expect(next.date > previous.date, "\(label): ascending")
                    #expect(
                        next.date == boundary.nextRollover(after: previous.date),
                        "\(label): \(next.date) is the rollover after \(previous.date)"
                    )
                }
            }
        }
    }
}
