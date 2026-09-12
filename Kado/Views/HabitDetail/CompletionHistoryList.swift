import SwiftData
import SwiftUI
import KadoCore

/// Scrollable list of completions for a habit, sorted newest first.
/// When `onDelete` is given, a row's long-press menu holds a
/// destructive **Delete** that hands the completion back through it,
/// and a footer says so — a long-press is invisible until someone
/// tells you it's there. A context menu rather than `swipeActions`,
/// which SwiftUI only honours on the rows of a `List` — on a
/// `LazyVStack` row it compiles, looks wired, and never fires (issue
/// #87). Every row also exposes Delete as a VoiceOver action, the same
/// way the Today row does. Without `onDelete` the list is read-only:
/// no menu, no action, no footer — the archived habit's case. Empty
/// state shows a neutral "No history yet" row.
///
/// Takes value-type snapshots for the same reason `HabitDetailView`
/// does: its `ForEach` would otherwise hold `CompletionRecord`s from
/// a store a dev-mode swap has already replaced, and re-reading one
/// during an update pass traps inside SwiftData (issue #63). The
/// deletion itself lives on `HabitDetailView`, which owns the `@Query`
/// the record has to be resolved against — a fetch-based lookup in a
/// view without one is the shape that left the detail screen stale
/// (issue #80).
struct CompletionHistoryList: View {
    let habitType: HabitType
    let completions: [Completion]
    /// `nil` renders the list read-only.
    var onDelete: ((Completion) -> Void)? = nil

    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today

    private var sortedCompletions: [Completion] {
        completions.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if sortedCompletions.isEmpty {
                Text("No history yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: KadoRadius.card)
                            .fill(Color.kadoBackgroundSecondary)
                    )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedCompletions) { completion in
                        row(for: completion)
                        if completion.id != sortedCompletions.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: KadoRadius.card)
                        .fill(Color.kadoBackgroundSecondary)
                )
                if onDelete != nil {
                    // Same job as the Today list's footer: the one
                    // gesture on this list is the one nobody can see.
                    Text("Long-press a row to delete it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    /// The row, with its menu and VoiceOver action when the list is
    /// editable. Branched rather than fed an empty `contextMenu`, so a
    /// read-only row has no interaction at all — nothing to long-press
    /// into and nothing in the Actions rotor.
    @ViewBuilder
    private func row(for completion: Completion) -> some View {
        if let onDelete {
            rowContent(for: completion)
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(completion)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier(AccessibilityID.HabitDetail.historyDeleteButton)
                }
                .accessibilityElement(children: .combine)
                // On a leaf: `.combine` has already collapsed the row
                // to one element. Keyed by the completion's id rather
                // than its date, which is localized.
                .accessibilityIdentifier(AccessibilityID.HabitDetail.historyRow(completion.id))
                .accessibilityAction(named: Text("Delete")) {
                    onDelete(completion)
                }
        } else {
            rowContent(for: completion)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.HabitDetail.historyRow(completion.id))
        }
    }

    private func rowContent(for completion: Completion) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(relativeDate(for: completion.date))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(absoluteDate(for: completion.date))
                    .font(.caption)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                if let note = completion.note, !note.isEmpty {
                    Label(note, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(Color.kadoForegroundSecondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                        .accessibilityLabel(String(localized: "Note: \(note)"))
                }
            }
            Spacer()
            if completion.value > 0 {
                Text(valueLabel(for: completion))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Relative labels are anchored to the **logical** today, not
    /// `isDateInToday` / `isDateInYesterday` — otherwise a completion
    /// logged at 1am under a 4 AM rollover would read "Yesterday" on
    /// the very screen that just recorded it as today.
    private func relativeDate(for date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        // `isDate(inSameDayAs:)` rather than `day == today`: exact
        // equality assumes `today` is a true midnight, which is a
        // stronger promise than this view needs to depend on.
        if calendar.isDate(day, inSameDayAs: today) { return String(localized: "Today") }
        let days = calendar.dateComponents([.day], from: day, to: calendar.startOfDay(for: today)).day ?? 0
        if days == 1 { return String(localized: "Yesterday") }
        if days > 0 && days < 7 {
            return String(localized: "\(days) days ago")
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func absoluteDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: date)
    }

    private func valueLabel(for completion: Completion) -> String {
        switch habitType {
        case .binary:
            return String(localized: "Done")
        case .negative:
            return String(localized: "Slipped")
        case .counter(let target):
            return "\(Int(completion.value))/\(Int(target))"
        case .timer(let targetSeconds):
            return "\(formatMinutes(completion.value)) / \(formatMinutes(targetSeconds))"
        }
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

#Preview("Populated daily") {
    CompletionHistoryListPreviewWrapper(habitName: "Morning meditation")
        .modelContainer(PreviewContainer.shared)
}

#Preview("Counter") {
    CompletionHistoryListPreviewWrapper(habitName: "Drink water")
        .modelContainer(PreviewContainer.shared)
}

#Preview("Read-only (archived)") {
    CompletionHistoryListPreviewWrapper(habitName: "Morning meditation", editable: false)
        .modelContainer(PreviewContainer.shared)
}

#Preview("Empty") {
    ScrollView {
        CompletionHistoryList(habitType: .binary, completions: [])
            .padding()
    }
}

#Preview("Dark") {
    CompletionHistoryListPreviewWrapper(habitName: "Morning meditation")
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

private struct CompletionHistoryListPreviewWrapper: View {
    let habitName: String
    var editable = true

    @Query private var habits: [HabitRecord]

    init(habitName: String, editable: Bool = true) {
        self.habitName = habitName
        self.editable = editable
        _habits = Query(filter: #Predicate<HabitRecord> { $0.name == habitName })
    }

    var body: some View {
        ScrollView {
            if let habit = habits.first {
                CompletionHistoryList(
                    habitType: habit.type,
                    completions: (habit.completions ?? []).compactMap(\.snapshot),
                    onDelete: editable ? { _ in } : nil
                )
                .padding()
            } else {
                Text("Seed habit not found")
            }
        }
    }
}
