import SwiftUI
import WidgetKit
import KadoCore

/// The round lock-screen "button" for the whole day: a ring that
/// closes as habits get done, with *completed / scheduled* in the
/// middle. Sibling of `LockCircularWidget`, which shows one picked
/// habit; this one needs no configuration, so it is a static widget on
/// the shared snapshot.
struct LockDayProgressWidget: Widget {
    let kind: String = "dev.scastiel.kado.widget.lockDayProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotTimelineProvider()) { entry in
            LockDayProgressView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(Text("Daily Progress"))
        .description(Text("How many of today's habits are done, as a ring."))
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockDayProgressView: View {
    let entry: SnapshotEntry

    private var progress: DayProgress { entry.snapshot.dayProgress }

    var body: some View {
        // The capacity style is the one built for "N of M": a thick
        // ring that reads as a fill level, with the count centred.
        // System-drawn, so it already adapts to the lock screen's
        // vibrant and tinted renderings.
        Gauge(value: progress.fraction) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            label
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var label: some View {
        if progress.total == 0 {
            // A rest day. A dash rather than "0/0", which would read as
            // a day the user failed.
            Text(verbatim: "–")
                .font(.system(.body, design: .rounded).weight(.medium))
        } else {
            Text("\(progress.completed)/\(progress.total)")
                .font(.system(.footnote, design: .rounded).weight(.semibold).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
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

#Preview("Partial", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.populated)
}

#Preview("All done", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: PreviewSnapshots.allDone)
}

#Preview("Rest day", as: .accessoryCircular) {
    LockDayProgressWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .empty)
}
