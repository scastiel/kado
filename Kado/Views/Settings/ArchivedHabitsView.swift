import SwiftData
import SwiftUI
import KadoCore

/// Settings › Archived habits: the habits Archive took off Today, each
/// opening the same read-only detail Today pushes, with **Unarchive**
/// and **Delete** on every row.
///
/// Before this screen existed, Archive was indistinguishable from
/// Delete — the habit vanished from every list and nothing offered it
/// back (issue #99). Delete lives here and only here: Today's menu and
/// the active detail keep Archive as their one destructive action, and
/// it is the recoverable one. Deleting is two steps by design.
///
/// The list is a `List`, so `.swipeActions` fires on its rows (issue
/// #87); the long-press menu and the VoiceOver actions carry the same
/// two actions, and a footer says so. Rows hold ids and snapshots,
/// never a `HabitRecord` (issue #63).
struct ArchivedHabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt != nil },
        sort: \HabitRecord.sortOrder
    )
    private var archivedHabits: [HabitRecord]

    /// The habit whose Delete is awaiting confirmation. An id, so the
    /// dialog can't hold a record across a container swap.
    @State private var confirmingDeleteOf: UUID?

    private var rows: [ArchivedHabitRow] {
        ArchivedHabitRow.rows(from: archivedHabits)
    }

    var body: some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.kadoBackground.ignoresSafeArea())
            .navigationTitle(Text("Archived habits"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HabitRoute.self) { route in
                HabitDetailLoader(habitID: route.id)
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: deleteDialogBinding,
                titleVisibility: .visible,
                presenting: confirmingDeleteOf
            ) { habitID in
                Button(String(localized: "Delete"), role: .destructive) {
                    delete(habitID)
                }
                .accessibilityIdentifier(AccessibilityID.Archived.deleteConfirmButton)
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { _ in
                Text("This permanently deletes the habit and all of its history. This can’t be undone.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if rows.isEmpty {
            ContentUnavailableView {
                Label("No archived habits", systemImage: "archivebox")
            } description: {
                Text("Habits you archive leave Today but keep their history. You can unarchive or delete them from here.")
            }
        } else {
            List {
                Section {
                    ForEach(rows) { row in
                        self.row(row)
                    }
                } footer: {
                    // Same job as the Today list's footer: the one
                    // place that says a long-press does something.
                    Text("Swipe or long-press a habit to unarchive or delete it.")
                        .foregroundStyle(Color.kadoForegroundSecondary)
                }
            }
        }
    }

    private func row(_ item: ArchivedHabitRow) -> some View {
        NavigationLink(value: HabitRoute(id: item.id)) {
            ArchivedHabitRowView(row: item, archivedOn: archivedOnLabel(for: item))
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
        // Unarchive is reversible, so a full swipe may fire it; Delete
        // confirms first, so it takes a tap.
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                unarchive(item.id)
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .tint(Color.kadoAccent)
            .accessibilityIdentifier(AccessibilityID.Archived.swipeUnarchiveButton)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No `.destructive` role: that role makes the system
            // animate the row away on the tap, and the row would then
            // spring back when the confirmation is cancelled.
            Button {
                confirmingDeleteOf = item.id
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            .accessibilityIdentifier(AccessibilityID.Archived.swipeDeleteButton)
        }
        .contextMenu {
            Button {
                unarchive(item.id)
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .accessibilityIdentifier(AccessibilityID.Archived.unarchiveButton)
            Button(role: .destructive) {
                confirmingDeleteOf = item.id
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier(AccessibilityID.Archived.deleteButton)
        }
        .accessibilityAction(named: Text("Unarchive")) {
            unarchive(item.id)
        }
        .accessibilityAction(named: Text("Delete")) {
            confirmingDeleteOf = item.id
        }
    }

    private func archivedOnLabel(for item: ArchivedHabitRow) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .medium
        return formatter.string(from: item.archivedAt)
    }

    // MARK: - Delete dialog

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { confirmingDeleteOf != nil },
            set: { if !$0 { confirmingDeleteOf = nil } }
        )
    }

    /// Names the habit, so a Delete reached from a swipe on the wrong
    /// row is caught by the title rather than by the loss.
    private var deleteDialogTitle: Text {
        if let habitID = confirmingDeleteOf,
           let name = rows.first(where: { $0.id == habitID })?.habit.name {
            return Text("Delete “\(name)”?")
        }
        return Text("Delete this habit?")
    }

    // MARK: - Actions

    /// Resolves a row back to the live managed object, against
    /// whichever store is mounted now. `nil` when the habit isn't there
    /// any more — unarchived from its detail, or left behind by a
    /// dev-mode store swap.
    private func record(for habitID: UUID) -> HabitRecord? {
        archivedHabits.first { $0.id == habitID }
    }

    private func unarchive(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        HabitLifecycle().unarchive(record, in: modelContext)
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func delete(_ habitID: UUID) {
        guard let record = record(for: habitID) else { return }
        HabitLifecycle().delete(record, in: modelContext)
        WidgetReloader.reloadAll(using: modelContext)
    }
}

/// One row: the habit's mark and name, and under it when it was
/// archived and how much history it carries.
private struct ArchivedHabitRowView: View {
    let row: ArchivedHabitRow
    let archivedOn: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(row.habit.color.tint(.mark))
                Image(systemName: row.habit.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(row.habit.color.onTint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.habit.name)
                    .foregroundStyle(Color.kadoForeground)
                    .lineLimit(2)
                (Text("Archived on \(archivedOn)")
                    + Text(verbatim: " · ")
                    + Text("\(row.completionCount) completions"))
                    .font(.footnote)
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
        }
        .padding(.vertical, 4)
        // Collapsed to one element so the identifier lands on a leaf,
        // and keyed by id: names are localized and user-editable.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.Archived.row(row.id))
    }
}

#Preview("Populated") {
    NavigationStack {
        ArchivedHabitsView()
    }
    .modelContainer(PreviewContainer.withArchivedHabits())
}

#Preview("Empty") {
    NavigationStack {
        ArchivedHabitsView()
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Dark") {
    NavigationStack {
        ArchivedHabitsView()
    }
    .modelContainer(PreviewContainer.withArchivedHabits())
    .preferredColorScheme(.dark)
}
