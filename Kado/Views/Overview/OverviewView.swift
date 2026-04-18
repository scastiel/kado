import SwiftData
import SwiftUI

/// Overview tab: habits × days matrix.
///
/// Layout (single horizontal scroll):
/// - One full-width `ScrollView(.horizontal)` holds a VStack that,
///   per habit, alternates a clear "name" spacer and a cells row.
///   Every cell row moves together because there's only one scroll
///   state.
/// - A sibling VStack overlays the scroll view with the habit
///   labels, positioned over the clear spacer rows. It has a
///   transparent background and `.allowsHitTesting(false)` so the
///   scroll + cell taps still reach the layer below.
/// - Outer `ScrollView(.vertical)` keeps the "Overview" title
///   collapsing like Today and Settings.
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
    private static let labelHeight: CGFloat = 28
    private static let labelBottomPadding: CGFloat = 8
    private static let rowGap: CGFloat = 12
    private static let headerHeight: CGFloat = 40

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
            ZStack(alignment: .topLeading) {
                scrollingCells(rows: rows, days: days)
                labelsOverlay(rows: rows)
            }
            .padding(.vertical, 8)
        }
    }

    /// Binding that reflects whether a specific (habit, date) cell is
    /// the currently selected one. Used to attach `.popover` per-cell
    /// so the popover anchors to the tapped button rather than the
    /// whole matrix.
    private func selectionBinding(habit: Habit, date: Date) -> Binding<Bool> {
        Binding(
            get: {
                guard let sel = selection else { return false }
                return sel.habit.id == habit.id && sel.date == date
            },
            set: { newValue in
                if !newValue,
                   let sel = selection,
                   sel.habit.id == habit.id,
                   sel.date == date {
                    selection = nil
                }
            }
        )
    }

    private func scrollingCells(rows: [MatrixRow], days: [Date]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Date column headers — scroll horizontally with the cells.
                HStack(spacing: Self.cellSpacing) {
                    ForEach(days, id: \.self) { day in
                        DayColumnHeader(date: day, width: Self.cellSize)
                    }
                }
                .frame(height: Self.headerHeight)

                Color.clear.frame(height: Self.rowGap)

                ForEach(rows, id: \.habit.id) { row in
                    // Transparent spacer where the label + padding overlay.
                    Color.clear.frame(height: Self.labelHeight + Self.labelBottomPadding)
                    cellRow(row, days: days)
                    if row.habit.id != rows.last?.habit.id {
                        Color.clear.frame(height: Self.rowGap)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .defaultScrollAnchor(.trailing)
    }

    private func labelsOverlay(rows: [MatrixRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Match the date-header row + its trailing gap so the first
            // label lands in the first habit's spacer slot.
            Color.clear.frame(height: Self.headerHeight + Self.rowGap)

            ForEach(rows, id: \.habit.id) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.habit.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(row.habit.color.color)
                    Text(row.habit.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: Self.labelHeight, alignment: .leading)

                // Spacer for the breathing room below the name + the
                // cell row itself, so the next label lines up with the
                // next habit's spacer slot.
                Color.clear.frame(height: Self.labelBottomPadding + Self.cellSize)
                if row.habit.id != rows.last?.habit.id {
                    Color.clear.frame(height: Self.rowGap)
                }
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
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
                .popover(isPresented: selectionBinding(habit: row.habit, date: day)) {
                    CellPopoverContent(habit: row.habit, date: day, cell: cell)
                        .presentationCompactAdaptation(.popover)
                }
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
