import AppIntents
import Foundation

/// Configuration intent for the home widgets, which show several
/// habits. The user picks them in the widget-edit sheet (long-press
/// the widget → Edit Widget) and the provider hands the ids to
/// `WidgetHabitSelection`.
///
/// One intent serves all three families rather than one apiece:
/// AppIntents has no max-count on an array parameter, so each family's
/// capacity is applied when the rows are resolved either way, and the
/// number the user needs to know is stated in each widget's own
/// localized `description`.
///
/// `habits` is optional, and empty means "no pick yet" — every
/// freshly added widget starts there, and so does one already on the
/// Home Screen when this build swaps its `StaticConfiguration` out.
/// Both show every habit, which is what they showed before.
public struct SelectHabitsIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "Choose Habits"
    public static let description = IntentDescription(
        "Choose which habits this widget shows. Leave it empty to show them all."
    )

    @Parameter(title: "Habits")
    public var habits: [HabitEntity]?

    public init() {}

    public init(habits: [HabitEntity]?) {
        self.habits = habits
    }

    /// The pick as the selection logic wants it: ids, in the order
    /// they were chosen.
    public var habitIDs: [UUID] {
        (habits ?? []).map(\.id)
    }
}
