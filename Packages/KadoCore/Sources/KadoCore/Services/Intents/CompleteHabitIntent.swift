import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Toggles today's completion for a binary or negative habit.
/// Counter and timer habits need the app's per-type input UI, so
/// this intent refuses them and signals the system to surface
/// the habit in the app instead.
///
/// Runs in the main app process — `openAppWhenRun = true` so
/// tapping a widget `Button(intent:)` opens the app, which then
/// performs the toggle against SwiftData. This trades silent
/// completion for the simpler single-container story the widget
/// snapshot architecture requires.
public struct CompleteHabitIntent: AppIntent {
    public static let title: LocalizedStringResource = "Complete Habit"
    public static let description = IntentDescription(
        "Mark a habit as done for today, or undo if it's already done."
    )

    /// Always opens the main app because the widget extension
    /// can't safely attach SwiftData — see `WidgetSnapshotBuilder`
    /// for the snapshot-based read path.
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Habit")
    public var habit: HabitEntity

    public init() {}

    public init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Reuse the app's live container — opening a fresh one in
        // the same process would fight for CloudKit ownership and
        // trap. `openAppWhenRun = true` guarantees the app primes
        // `ActiveContainer.shared` before this method runs.
        let container = try ActiveContainer.shared.get()
        _ = try Self.apply(
            habitID: habit.id,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )
        WidgetSnapshotBuilder.rebuildAndWrite(using: container.mainContext)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// Testable core of the intent. Fetches the habit, toggles
    /// today's completion via `CompletionToggler` when the type
    /// supports single-tap logging, and returns what happened so
    /// the caller can decide whether to hop to the app.
    @MainActor
    public static func apply(
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

    public enum Outcome: Equatable {
        case toggled
        case opensApp
    }

    public enum IntentError: Error, LocalizedError {
        case habitNotFound
        case habitArchived

        public var errorDescription: String? {
            switch self {
            case .habitNotFound: "This habit no longer exists."
            case .habitArchived: "This habit is archived."
            }
        }
    }

}
