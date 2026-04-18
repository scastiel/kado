import Foundation
import SwiftData
import KadoCore

/// Rebuilds the local UN pending-request set from SwiftData. Paired
/// with `WidgetReloader` — any mutation that reloads widgets should
/// also resync reminders so a just-completed day stops firing.
///
/// Safe to call even when `ActiveScheduler.shared` hasn't been
/// primed yet (early init); it's a no-op in that case.
@MainActor
enum RemindersSync {
    static func rescheduleAll(using context: ModelContext) {
        guard let scheduler = ActiveScheduler.shared.get() else { return }
        let habits = (try? context.fetch(FetchDescriptor<HabitRecord>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<CompletionRecord>())) ?? []
        let habitSnapshots = habits.map(\.snapshot)
        let completionSnapshots = completions.map(\.snapshot)
        Task.detached { [habitSnapshots, completionSnapshots] in
            await scheduler.rescheduleAll(
                habits: habitSnapshots,
                completions: completionSnapshots
            )
        }
    }
}
