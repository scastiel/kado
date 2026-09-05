import SwiftData
import SwiftUI
import KadoCore

/// Resolves a habit id to the live `HabitRecord` in whichever store is
/// currently mounted, then renders `HabitDetailView`.
///
/// Today pushes a `HabitRoute` (an id) rather than the record itself: a
/// `NavigationPath` survives a dev-mode `ModelContainer` swap, and a
/// record it retained from the previous store traps as soon as SwiftUI
/// re-reads it (issue #63). Re-resolving on every render means the
/// pushed screen follows the swap instead of holding a dead object.
struct HabitDetailLoader: View {
    let habitID: UUID

    /// Deliberately unfiltered. A `#Predicate` matching on `UUID` is
    /// exactly the kind of thing this project has been bitten by
    /// before, the habit list is small enough that a Swift-side lookup
    /// costs nothing, and archived habits must stay reachable here —
    /// the detail screen renders them read-only.
    @Query(sort: \HabitRecord.sortOrder) private var allHabits: [HabitRecord]

    var body: some View {
        if let record = allHabits.first(where: { $0.id == habitID }) {
            HabitDetailView(habit: record)
        } else {
            HabitUnavailableView()
        }
    }
}

#Preview("Found") {
    NavigationStack {
        HabitDetailLoader(habitID: PreviewContainer.firstHabitID)
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Dark") {
    NavigationStack {
        HabitDetailLoader(habitID: UUID())
    }
    .modelContainer(PreviewContainer.shared)
    .preferredColorScheme(.dark)
}
