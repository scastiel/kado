import SwiftUI
import WidgetKit

/// One picked habit on the Lock Screen: icon, name, streak and a
/// score bar. `LockRectangularWidget` in the extension wraps it; the
/// app draws it directly for the listing's widget screenshot.
public struct LockRectangularView: View {
    let entry: PickedSnapshotEntry

    public init(entry: PickedSnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let row = entry.pickedRow {
            filled(row: row)
        } else {
            pickPrompt
        }
    }

    private func filled(row: WidgetTodayRow) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: row.habit.icon)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.habit.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(row.streak)d")
                        .font(.caption2.monospacedDigit())
                        .fixedSize(horizontal: true, vertical: false)
                    scoreBar(progress: row.progress)
                        .frame(maxWidth: .infinity)
                    Text("\(row.scorePercent)%")
                        .font(.caption2.monospacedDigit())
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            Spacer(minLength: 0)
        }
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
    }

    private func scoreBar(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.3))
                Capsule()
                    .fill(.primary)
                    .frame(width: max(4, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: 4)
    }

    private var pickPrompt: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
            Text("Tap to pick a habit")
                .font(.caption)
                .lineLimit(2)
        }
        .widgetAccentable()
    }
}
