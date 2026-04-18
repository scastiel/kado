import AppIntents
import SwiftUI
import WidgetKit
import KadoCore

/// One habit row as it appears in the small and medium home
/// widgets. Score-shaded background, habit icon, truncated name,
/// and a type-aware indicator on the right.
///
/// Binary and negative rows wrap the body in `Button(intent:)` so
/// a tap fires `CompleteHabitIntent` in-process — the widget
/// reloads on the next timeline refresh (or sooner, via the
/// app-side `WidgetCenter` reload triggers). Counter and timer
/// rows render plain — the widget's `widgetURL` opens the app for
/// per-type input.
struct HabitWidgetCell: View {
    let row: HabitTimelineRow

    var body: some View {
        switch row.habit.type {
        case .binary, .negative:
            Button(intent: CompleteHabitIntent(habit: HabitEntity(habit: row.habit))) {
                content
            }
            .buttonStyle(.plain)
        case .counter, .timer:
            content
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Image(systemName: row.habit.icon)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(isComplete ? Color.white : row.habit.color.color)
            Text(row.habit.name)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(isComplete ? Color.white : Color.primary)
            Spacer(minLength: 4)
            indicator
                .font(.caption2)
                .foregroundStyle(isComplete ? Color.white : row.habit.color.color)
        }
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
        row.state.status == .complete
    }

    private var background: Color {
        switch row.state.status {
        case .complete:
            return row.habit.color.color
        case .partial:
            return row.habit.color.color.opacity(0.3 + row.state.progress * 0.4)
        case .none:
            return Color(.quaternarySystemFill)
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch row.habit.type {
        case .binary, .negative:
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        case .counter(let target):
            Text(counterLabel(value: row.state.valueToday ?? 0, target: target))
                .monospacedDigit()
        case .timer(let targetSeconds):
            Text(timerLabel(seconds: row.state.valueToday ?? 0, target: targetSeconds))
                .monospacedDigit()
        }
    }

    private var accessibilityValue: String {
        switch row.habit.type {
        case .binary, .negative:
            return isComplete
                ? String(localized: "done", comment: "Widget accessibility: binary habit completed")
                : String(localized: "not done", comment: "Widget accessibility: binary habit not completed")
        case .counter(let target):
            return counterLabel(value: row.state.valueToday ?? 0, target: target)
        case .timer(let targetSeconds):
            return timerLabel(seconds: row.state.valueToday ?? 0, target: targetSeconds)
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
