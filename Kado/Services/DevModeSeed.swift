import Foundation
import SwiftData
import KadoCore

/// Seeds a `ModelContext` with a realistic demo dataset covering each
/// `Frequency` and `HabitType` variant, plus ~30 days of historical
/// completions. Used by the in-app dev mode sandbox and by SwiftUI
/// previews.
@MainActor
enum DevModeSeed {
    /// Completions per habit in the seed dataset (every other day for
    /// 30 days from today). Kept as a constant so tests can reference
    /// it without duplicating arithmetic.
    static let completionsPerHabit = 15

    static func seed(into context: ModelContext, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: .now)
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

        try? context.save()
    }

    private struct SeedNames {
        let meditation: String
        let gym: String
        let water: String
        let read: String
        let noSocialMedia: String

        static func forCurrentLocale() -> SeedNames {
            switch Locale.current.language.languageCode?.identifier {
            case "fr":
                SeedNames(
                    meditation: "Méditation du matin",
                    gym: "Salle de sport",
                    water: "Boire de l'eau",
                    read: "Lecture",
                    noSocialMedia: "Pas de réseaux sociaux"
                )
            default:
                SeedNames(
                    meditation: "Morning meditation",
                    gym: "Gym",
                    water: "Drink water",
                    read: "Read",
                    noSocialMedia: "No social media"
                )
            }
        }
    }
}
