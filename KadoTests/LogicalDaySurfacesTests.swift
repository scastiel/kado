import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Kado
import KadoCore

/// The surfaces beyond Today that have to agree about which day it is:
/// App Intents (Siri and the notification banner share their core),
/// the widget snapshot, and — by deliberate exception — reminder
/// scheduling, which stays on wall-clock time.
@Suite("Logical day across surfaces")
@MainActor
struct LogicalDaySurfacesTests {
    private var calendar: Calendar { TestCalendar.utc }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    // MARK: - App Intents

    @Test("CompleteHabitIntent before the rollover completes the previous day")
    func intentCompletesTheLogicalDay() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        let outcome = try CompleteHabitIntent.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: calendar,
            now: boundary.loggingInstant(for: atTwoAM)
        )

        #expect(outcome == .toggledOn)
        let stored = try #require(habit.completions?.first)
        #expect(calendar.startOfDay(for: stored.date) == TestCalendar.instant(calendar, 2026, 8, 10))
    }

    @Test("LogHabitValueIntent before the rollover logs to the previous day")
    func valueIntentLogsToTheLogicalDay() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Water", frequency: .daily, type: .counter(target: 8))
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        _ = try LogHabitValueIntent.apply(
            habitID: habit.id,
            value: 5,
            in: container.mainContext,
            calendar: calendar,
            now: boundary.loggingInstant(for: atTwoAM)
        )

        let stored = try #require(habit.completions?.first)
        #expect(stored.value == 5.0)
        #expect(calendar.startOfDay(for: stored.date) == TestCalendar.instant(calendar, 2026, 8, 10))
    }

    // MARK: - Widget snapshot

    @Test("The snapshot's trailing matrix day is the logical day")
    func snapshotTrailingDayFollowsTheBoundary() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: boundary.startOfDay(for: atTwoAM),
            calendar: calendar,
            scoreCalculator: DefaultHabitScoreCalculator(calendar: calendar),
            streakCalculator: DefaultStreakCalculator(calendar: calendar),
            frequencyEvaluator: DefaultFrequencyEvaluator(calendar: calendar)
        )

        #expect(snapshot.matrixDays.last == TestCalendar.instant(calendar, 2026, 8, 10))
    }

    /// A completion logged at 1am has to show as done in the widget,
    /// not as an untouched row for a day the user thinks is over.
    @Test("A habit logged at 02:00 reads as complete in the widget snapshot")
    func snapshotReflectsAPreRolloverCompletion() throws {
        let container = try makeContainer()
        let habit = HabitRecord(name: "Meditate", frequency: .daily, type: .binary)
        container.mainContext.insert(habit)
        try container.mainContext.save()

        let boundary = DayBoundary(calendar: calendar, startHour: 4)
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)
        CompletionToggler(calendar: calendar).toggleToday(
            for: habit,
            on: boundary.loggingInstant(for: atTwoAM),
            in: container.mainContext
        )
        try container.mainContext.save()

        let snapshot = WidgetSnapshotBuilder.build(
            from: container.mainContext,
            asOf: boundary.startOfDay(for: atTwoAM),
            calendar: calendar,
            scoreCalculator: DefaultHabitScoreCalculator(calendar: calendar),
            streakCalculator: DefaultStreakCalculator(calendar: calendar),
            frequencyEvaluator: DefaultFrequencyEvaluator(calendar: calendar)
        )

        #expect(snapshot.completedToday == 1)
        #expect(snapshot.today.first?.status == .complete)
    }

    // MARK: - Reminders stay on wall-clock time

    /// Deliberate exception, decided in the plan: a 9 PM reminder means
    /// 9 PM regardless of where the day boundary sits. This test exists
    /// so a future "make everything consistent" refactor has to argue
    /// with a red bar rather than silently shifting people's alarms.
    @Test("Reminders schedule on wall-clock days regardless of the day boundary")
    func remindersIgnoreTheDayBoundary() async throws {
        // Hoisted: the scheduler's `now` closure is @Sendable and
        // can't reach back into this MainActor-isolated suite.
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)
        func scheduledIdentifiers() async -> [String] {
            let center = FakeUserNotificationCenter()
            let scheduler = DefaultNotificationScheduler(
                center: center,
                frequencyEvaluator: DefaultFrequencyEvaluator(calendar: calendar),
                streakCalculator: DefaultStreakCalculator(calendar: calendar),
                calendar: calendar,
                now: { atTwoAM }
            )
            let habit = Habit(
                name: "Meditate",
                frequency: .daily,
                type: .binary,
                createdAt: TestCalendar.instant(calendar, 2026, 7, 1),
                remindersEnabled: true,
                reminderHour: 21,
                reminderMinute: 0
            )
            await scheduler.rescheduleAll(habits: [habit], completions: [])
            return await center.pendingNotificationRequests().map(\.identifier).sorted()
        }

        // The scheduler reads no day-boundary state at all, so the
        // window it produces at 02:00 starts on the wall-clock day —
        // Aug 11, not the logical Aug 10 that Today is showing.
        let identifiers = await scheduledIdentifiers()

        #expect(identifiers.contains { $0.hasSuffix("2026-08-11") })
        #expect(!identifiers.contains { $0.hasSuffix("2026-08-10") })
    }

    @Test("A reminder keeps its wall-clock hour under a 4 AM day boundary")
    func remindersKeepTheirHour() async throws {
        let atTwoAM = TestCalendar.instant(calendar, 2026, 8, 11, 2, 0)
        let center = FakeUserNotificationCenter()
        let scheduler = DefaultNotificationScheduler(
            center: center,
            frequencyEvaluator: DefaultFrequencyEvaluator(calendar: calendar),
            streakCalculator: DefaultStreakCalculator(calendar: calendar),
            calendar: calendar,
            now: { atTwoAM }
        )
        let habit = Habit(
            name: "Meditate",
            frequency: .daily,
            type: .binary,
            createdAt: TestCalendar.instant(calendar, 2026, 7, 1),
            remindersEnabled: true,
            reminderHour: 21,
            reminderMinute: 30
        )

        await scheduler.rescheduleAll(habits: [habit], completions: [])

        let requests = await center.pendingNotificationRequests()
        let trigger = try #require(requests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 21)
        #expect(trigger.dateComponents.minute == 30)
    }
}
