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

    /// The picker caps the selection per family, so the user can't
    /// choose eight habits for a tile that draws five.
    ///
    /// The numbers are spelled out rather than read from
    /// `WidgetHabitLimit`: `IntentCollectionSize.init(min:max:)` takes
    /// `_const Int`, which rejects even a `static let` — "expect a
    /// compile-time constant literal". They must therefore agree with
    /// `WidgetHabitLimit` by hand, and
    /// `SelectHabitsIntentTests.pickerCapsMatchTheRenderLimits` reads
    /// them back out of the generated AppIntents metadata and fails
    /// if they ever drift.
    ///
    /// `min: 0` is load-bearing: an empty selection has to stay legal,
    /// because that is what "show every habit" means everywhere else.
    @Parameter(
        title: "Habits",
        size: [
            .systemSmall: IntentCollectionSize(min: 0, max: 5),
            .systemMedium: IntentCollectionSize(min: 0, max: 8),
            .systemLarge: IntentCollectionSize(min: 0, max: 5),
        ]
    )
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
