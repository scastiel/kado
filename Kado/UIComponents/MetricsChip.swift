import SwiftUI
import KadoCore

/// `🔥 streak · score%` caption used wherever a habit's current
/// situational state is surfaced inline (Today row, Overview label
/// overlay). Streak hidden when zero so calm rows stay calm. Caption2
/// + monospaced digits keep it dense; flame uses `.orange` so it
/// reads consistently regardless of the habit's accent color.
struct MetricsChip: View {
    let streak: Int
    let scorePercent: Int

    var body: some View {
        HStack(spacing: 6) {
            if streak > 0 {
                // Hand-rolled "label" — Label's default icon-to-title
                // gap is sized for body text and reads as loose at
                // .caption2.
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                    Text("\(streak)")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.orange)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(scorePercent)%")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MetricsChip(streak: 0, scorePercent: 30)
        MetricsChip(streak: 3, scorePercent: 65)
        MetricsChip(streak: 42, scorePercent: 92)
    }
    .padding()
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: 12) {
        MetricsChip(streak: 0, scorePercent: 30)
        MetricsChip(streak: 12, scorePercent: 87)
    }
    .padding()
    .preferredColorScheme(.dark)
}
