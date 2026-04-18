import SwiftUI
import WidgetKit

/// Large home widget — habits × last 7 days matrix, reusing
/// `OverviewMatrix.compute` so the cell tinting matches the
/// Overview tab exactly.
struct WeeklyGridLargeWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.weeklyLarge"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: WeeklyMatrixProvider()
        ) { entry in
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
    let entry: WeeklyMatrixEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.rows.isEmpty {
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
            ForEach(entry.days, id: \.self) { day in
                Text(weekdayLabel(for: day))
                    .font(.caption2.monospaced())
                    .foregroundStyle(isToday(day) ? Color.primary : Color.secondary)
                    .frame(width: cellSize, alignment: .center)
            }
        }
    }

    private var matrix: some View {
        VStack(spacing: 4) {
            ForEach(entry.rows.prefix(rowLimit), id: \.habit.id) { row in
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
                    ForEach(Array(row.days.enumerated()), id: \.offset) { _, cell in
                        MatrixCell(state: cell, color: row.habit.color, size: cellSize)
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

    private var cellSize: CGFloat { 22 }
    private var rowLimit: Int { 9 }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDateInToday(day)
    }

    private func weekdayLabel(for day: Date) -> String {
        let weekdayValue = Calendar.current.component(.weekday, from: day)
        return Weekday(rawValue: weekdayValue)?.localizedShort ?? ""
    }
}

#Preview("Seven habits × 7 days", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    PreviewMatrix.sampleEntry()
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    WeeklyMatrixEntry(date: .now, days: [], rows: [])
}
