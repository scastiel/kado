import Foundation
import Testing
@testable import Kado
import KadoCore

@Suite("GetHabitStatsIntent")
@MainActor
struct GetHabitStatsIntentTests {
    private func habit(
        name: String = "Meditate",
        streak: Int = 0,
        best: Int = 0,
        score: Double = 0
    ) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: name,
            color: .blue,
            icon: "checkmark",
            typeKind: .binary,
            target: nil,
            currentStreak: streak,
            bestStreak: best,
            currentScore: score
        )
    }

    private func todayRow(
        for habit: WidgetHabit,
        status: WidgetStatus
    ) -> WidgetTodayRow {
        WidgetTodayRow(
            habit: habit,
            status: status,
            progress: status == .complete ? 1 : 0,
            valueToday: status == .complete ? 1 : nil,
            streak: habit.currentStreak,
            scorePercent: Int((habit.currentScore * 100).rounded())
        )
    }

    @Test("Dialog reports active streak, score, and done-today status")
    func activeStreakDoneToday() {
        let h = habit(name: "Meditate", streak: 7, score: 0.42)
        let dialog = GetHabitStatsIntent.dialog(
            habit: h,
            todayRow: todayRow(for: h, status: .complete)
        )
        let text = String(describing: dialog)
        #expect(text.contains("Meditate"))
        #expect(text.contains("7"), "Streak should appear in spoken text")
        #expect(text.contains("42"), "Score percent should appear in spoken text")
        #expect(text.localizedCaseInsensitiveContains("done"))
    }

    @Test("Dialog reports not-done-today when status is .none")
    func activeStreakNotDone() {
        let h = habit(name: "Meditate", streak: 7, score: 0.42)
        let dialog = GetHabitStatsIntent.dialog(
            habit: h,
            todayRow: todayRow(for: h, status: .none)
        )
        let text = String(describing: dialog)
        #expect(text.contains("Meditate"))
        #expect(text.contains("7"))
        #expect(text.localizedCaseInsensitiveContains("not done"))
    }

    @Test("Dialog handles zero streak with no completions")
    func noStreakNoCompletions() {
        let h = habit(name: "Meditate", streak: 0, score: 0)
        let dialog = GetHabitStatsIntent.dialog(habit: h, todayRow: nil)
        let text = String(describing: dialog)
        #expect(text.contains("Meditate"))
        #expect(text.localizedCaseInsensitiveContains("no"), "Should mention no streak")
    }

    @Test("Score is formatted as integer percent 0-100")
    func scoreFormattedAsPercent() {
        let h = habit(name: "Read", streak: 3, score: 0.876)
        let dialog = GetHabitStatsIntent.dialog(
            habit: h,
            todayRow: todayRow(for: h, status: .complete)
        )
        let text = String(describing: dialog)
        #expect(text.contains("88"), "Score 0.876 should round to 88%")
        #expect(!text.contains("0.876"))
    }

    @Test("Habit not in snapshot returns an empty-snapshot dialog")
    func missingHabitDialog() {
        let dialog = GetHabitStatsIntent.missingHabitDialog(habitName: "Meditate")
        let text = String(describing: dialog)
        #expect(text.contains("Meditate"))
    }
}
