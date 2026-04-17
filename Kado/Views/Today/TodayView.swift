import SwiftUI

/// The Today tab — lists habits due today.
///
/// Placeholder at bootstrap. v0.1 replaces the body with a list of
/// habits (from a `@Query` on the SwiftData `Habit` model) and
/// tap-to-complete interactions.
struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No habits yet",
                systemImage: "list.bullet.clipboard",
                description: Text("Habits you create will appear here.")
            )
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
