import AppIntents
import Foundation

/// Configuration intent for the lock-screen widgets that show a
/// single habit. The user picks the habit via the widget-edit
/// flow; the provider reads the intent's `habit` parameter and
/// renders its state.
///
/// `habit` is optional because a newly-added widget has no habit
/// picked yet — the entry falls back to a "Pick a habit" nudge.
struct PickHabitIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pick Habit"
    static let description = IntentDescription(
        "Pick which habit this widget shows."
    )

    @Parameter(title: "Habit")
    var habit: HabitEntity?

    init() {}

    init(habit: HabitEntity?) {
        self.habit = habit
    }
}
