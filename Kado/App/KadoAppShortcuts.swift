import AppIntents
import KadoCore

/// Registers Kadō's user-facing `AppIntent`s with the system so
/// they appear in Shortcuts and can be triggered via Siri. Must
/// live in the main app target — iOS reads the provider from the
/// app's bundle, not from a linked framework.
///
struct KadoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Complete \(.applicationName) habit \(\.$habit)",
                "Mark \(\.$habit) as done in \(.applicationName)"
            ],
            shortTitle: "Complete Habit",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: LogHabitValueIntent(),
            // `value` is optional on the intent so we can refuse
            // binary / negative habits before prompting; the NLU
            // training pipeline rejects optional-param interpolation
            // in phrases. Keep phrases parameter-only on `habit`;
            // Siri prompts for the value at run-time.
            phrases: [
                "Log a value for \(\.$habit) in \(.applicationName)",
                "Log habit value in \(.applicationName)"
            ],
            shortTitle: "Log Habit Value",
            systemImageName: "number.circle"
        )
        AppShortcut(
            intent: GetHabitStatsIntent(),
            phrases: [
                "Stats for \(\.$habit) in \(.applicationName)",
                "\(.applicationName) stats for \(\.$habit)"
            ],
            shortTitle: "Get Habit Stats",
            systemImageName: "chart.bar"
        )
    }
}
