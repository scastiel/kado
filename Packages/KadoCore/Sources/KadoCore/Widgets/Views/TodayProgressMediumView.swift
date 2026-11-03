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
    @Environment(\.habitTheme) private var habitTheme

    public init(entry: SelectedSnapshotEntry) {
        self.entry = entry
    }

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode, theme: habitTheme)
    }

    private var rows: [WidgetTodayRow] {
        entry.todayRows(limit: WidgetHabitLimit.medium)
    }

    private var isFilteredOut: Bool {
        entry.isFilteredOut(limit: WidgetHabitLimit.medium)
    }

    public var body: some View {
        Group {
            if rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    TodayEmptyPlaceholder(isFilteredOut: isFilteredOut)
                }
            } else {
                // Measure every row before choosing a fit. A lazy grid
                // cannot supply the whole grid's intrinsic height.
                ViewThatFits(in: .vertical) {
                    populatedContent(verticalPadding: 5, spacing: 8, rowSpacing: 4)
                    populatedContent(verticalPadding: 2, spacing: 4, rowSpacing: 2)
                    VStack(alignment: .leading, spacing: 4) {
                        header
                        WidgetOpenAppHint()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func populatedContent(
        verticalPadding: CGFloat, spacing: CGFloat, rowSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
            Grid(horizontalSpacing: 6, verticalSpacing: rowSpacing) {
                ForEach(0..<((rows.count + 1) / 2), id: \.self) { index in
                    GridRow {
                        HabitWidgetCell(row: rows[index * 2], verticalPadding: verticalPadding)
                            .frame(minWidth: 0, maxWidth: .infinity)
                        if index * 2 + 1 < rows.count {
                            HabitWidgetCell(row: rows[index * 2 + 1], verticalPadding: verticalPadding)
                                .frame(minWidth: 0, maxWidth: .infinity)
                        } else {
                            // Preserve the leading column for an odd
                            // last row without adding height of its own.
                            Color.clear
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .gridCellUnsizedAxes(.vertical)
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
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
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
