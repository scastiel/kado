import SwiftUI
import WidgetKit

/// The round Lock Screen "button" for the whole day: a ring that
/// closes as habits get done, with the Kadō mark in the middle.
/// `LockDayProgressWidget` in the extension wraps it; the app draws
/// it directly for the listing's widget screenshot.
public struct LockDayProgressView: View {
    let entry: SnapshotEntry

    public init(entry: SnapshotEntry) {
        self.entry = entry
    }

    private var progress: DayProgress { entry.snapshot.dayProgress }

    public var body: some View {
        // The capacity style is the one built for "N of M": a thick
        // ring that reads as a fill level. System-drawn, so it already
        // adapts to the lock screen's vibrant and tinted renderings.
        // The count itself is the ring; the centre carries the mark, so
        // the button reads as Kadō's at a glance. VoiceOver still gets
        // the numbers.
        Gauge(value: progress.fraction) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            mark
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The ensō from `branding/kado-mark.svg`, as a template image:
    /// the lock screen keeps only its alpha and paints it in the
    /// widget's tint, which is exactly what a one-colour brush stroke
    /// wants. The asset lives in this package's own catalog so the
    /// extension and the app draw the same file.
    private var mark: some View {
        Image("KadoMark", bundle: .module)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundStyle(.primary)
    }

    private var accessibilityLabel: String {
        if progress.total == 0 {
            return String(localized: "No habits due today")
        }
        return String(
            localized: "\(progress.completed) of \(progress.total) habits done today",
            comment: "Medium widget VoiceOver summary. Arg 1 completed, arg 2 total."
        )
    }
}
