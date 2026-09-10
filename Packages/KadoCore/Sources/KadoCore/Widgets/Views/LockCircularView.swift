import SwiftUI
import WidgetKit

/// One picked habit as a Lock Screen ring. `LockCircularWidget` in
/// the extension wraps it; the app draws it directly for the
/// listing's widget screenshot.
public struct LockCircularView: View {
    let entry: PickedSnapshotEntry

    public init(entry: PickedSnapshotEntry) {
        self.entry = entry
    }

    public var body: some View {
        if let row = entry.pickedRow {
            filled(row: row)
        } else {
            prompt
        }
    }

    private func filled(row: WidgetTodayRow) -> some View {
        Gauge(value: row.progress) {
            Image(systemName: row.habit.icon)
        } currentValueLabel: {
            currentLabel(for: row)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
    }

    @ViewBuilder
    private func currentLabel(for row: WidgetTodayRow) -> some View {
        switch row.habit.typeKind {
        case .binary, .negative:
            Image(systemName: row.status == .complete ? "checkmark" : "")
                .font(.caption2)
        case .counter, .timer:
            Text("\(Int(row.progress * 100))")
                .font(.caption2.monospacedDigit())
        }
    }

    private var prompt: some View {
        Image(systemName: "square.and.pencil")
            .widgetAccentable()
            .accessibilityLabel("Pick a habit")
    }
}
