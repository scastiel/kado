import SwiftData
import SwiftUI
import KadoCore

/// Scrollable list of completions for a habit, sorted newest first.
/// Swipe-to-delete removes a completion. Empty state shows a neutral
/// "No history yet" row.
///
/// Takes value-type snapshots for the same reason `HabitDetailView`
/// does: its `ForEach` would otherwise hold `CompletionRecord`s from
/// a store a dev-mode swap has already replaced, and re-reading one
/// during an update pass traps inside SwiftData (issue #63). Deletion
/// resolves the record by id against the current context.
struct CompletionHistoryList: View {
    let habitType: HabitType
    let completions: [Completion]

    @Environment(\.modelContext) private var modelContext
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
                    .foregroundStyle(.secondary)
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
            }
        }
    }

    @ViewBuilder
    private func row(for completion: Completion) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(relativeDate(for: completion.date))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(absoluteDate(for: completion.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = completion.note, !note.isEmpty {
                    Label(note, systemImage: "note.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                        .accessibilityLabel(String(localized: "Note: \(note)"))
                }
            }
            Spacer()
            if completion.value > 0 {
                Text(valueLabel(for: completion))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(completion)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func delete(_ completion: Completion) {
        guard let record = modelContext.completionRecord(id: completion.id) else { return }
        CompletionLogger(calendar: calendar).delete(record, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
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

    @Query private var habits: [HabitRecord]

    init(habitName: String) {
        self.habitName = habitName
        _habits = Query(filter: #Predicate<HabitRecord> { $0.name == habitName })
    }

    var body: some View {
        ScrollView {
            if let habit = habits.first {
                CompletionHistoryList(
                    habitType: habit.type,
                    completions: (habit.completions ?? []).compactMap(\.snapshot)
                )
                .padding()
            } else {
                Text("Seed habit not found")
            }
        }
    }
}
