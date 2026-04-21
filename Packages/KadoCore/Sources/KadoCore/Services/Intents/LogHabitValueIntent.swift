import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Logs a numeric value for a counter or timer habit. Spoken from
/// Siri as "Log 2 for Water" or "Log 15 for Read"; the value's
/// unit follows the habit's type — counter values are stored
/// as-is, timer values are interpreted as **minutes** and converted
/// to seconds before persisting (matches how the habit graph and
/// score expect timer values).
///
/// Refuses binary / negative habits with a spoken hint pointing
/// the user at `CompleteHabitIntent` instead.
public struct LogHabitValueIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Habit Value"
    public static let description = IntentDescription(
        "Log a numeric value for a counter or timer habit."
    )

    /// Same constraint as CompleteHabitIntent — mutating SwiftData
    /// requires the main app process so we don't fight CloudKit
    /// for the store.
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Habit")
    public var habit: HabitEntity

    @Parameter(
        title: "Value",
        description: "Counter habits: the count. Timer habits: minutes."
    )
    public var value: Double

    public init() {}

    public init(habit: HabitEntity, value: Double) {
        self.habit = habit
        self.value = value
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ActiveContainer.shared.get()
        let outcome = try Self.apply(
            habitID: habit.id,
            value: value,
            in: container.mainContext,
            calendar: .current,
            now: .now
        )
        if case .logged = outcome {
            WidgetSnapshotBuilder.rebuildAndWrite(using: container.mainContext)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result(dialog: Self.dialog(for: outcome, habitName: habit.name))
    }

    /// Testable core. Fetches the habit, dispatches on type, and
    /// returns what happened so callers can build a dialog or chain
    /// further side effects without a second store round-trip.
    @MainActor
    public static func apply(
        habitID: UUID,
        value: Double,
        in context: ModelContext,
        calendar: Calendar,
        now: Date
    ) throws -> Outcome {
        let descriptor = FetchDescriptor<HabitRecord>()
        guard let record = try context.fetch(descriptor).first(where: { $0.id == habitID }) else {
            throw IntentError.habitNotFound
        }
        guard record.archivedAt == nil else {
            throw IntentError.habitArchived
        }
        switch record.type {
        case .binary:
            return .wrongType(kind: .binary)
        case .negative:
            return .wrongType(kind: .negative)
        case .counter:
            CompletionToggler(calendar: calendar)
                .setValueToday(value, for: record, on: now, in: context)
            try context.save()
            return .logged(value: value, kind: .counter)
        case .timer:
            // Spoken value is in minutes; on-disk completions for
            // timer habits store seconds so the score / graph match
            // manual entries.
            let seconds = value * 60
            CompletionToggler(calendar: calendar)
                .setValueToday(seconds, for: record, on: now, in: context)
            try context.save()
            return .logged(value: value, kind: .timer)
        }
    }

    /// Picks the spoken Siri dialog for an outcome. Separated so
    /// tests can pin dialog content without booting an intent host.
    public static func dialog(for outcome: Outcome, habitName: String) -> IntentDialog {
        switch outcome {
        case .logged(let value, .timer):
            let minutes = Int(value.rounded())
            return IntentDialog("Logged \(minutes) minutes for \(habitName).")
        case .logged(let value, _):
            let formatted = formatNumber(value)
            return IntentDialog("Logged \(formatted) for \(habitName).")
        case .wrongType(.binary), .wrongType(.negative):
            return IntentDialog("\(habitName) is a yes/no habit — say \"Complete \(habitName)\" instead.")
        case .wrongType:
            // Defensive — apply() never returns wrongType for
            // counter/timer, but the enum allows it. Generic phrasing.
            return IntentDialog("\(habitName) doesn't accept that kind of value.")
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    public enum Outcome: Equatable, Sendable {
        case logged(value: Double, kind: HabitKind)
        case wrongType(kind: HabitKind)
    }

    /// Type-erased habit kind so `Outcome` doesn't drag the whole
    /// `HabitType` enum (with associated values) into Equatable
    /// noise.
    public enum HabitKind: String, Sendable {
        case binary
        case negative
        case counter
        case timer
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
