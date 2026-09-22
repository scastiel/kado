import SwiftData
import SwiftUI
import KadoCore

/// Settings entry point for the Archived habits list. Always present,
/// even with nothing archived: the user who wrote in about issue #99
/// could not tell whether an archive *existed*, and a row that only
/// appears once something is in it would not have told them either.
/// The badge carries the count, so the answer is there without a push.
struct ArchivedSection: View {
    @Query(filter: #Predicate<HabitRecord> { $0.archivedAt != nil })
    private var archivedHabits: [HabitRecord]

    var body: some View {
        Section {
            NavigationLink {
                ArchivedHabitsView()
            } label: {
                Label("Archived habits", systemImage: "archivebox")
                    .badge(archivedHabits.count)
            }
            .accessibilityIdentifier(AccessibilityID.Settings.archivedRow)
            .listRowBackground(Color.kadoBackgroundSecondary)
        } header: {
            Text("Habits")
                .foregroundStyle(Color.kadoForegroundSecondary)
        }
    }
}

#Preview("With archived habits") {
    NavigationStack {
        Form {
            ArchivedSection()
        }
    }
    .modelContainer(PreviewContainer.withArchivedHabits())
}

#Preview("None archived") {
    NavigationStack {
        Form {
            ArchivedSection()
        }
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Dark") {
    NavigationStack {
        Form {
            ArchivedSection()
        }
    }
    .modelContainer(PreviewContainer.withArchivedHabits())
    .preferredColorScheme(.dark)
}
