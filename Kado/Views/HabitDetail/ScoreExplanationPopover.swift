import SwiftUI

/// Plain-English explanation of how the habit score is calculated,
/// shown as a popover when the user taps the Score card in the
/// habit detail view. Distilled from `docs/habit-score.md` — four
/// short points covering meaning, recency weighting, scheduled-only
/// evaluation, and the intentional slow climb for young habits.
struct ScoreExplanationPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("About this score", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                bullet("It reflects your habit's strength over time, not a streak.")
                bullet("Recent days weigh more than older ones. A missed day loses about half its impact after two weeks.")
                bullet("Only scheduled days count. If your habit runs Mon/Wed/Fri, other days are skipped.")
                bullet("It starts at 0% and climbs slowly. A young habit can read low even when you're perfect — that's intentional.")
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
        }
        .padding()
        .frame(minWidth: 260, maxWidth: 320)
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Light") {
    ScoreExplanationPopover()
}

#Preview("Dark") {
    ScoreExplanationPopover()
        .preferredColorScheme(.dark)
}
