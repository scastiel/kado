import AppIntents
import SwiftUI
import WidgetKit
import KadoCore

/// One habit row as it appears in the small and medium home
/// widgets. Score-shaded background, habit icon, truncated name,
/// and a type-aware indicator on the right.
///
/// Binary and negative rows wrap in `Button(intent:)` so a tap
/// invokes `CompleteHabitIntent`. Because the widget extension
/// can't safely open SwiftData, the intent is configured to open
/// the main app, which performs the toggle. Counter and timer
/// rows render plain and fall through to the widget's `widgetURL`.
struct HabitWidgetCell: View {
    let row: WidgetTodayRow

    var body: some View {
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
        row.status == .complete
    }

    private var background: Color {
        switch row.status {
        case .complete:
            return row.habit.color.color
        case .partial:
            return row.habit.color.color.opacity(0.3 + row.progress * 0.4)
        case .none:
            return Color(.quaternarySystemFill)
        }
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
