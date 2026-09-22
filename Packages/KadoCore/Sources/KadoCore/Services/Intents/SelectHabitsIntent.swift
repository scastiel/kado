import AppIntents
import Foundation

/// Configuration intent for the home widgets, which show several
/// habits. The user picks them in the widget-edit sheet (long-press
/// the widget → Edit Widget) and the provider hands the ids to
/// `WidgetHabitSelection`.
///
/// One intent serves all three families rather than one apiece: the
/// number the user needs to know is stated in each widget's own
/// localized `description`, which the edit sheet shows above the
/// picker, and each family's capacity is applied when the rows are
/// drawn (`WidgetHabitLimit`).
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

    /// No `size:` — deliberately. With a per-family
    /// `IntentCollectionSize` the sheet renders a *list editor*: the
    /// cap is enforced ("Add New Item" disappears at the limit) and
    /// rows can be dragged into order, but every "Add New Item" offers
    /// every habit again, so the same habit can be added twice — drawn
    /// once, at the cost of a slot. Without it the sheet renders a
    /// *checklist*: no duplicates by construction, tap order kept, but
    /// nothing stops checking more than the tile draws. The two cannot
    /// be combined: `size:` and `optionsProvider:` are separate
    /// initializers, and a query that depends on the parameter it
    /// resolves loops the extension forever. The checklist was chosen;
    /// the family's "Pick up to N." line sits directly above it in the
    /// sheet, and the tile draws the first N picks
    /// (`WidgetHabitLimit`, applied in `WidgetHabitSelection`).
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
