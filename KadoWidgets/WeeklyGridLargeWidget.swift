import SwiftUI
import WidgetKit
import KadoCore

/// Large home widget — habits × last 7 days matrix read from the
/// App Group snapshot. Layout mirrors the Overview tab: one row
/// per habit with the name + icon on top and the seven cells
/// beneath. No horizontal scroll (the widget can't scroll anyway),
/// so cell width stretches to fill the container.
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

    private let rowLimit = 6
    private static let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.headline)
            if entry.snapshot.matrix.isEmpty {
                emptyPlaceholder
            } else {
                weekdayStripe
                habitRows
            }
            Spacer(minLength: 0)
        }
    }

    /// Day labels laid out with the same full-width stretch as the
    /// per-habit cell stripes below, so each label sits directly
    /// above its column of cells.
    private var weekdayStripe: some View {
        GeometryReader { geo in
            let spacing: CGFloat = Self.cellSpacing
            let count = CGFloat(max(entry.snapshot.matrixDays.count, 1))
            let cellWidth = max(
                8,
                (geo.size.width - spacing * max(0, count - 1)) / count
            )
            HStack(spacing: spacing) {
                ForEach(entry.snapshot.matrixDays, id: \.self) { day in
                    Text(weekdayLabel(for: day))
                        .font(.caption2.monospaced())
                        .foregroundStyle(isToday(day) ? Color.primary : Color.secondary)
                        .frame(width: cellWidth)
                }
            }
        }
        .frame(height: 14)
    }

    private var habitRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entry.snapshot.matrix.prefix(rowLimit), id: \.habit.id) { row in
                habitBlock(for: row)
            }
        }
    }

    private func habitBlock(for row: WidgetMatrixRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: row.habit.icon)
                    .font(.caption)
                    .foregroundStyle(row.habit.color.color)
                    .frame(width: 16, alignment: .center)
                Text(row.habit.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            cellStripe(for: row)
        }
    }

    private func cellStripe(for row: WidgetMatrixRow) -> some View {
        GeometryReader { geo in
            let spacing: CGFloat = Self.cellSpacing
            let count = CGFloat(max(row.cells.count, 1))
            let cellWidth = max(
                8,
                (geo.size.width - spacing * max(0, count - 1)) / count
            )
            HStack(spacing: spacing) {
                ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                    WidgetMatrixCell(
                        cell: cell,
                        color: row.habit.color,
                        size: min(cellWidth, 26)
                    )
                    .frame(width: cellWidth)
                }
            }
        }
        .frame(height: 22)
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
        // `localizedMedium` returns the three-letter standalone
        // symbol for the current locale ("Sun", "Mon", "dim",
        // "lun"); truncating to two characters gives the stem the
        // user expects across languages.
        return String(Weekday(rawValue: weekdayValue)?.localizedMedium.prefix(2) ?? "")
    }
}

/// Widget-local cell view — the app uses `MatrixCell` with a
/// `DayCell` enum; the widget reads `WidgetDayCell` values
/// decoded from JSON so we render directly from those.
struct WidgetMatrixCell: View {
    let cell: WidgetDayCell
    let color: HabitColor
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .frame(height: size)
    }

    private var fill: Color {
        switch cell {
        case .future: Color.clear
        case .notDue: Color(.tertiarySystemFill)
        case .scored: color.color.opacity(cell.colorOpacity ?? 0)
        }
    }
}

#Preview("Populated", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
