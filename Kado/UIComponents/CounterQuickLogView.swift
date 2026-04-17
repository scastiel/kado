import SwiftUI

/// Quick-log control for counter habits on the detail view.
/// Shows today's value next to the target, with `−` and `+`
/// buttons on either side. Minus is disabled at zero. A success
/// haptic fires once when `todayValue` first meets `target`.
struct CounterQuickLogView: View {
    let target: Double
    let todayValue: Double
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    private var targetReached: Bool { todayValue >= target }
    private var canDecrement: Bool { todayValue > 0 }

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(Color(.secondarySystemFill))
                    )
                    .foregroundStyle(canDecrement ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)
            .accessibilityLabel(String(localized: "Decrement"))

            VStack(spacing: 2) {
                Text("\(Int(todayValue))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(targetReached ? Color.accentColor : Color.primary)
                Text(String(localized: "of \(Int(target))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Increment"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .sensoryFeedback(.success, trigger: targetReached) { old, new in
            !old && new
        }
    }
}

#Preview("Under target") {
    CounterQuickLogView(target: 8, todayValue: 3, onIncrement: {}, onDecrement: {})
        .padding()
}

#Preview("At target") {
    CounterQuickLogView(target: 8, todayValue: 8, onIncrement: {}, onDecrement: {})
        .padding()
}

#Preview("Over target") {
    CounterQuickLogView(target: 8, todayValue: 12, onIncrement: {}, onDecrement: {})
        .padding()
}

#Preview("At zero (minus disabled)") {
    CounterQuickLogView(target: 8, todayValue: 0, onIncrement: {}, onDecrement: {})
        .padding()
}

#Preview("Dark") {
    CounterQuickLogView(target: 8, todayValue: 3, onIncrement: {}, onDecrement: {})
        .padding()
        .preferredColorScheme(.dark)
}
