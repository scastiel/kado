#if DEBUG
import Foundation
import SwiftData
import KadoCore

/// The demo data the App Store screenshots are taken of.
///
/// Deliberately *not* `DevModeSeed`. That one exists to put every state
/// the app can be in on screen at once — a habit at 27%, a broken
/// streak, a negative habit slipped every other day — because that is
/// what makes a sandbox useful for finding bugs. It is the wrong data
/// to photograph: the first run of this pipeline led the listing with
/// a red "Slipped" row at 41%, which is an honest picture of the seed
/// and a misleading one of the app.
///
/// This is somebody who has been using Kadō for about four months and
/// is doing reasonably well: high scores, long streaks, and a scatter
/// of missed days, because a wall of perfect green would be the other
/// kind of lie. Every miss is at a fixed offset rather than random, so
/// two runs a week apart produce byte-identical history and a rerun
/// diffs to nothing.
///
/// `sortOrder` is set explicitly here, which `DevModeSeed` does not do
/// — every record it writes leaves the field at its `0` default, so
/// `@Query(sort: \.sortOrder)` hands back whatever order SQLite feels
/// like and the Today list reshuffles between runs. A screenshot set
/// cannot be reviewed if the rows move.
@MainActor
enum ScreenshotSeed {

    /// How far back the history runs. Long enough that the monthly
    /// calendar on the detail screen is full in every direction the
    /// month arrows can reach.
    private static let historyDays = 130

    static func seed(into context: ModelContext, calendar: Calendar = .current) {
        // Through the boundary, so the seeded history lines up with the
        // day Today renders — the same reason `DevModeSeed` does it.
        let today = DayStartDefaults.boundary(calendar: calendar).startOfDay(for: .now)
        let names = Names.forCurrentLocale()

        // 1 — Morning meditation. The hero: it leads the Today list, and
        // it is the habit the detail screenshot opens. Daily and binary,
        // so the calendar reads at a glance, and logged today so the
        // first row photographs in its completed state.
        add(
            HabitRecord(
                name: names.meditation,
                frequency: .daily,
                type: .binary,
                createdAt: day(-historyDays, from: today, calendar),
                color: .purple,
                icon: "figure.mind.and.body",
                sortOrder: 0
            ),
            to: context, on: today, calendar: calendar,
            // Misses kept outside the last three weeks, so the streak on
            // the detail card is a number worth photographing and the
            // calendar still shows that a real person missed some days.
            value: { daysAgo in
                guard daysAgo >= 21 && daysAgo % 17 == 3 else { return 1 }
                return nil
            }
        )

        // 2 — Read. A timer habit, left unlogged today so the row shows
        // its "+5m" affordance rather than another checkmark.
        add(
            HabitRecord(
                name: names.read,
                frequency: .daily,
                type: .timer(targetSeconds: 1800),
                createdAt: day(-115, from: today, calendar),
                color: .mint,
                icon: "book.fill",
                sortOrder: 1
            ),
            to: context, on: today, calendar: calendar,
            value: { daysAgo in
                if daysAgo == 0 { return nil }
                if daysAgo >= 14 && daysAgo % 11 == 5 { return nil }
                // Between twenty-five and forty minutes, cycling. A
                // column of identical 30:00 sessions reads as generated.
                return [1800, 2100, 1500, 2400, 1800, 1620][daysAgo % 6]
            }
        )

        // 3 — Drink water. A counter, part-way through today, so the
        // row's progress ring is caught mid-fill.
        add(
            HabitRecord(
                name: names.water,
                frequency: .daily,
                type: .counter(target: 8),
                createdAt: day(-98, from: today, calendar),
                color: .blue,
                icon: "drop.fill",
                sortOrder: 2
            ),
            to: context, on: today, calendar: calendar,
            value: { daysAgo in
                if daysAgo == 0 { return 5 }
                if daysAgo >= 16 && daysAgo % 13 == 4 { return nil }
                return [8, 8, 7, 9, 8, 6, 8][daysAgo % 7]
            }
        )

        // 4 — Running, four days a week. The frequency the score
        // algorithm handles most interestingly, and the one a streak
        // counter cannot describe at all.
        add(
            HabitRecord(
                name: names.run,
                frequency: .daysPerWeek(4),
                type: .binary,
                createdAt: day(-120, from: today, calendar),
                color: .green,
                icon: "figure.run",
                sortOrder: 3
            ),
            to: context, on: today, calendar: calendar,
            value: { daysAgo in
                // Four of every seven, at fixed positions in the week.
                [2, 5, 6].contains(daysAgo % 7) ? nil : 1
            }
        )

        // 5 — Gym, on named weekdays. Logged only on the days the
        // schedule asks for, so the calendar's rest days read as rest
        // rather than as misses.
        add(
            HabitRecord(
                name: names.gym,
                frequency: .specificDays([.monday, .wednesday, .friday]),
                type: .binary,
                createdAt: day(-historyDays, from: today, calendar),
                color: .orange,
                icon: "dumbbell.fill",
                sortOrder: 4
            ),
            to: context, on: today, calendar: calendar,
            value: { daysAgo in
                let date = day(-daysAgo, from: today, calendar)
                let weekday = calendar.component(.weekday, from: date)
                // Gregorian weekdays: Monday 2, Wednesday 4, Friday 6.
                guard [2, 4, 6].contains(weekday) else { return nil }
                return daysAgo >= 18 && daysAgo % 23 == 7 ? nil : 1
            }
        )

        // 6 — No social media. A negative habit, where a record means
        // the user *slipped*, so a good one has almost none. Seven in
        // four months, none of them recent.
        let slips: Set<Int> = [14, 21, 29, 40, 53, 65, 76]
        add(
            HabitRecord(
                name: names.noSocialMedia,
                frequency: .daily,
                type: .negative,
                createdAt: day(-88, from: today, calendar),
                color: .red,
                icon: "flame.fill",
                sortOrder: 5
            ),
            to: context, on: today, calendar: calendar,
            value: { daysAgo in slips.contains(daysAgo) ? 1 : nil }
        )

        try? context.save()
    }

