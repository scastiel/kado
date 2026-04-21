import AppIntents
import Foundation

/// Read-only Siri intent that speaks a one-sentence summary of a
/// habit's current state — streak, score, and whether today is
/// done. Reads from the App Group JSON snapshot instead of
/// SwiftData so it can run in any process without fighting
/// CloudKit for the store.
///
/// `openAppWhenRun = false` is the payoff of the snapshot design:
/// Siri can answer from a suspended app without foregrounding it.
public struct GetHabitStatsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Habit Stats"
    public static let description = IntentDescription(
        "Speak the current streak, score, and today's status for a habit."
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Habit")
    public var habit: HabitEntity

    public init() {}

    public init(habit: HabitEntity) {
        self.habit = habit
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = WidgetSnapshotStore.read()
        guard let widgetHabit = snapshot.habits.first(where: { $0.id == habit.id }) else {
            return .result(dialog: Self.missingHabitDialog(habitName: habit.name))
        }
        let todayRow = snapshot.today.first(where: { $0.habit.id == habit.id })
        return .result(dialog: Self.dialog(habit: widgetHabit, todayRow: todayRow))
    }

    /// Main dialog factory. `todayRow` is nil when the habit isn't
    /// due today (its presence in `snapshot.today` implies due).
    /// Kept to three sentence variants — one per done-today state —
    /// so each is a single localizable key with clean interpolations.
    public static func dialog(habit: WidgetHabit, todayRow: WidgetTodayRow?) -> IntentDialog {
        let percent = Int((habit.currentScore * 100).rounded())
        let streak = habit.currentStreak
        if streak == 0 {
            return IntentDialog("\(habit.name): no active streak. Score \(percent)%.")
        }
        if let row = todayRow, row.status == .complete {
            return IntentDialog("\(habit.name): \(streak)-day streak, score \(percent)%. Today is done.")
        } else {
            return IntentDialog("\(habit.name): \(streak)-day streak, score \(percent)%. Not done today yet.")
        }
    }

    /// Dialog used when the requested habit isn't in the snapshot —
    /// either archived, deleted, or the app has never built a
    /// snapshot yet (fresh install, Siri fired first).
    public static func missingHabitDialog(habitName: String) -> IntentDialog {
        IntentDialog("\(habitName) isn't in Kadō — open the app to set it up first.")
    }
}
