import FoundationModels
import Foundation

@Generable
enum Schedule {
    @Generable struct Daily {}
    @Generable struct DaysPerWeek { @Guide(.range(1...6)) var days: Int }
    @Generable struct SpecificDays {
        @Guide(description: "English weekday names", .count(1...7))
        var weekdays: [Weekday]
    }
    @Generable struct EveryNDays { @Guide(description: "'every couple of days' = 2, 'every other day' = 2", .range(2...30)) var interval: Int }
    case daily(Daily)
    case daysPerWeek(DaysPerWeek)
    case specificDays(SpecificDays)
    case everyNDays(EveryNDays)
}

@Generable enum Weekday { case monday, tuesday, wednesday, thursday, friday, saturday, sunday }

@Generable
struct HabitDraft {
    @Guide(description: "Whether the sentence describes a personal habit at all. False for harmful, nonsensical or non-habit requests.")
    var isHabit: Bool
    @Guide(description: "On which days the habit is due. Counts per WEEK and intervals of days belong here, never in measure.")
    var schedule: Schedule
    @Guide(description: "What counts as done on a due day. done = simply do it once. timesPerDay = an explicit number of repetitions within one day, e.g. 'twice a day', '8 glasses'. minutes = an explicit duration. avoid = something to stop, quit or not do.", .anyOf(["done", "timesPerDay", "minutes", "avoid"]))
    var measure: String
    @Guide(description: "Only for timesPerDay: the number of times within one day.")
    var timesPerDay: Int?
    @Guide(description: "Only for minutes: the duration in minutes.")
    var minutes: Int?
    @Guide(description: "Short habit name, 1-3 words, written in the same language as the sentence. Do not translate.")
    var name: String
    @Guide(.anyOf(["figure.walk","figure.run","dumbbell.fill","figure.yoga","bicycle","figure.pool.swim","figure.mind.and.body","leaf.fill","moon.stars.fill","bed.double.fill","drop.fill","cup.and.saucer.fill","fork.knife","carrot.fill","book.fill","pencil","music.note","heart.fill","pills.fill","nosign","sparkles","circle"]))
    var icon: String
}

let instructions = """
You turn one sentence describing a habit the user wants to build or break into a structured habit. \
Never invent details the sentence does not imply. When no frequency is stated, the schedule is daily.
Examples:
"Go for a run every couple of days" -> schedule everyNDays 2, measure done, name "Run".
"Read three times a week" -> schedule daysPerWeek 3, measure done, name "Read".
"Floss twice a day" -> schedule daily, measure timesPerDay 2, name "Floss".
"Gym on Mondays and Thursdays" -> schedule specificDays [monday, thursday], measure done.
"Stop smoking" -> schedule daily, measure avoid, name "No smoking".
"""

let m = ProcessInfo.processInfo.environment["PERMISSIVE"] != nil ? SystemLanguageModel(guardrails: .permissiveContentTransformations) : SystemLanguageModel.default
for s in CommandLine.arguments.dropFirst() {
    let session = LanguageModelSession(model: m, instructions: instructions)
    let t0 = Date()
    do {
        let r = try await session.respond(to: s, generating: HabitDraft.self)
        print(String(format: "%.1fs", Date().timeIntervalSince(t0)), "|", s, "=>", r.content)
    } catch { print("ERR", s, error) }
}
