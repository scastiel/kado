import SwiftUI
import KadoCore

/// Key to the Overview ramp.
///
/// The grid encodes four states in one hue per row, and without this
/// the screen reads as decoration — which is exactly what the shipping
/// build's alternating light/full tiles did. The swatches are
/// deliberately **neutral grey**, not any habit's color: a legend drawn
/// in one habit's hue would look like it described that habit.
///
/// It wraps rather than scrolls, so it survives Dynamic Type without
/// hiding an item off the edge.
struct OverviewLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.kadoHairline)
                .frame(height: 1)
                .padding(.bottom, 14)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { items }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) { missed; partial }
                    HStack(spacing: 14) { complete; notScheduled }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var items: some View {
        missed
        partial
        complete
        notScheduled
    }

    private var missed: some View {
        item("Missed") { swatch.fill(Color.kadoTileMissed) }
    }

    private var partial: some View {
        item("Partial") { swatch.fill(Color.kadoForegroundTertiary.opacity(KadoTint.tilePartial)) }
    }

    private var complete: some View {
        item("Completed") { swatch.fill(Color.kadoForegroundSecondary) }
    }

    private var notScheduled: some View {
        item("Not scheduled") {
            swatch
                .fill(Color.kadoTileOffSchedule)
                .overlay { swatch.strokeBorder(Color.kadoTileOffScheduleRing, lineWidth: 1) }
        }
    }

    private var swatch: RoundedRectangle {
        RoundedRectangle(cornerRadius: KadoRadius.xs, style: .continuous)
    }

    private func item(
        _ title: LocalizedStringKey,
        @ViewBuilder mark: () -> some View
    ) -> some View {
        HStack(spacing: 6) {
            mark().frame(width: 13, height: 13)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Color.kadoForegroundSecondary)
        }
        .fixedSize()
    }
}

#Preview {
    OverviewLegend()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.kadoBackground)
}

#Preview("Dark") {
    OverviewLegend()
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.kadoBackground)
        .preferredColorScheme(.dark)
}
