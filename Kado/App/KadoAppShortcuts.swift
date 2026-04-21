import AppIntents
import KadoCore

/// Registers Kadō's user-facing `AppIntent`s with the system so
/// they appear in Shortcuts and can be triggered via Siri. Must
/// live in the main app target — iOS reads the provider from the
/// app's bundle, not from a linked framework.
///
/// Additional intents (`LogHabitValueIntent`, `GetHabitStatsIntent`)
/// will be appended as they're built.
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
    }
}
