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
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitsIntent.self,
            provider: SelectedSnapshotProvider()
        ) { entry in
            WeeklyGridLargeView(entry: entry)
                .containerBackground(for: .widget) { Color.kadoBackgroundSecondary }
                .widgetURL(URL(string: "kado://overview"))
        }
        .configurationDisplayName(Text("This Week"))
        .description(Text("Your habit grid for the past seven days. Pick up to 5."))
        .supportedFamilies([.systemLarge])
    }
}

struct WeeklyGridLargeView: View {
    let entry: SelectedSnapshotEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private static let cellSpacing: CGFloat = 4

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    private var rows: [WidgetMatrixRow] {
        entry.matrixRows(limit: WidgetHabitLimit.large)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
                .font(.headline)
                .foregroundStyle(palette.foreground)
                .widgetAccentable()
            if rows.isEmpty {
                // "No habits yet" only when there really are none. A
                // pick whose habits have all been archived is a
                // different situation and gets its own wording.
                emptyPlaceholder(isFilteredOut: !entry.snapshot.matrix.isEmpty)
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
                        .foregroundStyle(isToday(day) ? palette.foreground : palette.foregroundSecondary)
                        .frame(width: cellWidth)
                }
            }
        }
        .frame(height: 14)
    }

    private var habitRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.habit.id) { row in
                habitBlock(for: row)
            }
        }
    }

    private func habitBlock(for row: WidgetMatrixRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // Only the icon + name are accentable: the metrics
                // rank second, and content outside the accent group is
                // already dimmed by the system, which is the whole of
                // the hierarchy they need.
                HStack(spacing: 6) {
                    Image(systemName: row.habit.icon)
                        .font(.caption)
                        .foregroundStyle(row.habit.color.color)
                        .frame(width: 16, alignment: .center)
                    Text(row.habit.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(palette.foreground)
                }
                .widgetAccentable()
                Spacer(minLength: 4)
                WidgetMetricsChip(
                    streak: row.habit.currentStreak,
                    scorePercent: row.habit.scorePercent
                )
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

    private func emptyPlaceholder(isFilteredOut: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: isFilteredOut ? "line.3.horizontal.decrease.circle" : "square.grid.3x3")
                .font(.title2)
                .foregroundStyle(palette.foregroundSecondary)
            // Split rather than a ternary inside one `Text`: a
            // `Text(cond ? "A" : "B")` binds to the `StringProtocol`
            // overload and neither arm ever reaches the catalog.
            Group {
                if isFilteredOut {
                    Text("No picked habits to show")
                } else {
                    Text("No habits yet")
                }
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetAccentable()
    }

    /// Taken from the snapshot rather than the clock. The app builds
    /// `matrixDays` ending on the *logical* day, so under a non-midnight
    /// "Day starts at" hour `isDateInToday` would match no column at all
    /// between midnight and the rollover.
    private func isToday(_ day: Date) -> Bool {
        day == entry.snapshot.matrixDays.last
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

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .overlay {
                // Hollow = logged off-schedule. Same language the
                // main app's `MatrixCell` uses, thinner border for
                // the smaller cell.
                if let borderOpacity = cell.borderOpacity {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            color.color.opacity(borderOpacity),
                            lineWidth: 1.5
                        )
                }
            }
            .frame(height: size)
    }

    /// `.scored` / `.offSchedule` already carry their own alpha, so
    /// they survive the tint untouched. `.notDue` is the one opaque
    /// fill here, and an opaque fill is exactly what gets flattened
    /// into a solid block under Tinted / Clear — route it through the
    /// palette, which keeps it under the scored ramp's 0.2 floor so
    /// "never due" stays tellable from "due and missed".
    private var fill: Color {
        switch cell {
        case .future: Color.clear
        case .notDue: palette.notDueFill
        case .scored: color.color.opacity(cell.colorOpacity ?? 0)
        case .offSchedule: color.color.opacity(cell.offScheduleFillOpacity ?? 0)
        }
    }
}

#Preview("Populated", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated, habitIDs: [])
}

#Preview("Picked three", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(
        date: .now,
        snapshot: PreviewSnapshots.populated,
        habitIDs: PreviewSnapshots.pickedMatrixIDs
    )
}

#Preview("Empty", as: .systemLarge) {
    WeeklyGridLargeWidget()
} timeline: {
    SelectedSnapshotEntry(date: .now, snapshot: .empty, habitIDs: [])
}
