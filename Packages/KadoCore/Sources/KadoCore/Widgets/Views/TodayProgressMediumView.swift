import SwiftUI
import WidgetKit

/// The medium home widget's content — a two-column habit grid plus a
/// progress summary, narrowed to the habits the user picked in the
/// widget-edit sheet. `TodayProgressMediumWidget` in the extension
/// wraps it; the app draws it directly for the listing's widget
/// screenshot.
public struct TodayProgressMediumView: View {
    let entry: SelectedSnapshotEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(entry: SelectedSnapshotEntry) {
        self.entry = entry
    }

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    private var rows: [WidgetTodayRow] {
        entry.todayRows(limit: WidgetHabitLimit.medium)
    }

    private var isFilteredOut: Bool {
        entry.isFilteredOut(limit: WidgetHabitLimit.medium)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if rows.isEmpty {
                TodayEmptyPlaceholder(isFilteredOut: isFilteredOut)
            } else {
                cellGrid
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        // Counts the pick when there is one, the whole day when there
        // isn't — otherwise the summary describes habits this tile
        // deliberately hides. And no count at all when nothing in the
        // pick is due today: "0 / 0 done" over dimmed rows, or over
        // the placeholder, says nothing they don't.
        let progress = entry.progress(limit: WidgetHabitLimit.medium)
        return HStack {
            Text("Today")
                .font(.headline)
                .foregroundStyle(palette.foreground)
                .widgetAccentable()
            Spacer()
            if !entry.hasNothingDue(limit: WidgetHabitLimit.medium) {
                Text(
                    String(
                        localized: "\(progress.completed) / \(progress.total) done",
                        comment: "Widget progress summary. Arg 1 is completed count, arg 2 is total count."
                    )
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(palette.foregroundSecondary)
            }
        }
    }

    private var cellGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ],
            spacing: 4
        ) {
            ForEach(rows) { row in
                HabitWidgetCell(row: row)
            }
        }
    }
}
