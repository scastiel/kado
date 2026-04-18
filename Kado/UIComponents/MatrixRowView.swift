import SwiftUI
import KadoCore

/// One habit's row in the Overview matrix: a leading label (icon +
/// name) and a horizontal list of day cells. The `cellTap` closure
/// receives the cell's index into `cells` so the caller can map back
/// to the corresponding day.
struct MatrixRowView: View {
    let habit: Habit
    let cells: [DayCell]
    var cellSize: CGFloat = 32
    var cellSpacing: CGFloat = 4
    var cellTap: ((Int) -> Void)? = nil
    /// Optional per-cell accessibility label. Passed the cell index
    /// into `cells` so the caller can compose `{habit, date, state}`.
    var cellAccessibilityLabel: ((Int) -> String)? = nil

    var body: some View {
        HStack(spacing: cellSpacing) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                cellView(cell: cell, index: index)
                    .accessibilityLabel(
                        cellAccessibilityLabel?(index) ?? ""
                    )
            }
        }
    }

    @ViewBuilder
    private func cellView(cell: DayCell, index: Int) -> some View {
        if let cellTap {
            Button {
                cellTap(index)
            } label: {
                MatrixCell(state: cell, color: habit.color, size: cellSize)
            }
            .buttonStyle(.plain)
        } else {
            MatrixCell(state: cell, color: habit.color, size: cellSize)
        }
    }
}

/// A leading label for the Overview matrix: habit icon tinted by its
/// color, followed by the habit name. Factored out so the full-view
/// can stack it sticky-left of the scrolling cell region.
struct HabitRowLabel: View {
    let habit: Habit
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: habit.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(habit.color.color)
                .frame(width: 24)
            Text(habit.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(height: height, alignment: .leading)
    }
}

#Preview("Row — varied states") {
    let habit = Habit(
        name: "Morning meditation",
        frequency: .daily,
        type: .binary,
        createdAt: Calendar.current.date(byAdding: .day, value: -20, to: .now)!,
        color: .purple,
        icon: "figure.mind.and.body"
    )
    let cells: [DayCell] = [
        .notDue, .scored(0.1), .scored(0.3), .scored(0.6), .scored(0.9),
        .scored(1.0), .notDue, .scored(0.5), .scored(0.7), .future, .future,
    ]
    return VStack(alignment: .leading, spacing: 8) {
        HabitRowLabel(habit: habit)
        MatrixRowView(habit: habit, cells: cells)
    }
    .padding()
}
