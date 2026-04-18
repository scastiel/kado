import SwiftUI
import WidgetKit
import KadoCore

/// Large home widget — habits × last 7 days matrix read from the
/// App Group snapshot.
struct WeeklyGridLargeWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.weeklyLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            WeeklyGridLargeView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kado://overview"))
        }
        .configurationDisplayName(Text("This Week"))
        .description(Text("Your habit grid for the past seven days."))
        .supportedFamilies([.systemLarge])
    }
}

struct WeeklyGridLargeView: View {
    let entry: SnapshotEntry

    private let rowLimit = 9
    private let cellSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.snapshot.matrix.isEmpty {
                emptyPlaceholder
            } else {
                matrix
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("This week")
                .font(.headline)
            Spacer()
            ForEach(entry.snapshot.matrixDays, id: \.self) { day in
                Text(weekdayLabel(for: day))
                    .font(.caption2.monospaced())
                    .foregroundStyle(isToday(day) ? Color.primary : Color.secondary)
                    .frame(width: cellSize, alignment: .center)
            }
        }
    }

    private var matrix: some View {
        VStack(spacing: 4) {
            ForEach(entry.snapshot.matrix.prefix(rowLimit), id: \.habit.id) { row in
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: row.habit.icon)
                            .font(.caption)
                            .foregroundStyle(row.habit.color.color)
                        Text(row.habit.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                        WidgetMatrixCell(cell: cell, color: row.habit.color, size: cellSize)
                    }
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.3x3")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No habits yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    private func weekdayLabel(for day: Date) -> String {
        let weekdayValue = Calendar.current.component(.weekday, from: day)
        return Weekday(rawValue: weekdayValue)?.localizedShort ?? ""
    }
}

/// Widget-local cell view — the app uses `MatrixCell` with a
/// `DayCell` enum from `OverviewMatrix`; the widget reads
/// `WidgetDayCell` values decoded from JSON so we render directly
/// from those.
struct WidgetMatrixCell: View {
    let cell: WidgetDayCell
    let color: HabitColor
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
    }

    private var fill: Color {
        switch cell {
        case .future: Color.clear
        case .notDue: Color(.tertiarySystemFill)
        case .scored: color.color.opacity(cell.colorOpacity ?? 0)
        }
    }
}

#Preview("Seven habits × 7 days", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
