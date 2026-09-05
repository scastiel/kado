import SwiftUI
import KadoCore

/// The grouped surface behind a run of Today rows.
///
/// Replaces the `List` section this screen used to be. A `List` gives
/// separators and grouped corners for free, but not at the radius,
/// inset, or padding this design asks for — and its row insets fought
/// every attempt to line the hairline up with the text column.
///
/// The hairline is inset by exactly the mark column (38pt) plus the
/// row's column gap (12pt), so it begins under the habit's name rather
/// than under its icon. A separator that runs the full width cuts the
/// mark off from the row it belongs to.
struct HabitCard<Content: View>: View {
    @ViewBuilder var content: Content

    /// Mark width + column gap. Matches `HabitRowView`'s leading
    /// geometry; if that changes, this has to move with it.
    private static var hairlineInset: CGFloat { 50 }

    var body: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: 0) {
                ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.kadoHairline)
                            .frame(height: 1)
                            .padding(.leading, Self.hairlineInset)
                    }
                    subview
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: KadoRadius.group, style: .continuous)
                .fill(Color.kadoBackgroundSecondary)
        )
    }
}

/// The uppercase label above a card. Parallel phrasing across the two
/// Today sections ("Scheduled today" / "Not scheduled today") — the
/// shipping build paired "Scheduled" with "Not scheduled today", which
/// read as two different kinds of statement.
struct TodaySectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.96)
            .foregroundStyle(Color.kadoForegroundSecondary)
            .padding(.leading, 2)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 0) {
            TodaySectionHeader(title: "Scheduled today")
            HabitCard {
                Text("Row one").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
                Text("Row two").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
                Text("Row three").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
            }
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.kadoBackground)
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: 0) {
        TodaySectionHeader(title: "Not scheduled today")
        HabitCard {
            Text("Row one").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
            Text("Row two").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
        }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.kadoBackground)
    .preferredColorScheme(.dark)
}
