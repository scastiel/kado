import SwiftUI

/// Plain-English explanation of how the habit score is calculated,
/// shown as a medium sheet when the user taps the Score card in the
/// habit detail view. Distilled from `docs/habit-score.md` — four
/// short points covering meaning, recency weighting, scheduled-only
/// evaluation, and the intentional slow climb for young habits.
struct ScoreExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    bullet("It reflects your habit's strength over time, not a streak.")
                    bullet("Recent days weigh more than older ones. A missed day loses about half its impact after two weeks.")
                    bullet("Only scheduled days count. If your habit runs Mon/Wed/Fri, other days are skipped.")
                    bullet("It starts at 0% and climbs slowly. A young habit can read low even when you're perfect — that's intentional.")
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(Text("About this score"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Light") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ScoreExplanationSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
}

#Preview("Dark") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ScoreExplanationSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
}
