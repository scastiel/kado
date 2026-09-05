import Foundation
import SwiftData
import Testing
@testable import Kado
import KadoCore

/// Guards the dataset the App Store screenshots are taken of.
///
/// This is not a test of the app; it is a test of the marketing. The
/// first run of the screenshot pipeline led the listing with a red
/// "Slipped" row at 41% — a fair picture of `DevModeSeed`, which puts
/// every state on screen at once, and a misleading picture of Kadō.
/// `ScreenshotSeed` exists to be the other thing, and nothing else in
/// the suite would notice if it drifted back: the scores here are read
/// by a person looking at a PNG weeks later, if at all.
@Suite("ScreenshotSeed")
@MainActor
struct ScreenshotSeedTests {

    /// Seeds an in-memory store and hands the records to `body`.
    ///
    /// A closure rather than a return value on purpose: the records are
    /// managed objects, and returning them lets the container that
    /// vended them go out of scope with them. Reading one afterwards
    /// traps inside SwiftData with "this model instance was destroyed",
    /// which is the same shape as issue #63 and just as confusing the
    /// second time.
    private func withSeeded<T>(
        calendar: Calendar = TestCalendar.utc,
        _ body: ([HabitRecord]) throws -> T
    ) throws -> T {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: KadoMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        ScreenshotSeed.seed(into: context, calendar: calendar)
        let habits = try context.fetch(
            FetchDescriptor<HabitRecord>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        return try withExtendedLifetime(container) { try body(habits) }
    }

    @Test("Every habit has a distinct sortOrder, so the Today list can't reshuffle")
    func sortOrderIsExplicitAndDistinct() throws {
        try withSeeded { habits in
            #expect(habits.count == 6)
            // 0...5 exactly: a duplicate would leave the order up to
            // SQLite, which is what `DevModeSeed` does and why its list
            // moves between runs.
            #expect(habits.map(\.sortOrder) == Array(0..<habits.count))
        }
    }

    @Test("Every habit type and every frequency shape is represented")
    func coversTheProductsRange() throws {
        try withSeeded { habits in
            let types = Set(habits.map(\.type))
            #expect(types.contains(.binary))
            #expect(types.contains(.negative))
            #expect(types.contains { if case .counter = $0 { true } else { false } })
            #expect(types.contains { if case .timer = $0 { true } else { false } })

            let frequencies = habits.map(\.frequency)
            #expect(frequencies.contains(.daily))
            #expect(frequencies.contains { if case .daysPerWeek = $0 { true } else { false } })
            #expect(frequencies.contains { if case .specificDays = $0 { true } else { false } })
        }
    }

    /// The reason the seed exists. A listing whose hero screenshot shows
    /// a habit at 41% is selling the opposite of what the score is for.
    @Test("Every habit scores well enough to photograph")
    func scoresAreWorthShowing() throws {
        try withSeeded { habits in
            for habit in habits {
                let score = Self.score(of: habit)
                #expect(
                    score > 0.7,
                    """
                    \(habit.name) scores \(Int(score * 100))%, \
                    which is not a number to lead a listing with
                    """
                )
            }
        }
    }

    /// …and equally, not a wall of perfect green. A set where nothing
    /// was ever missed reads as a mockup, and the calendar on the
    /// detail screenshot would have nothing in it but filled squares.
    @Test("But nobody is perfect")
    func historyContainsMissedDays() throws {
        try withSeeded { habits in
            #expect(habits.map(Self.score).allSatisfy { $0 < 1.0 })
        }
    }

    /// The score of one seeded habit, as the app would compute it.
    ///
    /// Pinned to the same calendar the seed was written with. Leaving
    /// the calculator on `.current` scores UTC-midnight completions
    /// against local day boundaries, which slides every one of them
    /// onto the previous day — harmless for a daily habit and fatal for
    /// the Mon/Wed/Fri one, whose completions then all land on days its
    /// schedule never asked for. It scored 0%, and the seed was fine.
    private static func score(of habit: HabitRecord) -> Double {
        DefaultHabitScoreCalculator(calendar: TestCalendar.utc).currentScore(
            for: habit.snapshot,
            completions: (habit.completions ?? []).compactMap(\.snapshot),
            asOf: TestCalendar.utc.startOfDay(for: .now)
        )
    }

    /// The hero. `ScreenshotTests` taps the first Today row to reach the
    /// detail screen, and the first row is whichever habit sorts first —
    /// so which habit that is belongs in a test, not in a comment.
    @Test("The first habit is the daily binary one the detail shot opens")
    func theFirstHabitIsTheHero() throws {
        try withSeeded { habits in
            let hero = try #require(habits.first)
            #expect(hero.frequency == .daily)
            #expect(hero.type == .binary)
            // Logged today, so the Today shot catches the row filled
            // rather than waiting to be tapped.
            let today = TestCalendar.utc.startOfDay(for: .now)
            let loggedToday = (hero.completions ?? []).contains {
                TestCalendar.utc.isDate($0.date, inSameDayAs: today)
            }
            #expect(loggedToday)
        }
    }

    /// A negative habit records *slips*, so a good one has almost none.
    /// Seeding it like a positive habit is the specific mistake that
    /// produced the 41% first draft.
    @Test("The negative habit has few slips, and none of them recent")
    func theNegativeHabitIsMostlyClean() throws {
        try withSeeded { habits in
            let negative = try #require(habits.first { $0.type == .negative })
            let slips = negative.completions ?? []
            #expect(slips.count <= 10)

            let today = TestCalendar.utc.startOfDay(for: .now)
            let mostRecent = slips.map(\.date).max()
            let daysSince = mostRecent.flatMap {
                TestCalendar.utc.dateComponents([.day], from: $0, to: today).day
            }
            #expect((daysSince ?? .max) >= 7)
        }
    }

    /// Two runs a week apart must produce the same history, or a
    /// re-capture diffs as noise and nobody reviews it.
    @Test("Seeding twice from the same day produces identical history")
    func isDeterministic() throws {
        let first = try withSeeded { $0.map(Self.fingerprint) }
        let second = try withSeeded { $0.map(Self.fingerprint) }
        #expect(first == second)
    }

    private static func fingerprint(_ habit: HabitRecord) -> String {
        let completions = (habit.completions ?? [])
            .sorted { $0.date < $1.date }
            .map { "\($0.date.timeIntervalSince1970):\($0.value)" }
            .joined(separator: ",")
        return "\(habit.sortOrder)|\(habit.name)|\(completions)"
    }
}
