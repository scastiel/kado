import SwiftUI
import KadoCore

/// Placeholder for a screen whose habit id no longer resolves to a
/// record — the store was swapped underneath it (dev mode) or the
/// habit was deleted while the screen was still on the stack.
///
/// Screens address habits by id rather than by managed object so a
/// container swap can't trap them (issue #63); this is what they show
/// when the lookup comes back empty.
struct HabitUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Habit unavailable", systemImage: "questionmark.circle")
        } description: {
            Text("This habit is no longer available.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.kadoBackground.ignoresSafeArea())
    }
}

#Preview {
    HabitUnavailableView()
}

#Preview("Dark") {
    HabitUnavailableView()
        .preferredColorScheme(.dark)
}
