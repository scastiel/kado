import Foundation
import SwiftData
import KadoCore

/// Seeds a `ModelContext` with a realistic demo dataset covering every
/// `HabitType` variant and every `Frequency` variant, plus ~30 days of
/// historical completions.
/// Used by the in-app dev mode sandbox and by SwiftUI previews.
@MainActor
enum DevModeSeed {
    /// Completions per habit in the seed dataset (every other day for
    /// 30 days from today). Kept as a constant so tests can reference
    /// it without duplicating arithmetic.
    static let completionsPerHabit = 15

    /// Day offsets (in days ago) for the `.daysPerWeek` habit. Five of
    /// every seven days, plus two extra days.
    ///
    /// The every-other-day default used by the other habits never fills
    /// a five-per-week quota, so the interesting states never appear.
    /// This pattern saturates the rolling window — which is what makes
    /// rest days read as "not scheduled" rather than "missed", and what
    /// makes the two bonus days render as off-schedule completions.
    static let daysPerWeekOffsets: [Int] = {
        let scheduled = (1...35).filter { $0 % 7 != 0 && $0 % 7 != 6 }
        return (scheduled + [6, 20]).sorted()
    }()

    /// Day offsets (in days ago) for the `.everyNDays(2)` habit: on
    /// cadence for the most part, but done a day early four times.
    ///
    /// The early days are the whole point. The cycle re-anchors on each
    /// completion, so doing the habit early moves the next due day
    /// instead of leaving a phantom miss on the day a fixed grid from
    /// `createdAt` would have insisted on. Seeded flat on cadence, the
    /// habit would render identically either way and dev mode would
    /// show nothing.
    ///
    /// Starts on the creation day (30) so the habit is due on the day
    /// it was created, and ends two days ago (2) so it is due — and
    /// outstanding — today. Both ends are load-bearing, so the values
    /// are written out rather than derived from a gap array whose sum
    /// would have to stay exactly 28 for the last one to land on 2.
    /// `PreviewContainerTests` pins both.
    static let everyNDaysOffsets: [Int] = [
        30, 28, 26, 25, 23, 21, 19, 18, 16, 14, 12, 11, 9, 7, 5, 4, 2,
    ]

    static func seed(into context: ModelContext, calendar: Calendar = .current) {
        // Through the boundary so seeded history lines up with what
        // Today renders — otherwise dev mode is misleading precisely
        // when you're using it to exercise the day-start setting.
        let today = DayStartDefaults.boundary(calendar: calendar).startOfDay(for: .now)
        let names = SeedNames.forCurrentLocale()

        let habits: [HabitRecord] = [
            HabitRecord(
                name: names.meditation,
                frequency: .daily,
                type: .binary,
                createdAt: calendar.date(byAdding: .day, value: -45, to: today)!,
                color: .purple,
                icon: "figure.mind.and.body"
            ),
            HabitRecord(
                name: names.gym,
                frequency: .specificDays([.monday, .wednesday, .friday]),
                type: .binary,
                createdAt: calendar.date(byAdding: .day, value: -60, to: today)!,
                color: .orange,
                icon: "dumbbell.fill"
            ),
            HabitRecord(
                name: names.water,
                frequency: .daily,
                type: .counter(target: 8),
                createdAt: calendar.date(byAdding: .day, value: -30, to: today)!,
                color: .blue,
                icon: "drop.fill"
            ),
            HabitRecord(
                name: names.read,
                frequency: .daily,
                type: .timer(targetSeconds: 1800),
                createdAt: calendar.date(byAdding: .day, value: -40, to: today)!,
                color: .mint,
                icon: "book.fill"
            ),
            HabitRecord(
                name: names.noSocialMedia,
                frequency: .daily,
                type: .negative,
                createdAt: calendar.date(byAdding: .day, value: -30, to: today)!,
                color: .red,
                icon: "flame.fill"
            ),
        ]

        let run = HabitRecord(
            name: names.run,
            frequency: .daysPerWeek(5),
            type: .binary,
            createdAt: calendar.date(byAdding: .day, value: -50, to: today)!,
            color: .green,
            icon: "figure.run"
        )

        let plants = HabitRecord(
            name: names.plants,
            frequency: .everyNDays(2),
            type: .binary,
            createdAt: calendar.date(byAdding: .day, value: -30, to: today)!,
            color: .teal,
            icon: "leaf.fill"
        )

        for habit in habits {
            context.insert(habit)
            // 15 completions per habit, every other day going back 29 days.
            for daysAgo in stride(from: 1, through: 29, by: 2) {
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                let value: Double = switch habit.type {
                case .counter: 6
                case .timer: 1500
                default: 1
                }
                let completion = CompletionRecord(date: date, value: value, habit: habit)
                context.insert(completion)
            }
        }

        context.insert(run)
        for daysAgo in daysPerWeekOffsets {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            context.insert(CompletionRecord(date: date, value: 1, habit: run))
        }

        context.insert(plants)
        for daysAgo in everyNDaysOffsets {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            context.insert(CompletionRecord(date: date, value: 1, habit: plants))
        }

        try? context.save()
    }

    private struct SeedNames {
        let meditation: String
        let gym: String
        let water: String
        let read: String
        let noSocialMedia: String
        let run: String
        let plants: String

        static func forCurrentLocale() -> SeedNames {
            switch Locale.current.language.languageCode?.identifier {
            case "fr":
                SeedNames(
                    meditation: "Méditation du matin",
                    gym: "Salle de sport",
                    water: "Boire de l'eau",
                    read: "Lecture",
                    noSocialMedia: "Pas de réseaux sociaux",
                    run: "Course à pied",
                    plants: "Arroser les plantes"
                )
            default:
                SeedNames(
                    meditation: "Morning meditation",
                    gym: "Gym",
                    water: "Drink water",
                    read: "Read",
                    noSocialMedia: "No social media",
                    run: "Running",
                    plants: "Water the plants"
                )
            }
        }
    }
}
