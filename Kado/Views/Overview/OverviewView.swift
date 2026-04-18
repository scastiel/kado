import SwiftData
import SwiftUI

/// Overview tab: habits × days matrix.
///
/// Layout:
/// - Outer vertical `ScrollView` so the large `Overview` title
///   collapses as on Today and Settings.
/// - Inside, an `HStack(alignment: .top)`:
///   - Leading column (pinned): habit icon + name per row. Sits
///     outside the horizontal scroll so it stays put.
///   - Trailing column: a single `ScrollView(.horizontal)` wrapping
///     a `VStack` of cell rows. One scroll view → one scroll state
///     → every row moves together. Anchored at today via
///     `defaultScrollAnchor(.trailing)`.
/// - Row heights match between the labels column and the cells
///   column so the two stay aligned visually.
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
    private static let cellSize: CGFloat = 36
    private static let cellSpacing: CGFloat = 6
    private static let rowSpacing: CGFloat = 8
    private static let labelWidth: CGFloat = 130

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
            HStack(alignment: .top, spacing: 12) {
                labelsColumn(rows: rows)
                cellsScrollView(rows: rows, days: days)
            }
            .padding(.horizontal)
            .padding(.top, 8)
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

    private func labelsColumn(rows: [MatrixRow]) -> some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            ForEach(rows, id: \.habit.id) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.habit.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(row.habit.color.color)
                        .frame(width: 22)
                    Text(row.habit.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: Self.cellSize, alignment: .leading)
            }
        }
        .frame(width: Self.labelWidth, alignment: .leading)
    }

    private func cellsScrollView(rows: [MatrixRow], days: [Date]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(rows, id: \.habit.id) { row in
                    cellRow(row, days: days)
                }
            }
            .padding(.trailing, 8)
        }
        .defaultScrollAnchor(.trailing)
    }

    private func cellRow(_ row: MatrixRow, days: [Date]) -> some View {
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
            }
        }
        .frame(height: Self.cellSize)
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
