import SwiftData
import SwiftUI

/// Overview tab: one card per non-archived habit. Each card stacks
/// the habit label (icon + name) above a horizontal strip of day
/// cells. Cards scroll vertically so the `Overview` nav title
/// collapses naturally like Today and Settings.
///
/// Every cell-strip ScrollView shares one `scrollPosition` binding,
/// so panning horizontally on any card simultaneously scrolls all
/// cards. Labels live outside the horizontal scroll region and
/// therefore stay put.
struct OverviewView: View {
    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.createdAt
    )
    private var records: [HabitRecord]

    @Environment(\.calendar) private var calendar
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator

    @State private var selection: CellSelection?
    @State private var scrolledDay: Date?

    private static let dayWindow = 30
    private static let cellSize: CGFloat = 36
    private static let cellSpacing: CGFloat = 6

    struct CellSelection: Identifiable, Equatable {
        let habit: Habit
        let date: Date
        let cell: DayCell

        var id: String { "\(habit.id)-\(date.timeIntervalSince1970)" }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Overview")
        }
    }

    @ViewBuilder
    private var content: some View {
        if records.isEmpty {
            emptyState
        } else {
            matrix
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No habits yet",
            systemImage: "square.grid.2x2",
            description: Text("Create habits from the Today tab to see them here.")
        )
    }

    private var matrix: some View {
        let today = calendar.startOfDay(for: .now)
        let days = dayRange(endingAt: today)
        let habits = records.map { $0.snapshot }
        let completions = records.flatMap {
            ($0.completions ?? []).map { $0.snapshot }
        }
        let rows = OverviewMatrix.compute(
            habits: habits,
            completions: completions,
            days: days,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )

        return ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                ForEach(rows, id: \.habit.id) { row in
                    habitCard(row, days: days)
                }
            }
            .padding()
        }
        .popover(item: $selection) { sel in
            CellPopoverContent(
                habit: sel.habit,
                date: sel.date,
                cell: sel.cell
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private func habitCard(_ row: MatrixRow, days: [Date]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: row.habit.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(row.habit.color.color)
                Text(row.habit.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.cellSpacing) {
                    ForEach(Array(zip(days, row.days).enumerated()), id: \.offset) { _, pair in
                        let (day, cell) = pair
                        Button {
                            selection = CellSelection(habit: row.habit, date: day, cell: cell)
                        } label: {
                            MatrixCell(
                                state: cell,
                                color: row.habit.color,
                                size: Self.cellSize
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            Self.accessibilityLabel(
                                habit: row.habit,
                                date: day,
                                cell: cell,
                                calendar: calendar
                            )
                        )
                        .id(day)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 2)
            }
            .scrollPosition(id: $scrolledDay, anchor: .trailing)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            // Anchor every card at today on first appearance; subsequent
            // pans update the shared binding, syncing all cards.
            if scrolledDay == nil {
                scrolledDay = days.last
            }
        }
    }

    private func dayRange(endingAt today: Date) -> [Date] {
        (0..<Self.dayWindow).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    /// Composes a per-cell VoiceOver label:
    /// `"{habit}, {localized date}, {state}"`.
    private static func accessibilityLabel(
        habit: Habit,
        date: Date,
        cell: DayCell,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        let dateString = formatter.string(from: date)

        let state: String
        switch cell {
        case .future:
            state = String(localized: "upcoming")
        case .notDue:
            state = String(localized: "not scheduled")
        case .scored(let s):
            if s >= 1.0 {
                state = String(localized: "completed")
            } else if s <= 0.0 {
                state = String(localized: "missed")
            } else {
                let percent = Int((s * 100).rounded())
                state = String(localized: "\(percent)% complete")
            }
        }
        return "\(habit.name), \(dateString), \(state)"
    }
}

#Preview("Populated") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
}

#Preview("Empty") {
    OverviewView()
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Dark") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.dynamicTypeSize, .accessibility3)
}
