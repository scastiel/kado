import SwiftData
import SwiftUI
import KadoCore

/// Scrollable list of completions for a habit, sorted newest first.
/// Swipe-to-delete removes a completion. Empty state shows a neutral
/// "No history yet" row.
struct CompletionHistoryList: View {
    @Bindable var habit: HabitRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    private var sortedCompletions: [CompletionRecord] {
        (habit.completions ?? []).sorted { $0.date > $1.date }
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    @ViewBuilder
    private func row(for completion: CompletionRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(relativeDate(for: completion.date))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(absoluteDate(for: completion.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(valueLabel(for: completion))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
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

    private func delete(_ completion: CompletionRecord) {
        CompletionLogger(calendar: calendar).delete(completion, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll()
    }

    private func relativeDate(for date: Date) -> String {
        let now = Date.now
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
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

    private func valueLabel(for completion: CompletionRecord) -> String {
        switch habit.type {
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
    CompletionHistoryListPreviewWrapperEmpty()
        .modelContainer(PreviewContainer.emptyContainer())
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
                CompletionHistoryList(habit: habit)
                    .padding()
            } else {
                Text("Seed habit not found")
            }
        }
    }
}

private struct CompletionHistoryListPreviewWrapperEmpty: View {
    @Environment(\.modelContext) private var context
    @State private var habit = HabitRecord(name: "Fresh")

    var body: some View {
        ScrollView {
            CompletionHistoryList(habit: habit)
                .padding()
        }
        .onAppear { context.insert(habit) }
    }
}
