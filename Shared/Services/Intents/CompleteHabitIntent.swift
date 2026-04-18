import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Toggles today's completion for a binary or negative habit.
/// Counter and timer habits need the app's per-type input UI, so
/// this intent refuses them and surfaces an "open the app"
/// result instead.
///
/// Runs either in the foreground app (MainActor) or inside the
/// widget extension process when the user taps an interactive
/// widget. Both paths funnel through `apply(habitID:in:calendar:now:)`
/// which is the single unit of tested behavior.
struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Habit"
    static let description = IntentDescription(
        "Mark a habit as done for today, or undo if it's already done."
    )

    /// Interactive-widget taps invoke this intent without needing
    /// to open the app.
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = try IntentContainerResolver.sharedContainer().mainContext
        let outcome = try Self.apply(
            habitID: habit.id,
            in: context,
            calendar: .current,
            now: .now
        )
        WidgetCenter.shared.reloadAllTimelines()
        switch outcome {
        case .toggled:
            return .result()
        case .opensApp:
            // Counter / timer habits can't meaningfully be logged
            // in one tap — ask the system to open the app.
            throw OpenAppSignal()
        }
    }

    /// Testable core of the intent. Fetches the habit, toggles
    /// today's completion via `CompletionToggler` when the type
    /// supports single-tap logging, and returns what happened so
    /// the caller can decide whether to hop to the app.
    @MainActor
    static func apply(
        habitID: UUID,
        in context: ModelContext,
        calendar: Calendar,
        now: Date
    ) throws -> Outcome {
        // Widget extension can't compile `#Predicate` — fetch all
        // and search in Swift. See HabitEntity.fetchSuggestions.
        let descriptor = FetchDescriptor<HabitRecord>()
        guard let record = try context.fetch(descriptor).first(where: { $0.id == habitID }) else {
            throw IntentError.habitNotFound
        }
        guard record.archivedAt == nil else {
            throw IntentError.habitArchived
        }
        switch record.type {
        case .binary, .negative:
            CompletionToggler(calendar: calendar)
                .toggleToday(for: record, on: now, in: context)
            try context.save()
            return .toggled
        case .counter, .timer:
            return .opensApp
        }
    }

    enum Outcome: Equatable {
        case toggled
        case opensApp
    }

    enum IntentError: Error, LocalizedError {
        case habitNotFound
        case habitArchived

        var errorDescription: String? {
            switch self {
            case .habitNotFound: "This habit no longer exists."
            case .habitArchived: "This habit is archived."
            }
        }
    }

    /// Sentinel thrown from `perform()` to signal the system to
    /// open the app rather than silently succeed. AppIntents
    /// handles the rest.
    private struct OpenAppSignal: Error {}
}
