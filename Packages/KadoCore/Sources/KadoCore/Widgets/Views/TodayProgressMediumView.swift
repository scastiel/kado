import SwiftUI
import WidgetKit

/// The medium home widget's content — a two-column habit grid plus a
/// progress summary. `TodayProgressMediumWidget` in the extension
/// wraps it; the app draws it directly for the listing's widget
/// screenshot.
public struct TodayProgressMediumView: View {
    let entry: SnapshotEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    private let limit = 8

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if entry.snapshot.today.isEmpty {
                TodayEmptyPlaceholder()
            } else {
                cellGrid
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack {
            Text("Today")
                .font(.headline)
                .foregroundStyle(palette.foreground)
                .widgetAccentable()
            Spacer()
            Text(
                String(
                    localized: "\(entry.snapshot.completedToday) / \(entry.snapshot.totalDueToday) done",
                    comment: "Widget progress summary. Arg 1 is completed count, arg 2 is total count."
                )
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(palette.foregroundSecondary)
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
            ForEach(entry.snapshot.today.prefix(limit)) { row in
                HabitWidgetCell(row: row)
            }
        }
    }
}
