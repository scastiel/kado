import SwiftUI
import WidgetKit

/// The small home widget's content — up to five habits due today as
/// tappable, score-shaded chips. `TodayGridSmallWidget` in the
/// extension wraps it in a `StaticConfiguration`; the app draws it
/// directly for the listing's widget screenshot.
public struct TodayGridSmallView: View {
    let entry: SnapshotEntry

    private let limit = 5

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        if entry.snapshot.today.isEmpty {
            TodayEmptyPlaceholder()
        } else {
            VStack(spacing: 4) {
                ForEach(entry.snapshot.today.prefix(limit)) { row in
                    HabitWidgetCell(row: row)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// What the small and medium widgets show when nothing is due.
public struct TodayEmptyPlaceholder: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    public init() {}

    public var body: some View {
        let palette = WidgetPalette(renderingMode: renderingMode)
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(palette.foregroundSecondary)
            Text("All done")
                .font(.caption)
                .foregroundStyle(palette.foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The only content on the tile, so it belongs in the accent
        // group. Without this the whole widget falls into the dimmed
        // default group and the caption's own alpha dims it a second
        // time — leaving the empty state fainter than it was before
        // any of this.
        .widgetAccentable()
    }
}
