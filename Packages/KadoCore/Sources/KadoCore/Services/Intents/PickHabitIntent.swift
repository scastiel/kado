import AppIntents
import Foundation

/// Configuration intent for the lock-screen widgets that show a
/// single habit. The user picks the habit via the widget-edit
/// flow; the provider reads the intent's `habit` parameter and
/// renders its state.
///
/// `habit` is optional because a newly-added widget has no habit
/// picked yet — the entry falls back to a "Pick a habit" nudge.
public struct PickHabitIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "Pick Habit"
    public static let description = IntentDescription(
        "Pick which habit this widget shows."
    )

    @Parameter(title: "Habit")
    public var habit: HabitEntity?

    public init() {}

    public init(habit: HabitEntity?) {
        self.habit = habit
    }
}
