import SwiftData
import SwiftUI

/// Overview tab: a habits × days matrix. Each row is one non-archived
/// habit; each column is one of the last ~30 days; each cell is
/// tinted by the habit's color at an opacity derived from its EMA
/// score that day.
///
/// Layout: sticky left column (habit icon + name) outside the
/// horizontal scroll view; the scrolling region contains day-column
/// headers plus one row of cells per habit. Initial scroll position
/// anchors at today (newest-on-right, scroll left into history).
struct OverviewView: View {
    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.createdAt
    )
    private var records: [HabitRecord]

    @Environment(\.calendar) private var calendar
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator

    @State private var selection: CellSelection?

    private static let dayWindow = 30
    private static let cellSize: CGFloat = 32
    private static let cellSpacing: CGFloat = 4
    private static let labelWidth: CGFloat = 130
    private static let headerHeight: CGFloat = 36
    private static let rowHeight: CGFloat = 32

    struct CellSelection: Identifiable, Equatable {
        let habit: Habit
        let date: Date
        let cell: DayCell

        var id: String { "\(habit.id)-\(date.timeIntervalSince1970)" }
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    matrix
                }
            }
            .navigationTitle("Overview")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No habits yet",
            systemImage: "square.grid.2x2",
            description: Text("Create habits from the Today tab to see them here.")
        )
    }

    @ViewBuilder
    private var matrix: some View {
        let habits = records.map { $0.snapshot }
        let completions = records.flatMap {
            ($0.completions ?? []).map { $0.snapshot }
        }
        let today = calendar.startOfDay(for: .now)
        let days = dayRange(endingAt: today)
        let rows = OverviewMatrix.compute(
            habits: habits,
            completions: completions,
            days: days,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )

        HStack(alignment: .top, spacing: 8) {
            stickyLabelColumn(rows: rows)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Self.cellSpacing) {
                    dayHeaderRow(days: days)
                    ForEach(rows, id: \.habit.id) { row in
                        cellRow(row, days: days)
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
        }
        .padding()
        .popover(item: $selection) { sel in
            CellPopoverContent(
                habit: sel.habit,
                date: sel.date,
                cell: sel.cell
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private func stickyLabelColumn(rows: [MatrixRow]) -> some View {
        VStack(alignment: .leading, spacing: Self.cellSpacing) {
            Color.clear.frame(height: Self.headerHeight)
            ForEach(rows, id: \.habit.id) { row in
                HabitRowLabel(habit: row.habit, height: Self.rowHeight)
            }
        }
        .frame(width: Self.labelWidth, alignment: .leading)
    }

    private func dayHeaderRow(days: [Date]) -> some View {
        HStack(spacing: Self.cellSpacing) {
            ForEach(days, id: \.self) { day in
                DayColumnHeader(date: day, width: Self.cellSize)
            }
        }
        .frame(height: Self.headerHeight)
    }

    private func cellRow(_ row: MatrixRow, days: [Date]) -> some View {
        MatrixRowView(
            habit: row.habit,
            cells: row.days,
            cellSize: Self.cellSize,
            cellSpacing: Self.cellSpacing,
            cellTap: { index in
                guard days.indices.contains(index),
                      row.days.indices.contains(index) else { return }
                selection = CellSelection(
                    habit: row.habit,
                    date: days[index],
                    cell: row.days[index]
                )
            },
            cellAccessibilityLabel: { index in
                guard days.indices.contains(index),
                      row.days.indices.contains(index) else { return "" }
                return Self.accessibilityLabel(
                    habit: row.habit,
                    date: days[index],
                    cell: row.days[index],
                    calendar: calendar
                )
            }
        )
        .frame(height: Self.rowHeight)
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

    private func dayRange(endingAt today: Date) -> [Date] {
        (0..<Self.dayWindow).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
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
