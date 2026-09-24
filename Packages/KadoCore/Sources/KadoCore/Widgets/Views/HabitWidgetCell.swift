import AppIntents
import SwiftUI
import WidgetKit

/// One habit row as it appears in the small and medium home
/// widgets. Score-shaded background, habit icon, truncated name,
/// and a type-aware indicator on the right.
///
/// Binary and negative rows wrap in `Button(intent:)` so a tap
/// invokes `CompleteHabitIntent`. Because the widget extension
/// can't safely open SwiftData, the intent is configured to open
/// the main app, which performs the toggle. Counter and timer
/// rows render plain and fall through to the widget's `widgetURL`.
/// A picked habit that isn't due today (`row.isDueToday == false`)
/// renders dimmed with "Not today" and no button at all: it is on
/// the tile because the user asked for it, not because it is owed.
///
/// Colours go through `WidgetPalette` rather than reaching for paper
/// and ink directly: under the Home Screen's Tinted and Clear
/// appearances the system re-tints every opaque pixel with a single
/// colour, which would otherwise flatten a completed row's white
/// label into the block behind it.
///
/// Lives in `KadoCore` rather than the extension so the app can draw
/// it too — the App Store screenshot of the widgets is assembled from
/// these views rendered in-app, not photographed off a Home Screen.
public struct HabitWidgetCell: View {
    let row: WidgetTodayRow

    @Environment(\.widgetRenderingMode) private var renderingMode

    public init(row: WidgetTodayRow) {
        self.row = row
    }

    private var palette: WidgetPalette {
        WidgetPalette(renderingMode: renderingMode)
    }

    public var body: some View {
        if !row.isDueToday {
            notDueContent
        } else {
            switch row.habit.typeKind {
            case .binary, .negative:
                Button(intent: CompleteHabitIntent(habit: HabitEntity(widgetHabit: row.habit))) {
                    content
                }
                .buttonStyle(.plain)
            case .counter, .timer:
                content
            }
        }
    }

    /// The picked-but-not-scheduled row: secondary ink on the not-due
    /// wash, the same pairing the weekly grid uses for a day that was
    /// never due, so it reads as "not owed" rather than "missed".
    ///
    /// `ViewThatFits` decides the tag: "Not today" in words where the
    /// row is wide enough for a name beside it (the medium tile), a
    /// calendar-minus glyph where it isn't (the small tile — a name
    /// squeezed to "…" next to a full tag says less than a glyph next
    /// to a name). The name's ideal width is held at ~six characters
    /// so the words variant is judged on "does a readable name fit
    /// beside the tag", not on the longest habit name: on the small
    /// tile it doesn't, and the glyph wins.
    private var notDueContent: some View {
        ViewThatFits(in: .horizontal) {
            notDueRow {
                Text("Not today")
                    .font(.caption2)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            notDueRow {
                Image(systemName: "calendar.badge.minus")
                    .font(.caption2)
            }
        }
        // Not `.widgetAccentable()`: the dimmed default group is the
        // right rank for a row that asks nothing of the user today.
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.notDueFill)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
        .accessibilityValue(String(localized: "Not today", comment: "Widget row for a picked habit that isn't scheduled today"))
    }

    private func notDueRow<Tag: View>(@ViewBuilder tag: () -> Tag) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.habit.icon)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(palette.foregroundSecondary)
            Text(row.habit.name)
                .font(.caption)
                .lineLimit(1)
                .frame(minWidth: 40, idealWidth: 40, maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(palette.foregroundSecondary)
            tag()
                .foregroundStyle(palette.foregroundSecondary)
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: row.habit.icon)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(palette.glyphColor(row.habit.color, status: row.status))
            Text(row.habit.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(palette.labelColor(row.habit.color, status: row.status))
            Spacer(minLength: 4)
            indicator
                .font(.caption2)
                .foregroundStyle(palette.glyphColor(row.habit.color, status: row.status))
        }
        // Order matters, and is load-bearing: `.widgetAccentable()`
        // must stay *above* `.background`, so the fill is added
        // outside the accentable subtree. Fold the background up into
        // the `HStack` and the fill joins the accent group alongside
        // the label — both render as one flat tint under Clear and the
        // text disappears again, with every test still green.
        .widgetAccentable()
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(background)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.habit.name)
        .accessibilityValue(accessibilityValue)
    }

    private var isComplete: Bool {
        row.status == .complete
    }

    private var background: Color {
        palette.habitFill(row.habit.color, status: row.status, progress: row.progress)
    }

    @ViewBuilder
    private var indicator: some View {
        switch row.habit.typeKind {
        case .binary, .negative:
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        case .counter:
            if let target = row.habit.target {
                Text(counterLabel(value: row.valueToday ?? 0, target: target))
                    .monospacedDigit()
            }
        case .timer:
            if let target = row.habit.target {
                Text(timerLabel(seconds: row.valueToday ?? 0, target: target))
                    .monospacedDigit()
            }
        }
    }

    private var accessibilityValue: String {
        switch row.habit.typeKind {
        case .binary, .negative:
            return isComplete
                ? String(localized: "done", comment: "Widget accessibility: binary habit completed")
                : String(localized: "not done", comment: "Widget accessibility: binary habit not completed")
        case .counter:
            guard let target = row.habit.target else { return "" }
            return counterLabel(value: row.valueToday ?? 0, target: target)
        case .timer:
            guard let target = row.habit.target else { return "" }
            return timerLabel(seconds: row.valueToday ?? 0, target: target)
        }
    }

    private func counterLabel(value: Double, target: Double) -> String {
        let cur = Int(value.rounded())
        let tgt = Int(target)
        return "\(cur)/\(tgt)"
    }

    private func timerLabel(seconds: Double, target: Double) -> String {
        let curMin = Int(seconds / 60)
        let tgtMin = Int(target / 60)
        return "\(curMin)/\(tgtMin)m"
    }
}