    // MARK: - Writing

    /// Inserts the habit and walks `historyDays` back from today,
    /// asking `value` what happened on each one. `nil` means nothing
    /// was logged — which for a negative habit is the good answer.
    private static func add(
        _ habit: HabitRecord,
        to context: ModelContext,
        on today: Date,
        calendar: Calendar,
        value: (Int) -> Double?
    ) {
        context.insert(habit)
        let start = calendar.dateComponents([.day], from: habit.createdAt, to: today).day ?? 0
        for daysAgo in stride(from: min(start, historyDays), through: 0, by: -1) {
            guard let logged = value(daysAgo) else { continue }
            context.insert(
                CompletionRecord(
                    date: day(-daysAgo, from: today, calendar), value: logged, habit: habit
                )
            )
        }
    }

    /// Day arithmetic through `Calendar`, never through seconds: a
    /// "day" is 23 or 25 hours twice a year, and a seeded history that
    /// drifted across a DST boundary would put a completion on the
    /// wrong square of the calendar in exactly one screenshot.
    private static func day(_ offset: Int, from date: Date, _ calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }

    // MARK: - Names

    /// Translated in the same place and the same way `DevModeSeed` does
    /// it. The screenshot run pins the simulator's language, so this is
    /// what makes the French set actually French inside the pictures
    /// rather than only around them.
    private struct Names {
        let meditation: String
        let gym: String
        let water: String
        let read: String
        let noSocialMedia: String
        let run: String

        static func forCurrentLocale() -> Names {
            switch Locale.current.language.languageCode?.identifier {
            case "fr":
                Names(
                    meditation: "Méditation du matin",
                    gym: "Salle de sport",
                    water: "Boire de l'eau",
                    read: "Lecture",
                    noSocialMedia: "Pas de réseaux sociaux",
                    run: "Course à pied"
                )
            default:
                Names(
                    meditation: "Morning meditation",
                    gym: "Gym",
                    water: "Drink water",
                    read: "Read",
                    noSocialMedia: "No social media",
                    run: "Running"
                )
            }
        }
    }
}
#endif
