import Foundation
import Testing
import UserNotifications
@testable import Kado
import KadoCore

@Suite("DefaultNotificationScheduler")
@MainActor
struct DefaultNotificationSchedulerTests {
    /// Convenience: build a scheduler + fake center anchored to
    /// `TestCalendar`'s Monday reference date so every test reasons
    /// about the same "today."
    private func makeScheduler(now: Date = TestCalendar.day(0))
        -> (DefaultNotificationScheduler, FakeUserNotificationCenter)
    {
        let center = FakeUserNotificationCenter()
        let scheduler = DefaultNotificationScheduler(
            center: center,
            frequencyEvaluator: DefaultFrequencyEvaluator(calendar: TestCalendar.utc),
            streakCalculator: DefaultStreakCalculator(calendar: TestCalendar.utc),
            calendar: TestCalendar.utc,
            now: { now }
        )
        return (scheduler, center)
    }

    private func makeHabit(
        frequency: Frequency = .daily,
        createdOffset: Int = -30,
        reminderHour: Int = 9,
        reminderMinute: Int = 0,
        remindersEnabled: Bool = true,
        archivedOffset: Int? = nil
    ) -> Habit {
        Habit(
            name: "Meditate",
            frequency: frequency,
            type: .binary,
            createdAt: TestCalendar.day(createdOffset),
            archivedAt: archivedOffset.map { TestCalendar.day($0) },
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }

    // MARK: - Opt-in gating

    @Test("Reminders off yields no pending requests")
    func remindersOff() async {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(remindersEnabled: false)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.isEmpty)
    }

    // MARK: - Frequency coverage

    @Test("Daily habit yields 7 requests spanning the next 7 days")
    func dailyWindow() async {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.count == 7)
    }

    @Test("specificDays(Mon/Wed/Fri) yields three requests in a typical week")
    func specificDaysWindow() async {
        let (scheduler, center) = makeScheduler()
        let days: Set<Weekday> = [.monday, .wednesday, .friday]
        let habit = makeHabit(frequency: .specificDays(days))
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.count == 3)
    }

    @Test("everyNDays(3) anchored to createdAt produces correct offsets")
    func everyNDaysWindow() async {
        let (scheduler, center) = makeScheduler()
        // createdAt at day(-6). In the 7-day window 0..6, due when
        // (dayOffset + 6) % 3 == 0 → days 0, 3, 6.
        let habit = makeHabit(frequency: .everyNDays(3), createdOffset: -6)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.count == 3)
    }

    @Test("daysPerWeek(3) stays silent while the sliding window holds three completions")
    func daysPerWeekSaturated() async {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daysPerWeek(3))
        // Three completions all on today — every 7-day window
        // ending on a day in [d0, d6] contains today, so
        // countInWindow == 3 for each day evaluated and no
        // reminder fires in the window.
        let completions: [Completion] = (0..<3).map { _ in
            Completion(habitID: habit.id, date: TestCalendar.day(0))
        }
        await scheduler.rescheduleAll(habits: [habit], completions: completions)
        #expect(center.pending.isEmpty)
    }

    // MARK: - Lifecycle clearing

    @Test("Archived habits drop their pending requests")
    func archivedHabitCleared() async {
        let (scheduler, center) = makeScheduler()
        let active = makeHabit()
        await scheduler.rescheduleAll(habits: [active], completions: [])
        #expect(center.pending.count == 7)

        let archived = makeHabit(archivedOffset: -1)
        await scheduler.rescheduleAll(habits: [archived], completions: [])
        #expect(center.pending.isEmpty)
    }

    @Test("Toggling reminders off drops existing pending requests")
    func toggleOffCleared() async {
        let (scheduler, center) = makeScheduler()
        var habit = makeHabit()
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.count == 7)

        habit.remindersEnabled = false
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        #expect(center.pending.isEmpty)
    }

    @Test("cancel(habitID:) removes requests scoped to that habit")
    func cancelScopedRemoval() async {
        let (scheduler, center) = makeScheduler()
        let a = makeHabit()
        let b = Habit(
            id: UUID(),
            name: "Read",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.day(-30),
            remindersEnabled: true,
            reminderHour: 21
        )
        await scheduler.rescheduleAll(habits: [a, b], completions: [])
        #expect(center.pending.count == 14)

        await scheduler.cancel(habitID: a.id)
        #expect(center.pending.count == 7)
        #expect(center.pending.allSatisfy { $0.identifier.contains(b.id.uuidString) })
    }

    // MARK: - Request shape

    @Test("Request identifier encodes habit id and ISO yyyy-MM-dd day")
    func identifierFormat() async throws {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        let first = try #require(center.pending.first)
        let expectedPrefix = "kado.reminder.\(habit.id.uuidString)."
        #expect(first.identifier.hasPrefix(expectedPrefix))
        let suffix = String(first.identifier.dropFirst(expectedPrefix.count))
        // ISO yyyy-MM-dd is 10 chars with two dashes
        #expect(suffix.count == 10)
        #expect(suffix.filter { $0 == "-" }.count == 2)
    }

    @Test("Content carries category identifier and habit id in userInfo")
    func contentMetadata() async throws {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        let first = try #require(center.pending.first)
        #expect(first.content.categoryIdentifier == "kado.habit")
        let storedID = first.content.userInfo["habitID"] as? String
        #expect(storedID == habit.id.uuidString)
    }

    @Test("Body shows name only when streak is zero")
    func bodyWithoutStreak() async throws {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        let first = try #require(center.pending.first)
        #expect(first.content.title == "Meditate")
        #expect(first.content.body == "Meditate")
    }

    @Test("Body shows '<Name> — N day streak' when streak is positive")
    func bodyWithStreak() async throws {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily)
        let completions: [Completion] = (-4...(-1)).map {
            Completion(habitID: habit.id, date: TestCalendar.day($0))
        }
        await scheduler.rescheduleAll(habits: [habit], completions: completions)
        let first = try #require(center.pending.first)
        #expect(first.content.body.hasPrefix("Meditate — "))
        #expect(first.content.body.contains("day streak"))
    }

    @Test("Trigger fires at the configured hour and minute")
    func triggerTime() async throws {
        let (scheduler, center) = makeScheduler()
        let habit = makeHabit(frequency: .daily, reminderHour: 8, reminderMinute: 30)
        await scheduler.rescheduleAll(habits: [habit], completions: [])
        let first = try #require(center.pending.first)
        let trigger = try #require(first.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 8)
        #expect(trigger.dateComponents.minute == 30)
        #expect(trigger.repeats == false)
    }

    // MARK: - Authorization

    @Test("requestAuthorizationIfNeeded asks when status is notDetermined")
    func requestAuthWhenUndetermined() async {
        let (scheduler, center) = makeScheduler()
        center.stubbedAuthorizationStatus = .notDetermined
        center.stubbedStatusAfterRequest = .authorized
        let result = await scheduler.requestAuthorizationIfNeeded()
        #expect(center.authorizationRequests.count == 1)
        #expect(result == .authorized)
    }

    @Test("requestAuthorizationIfNeeded is a no-op once decided")
    func requestAuthAlreadyDenied() async {
        let (scheduler, center) = makeScheduler()
        center.stubbedAuthorizationStatus = .denied
        let result = await scheduler.requestAuthorizationIfNeeded()
        #expect(center.authorizationRequests.isEmpty)
        #expect(result == .denied)
    }
}
