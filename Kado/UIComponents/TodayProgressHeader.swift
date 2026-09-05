import SwiftUI
import KadoCore

/// Today's title block: the screen title, a day-progress bar, and the
/// one line that explains what the percentages on the rows mean.
///
/// The bar answers a question the list itself never could — "how much
/// of today is left?" — which previously required counting filled
/// circles. It counts **scheduled** habits only: a habit the schedule
/// didn't ask for today can be logged, but it can't make the day
/// incomplete, so including it would let the bar go backwards when a
/// user adds a habit.
///
/// The caption below it labels the row percentages once for the whole
/// screen. Repeating "strength" on every row was never an option at
/// this width, and an unexplained `43%` beside a habit reads as
/// "43% done today", which is the opposite of reassuring on a day the
/// user has just completed.
struct TodayProgressHeader: View {
    let doneCount: Int
    let scheduledCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard scheduledCount > 0 else { return 0 }
        return min(Double(doneCount) / Double(scheduledCount), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today")
                .kadoDisplay(size: 40, weight: .medium)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 10) {
                track
                Text("\(doneCount) of \(scheduledCount) done")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(doneCount) of \(scheduledCount) done"))

            Text("Percentages show habit strength.")
                .font(.system(size: 12))
                .foregroundStyle(Color.kadoForegroundSecondary)
        }
    }

    private var track: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.kadoHairline)
                Capsule()
                    .fill(Color.kadoBrandSolid)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 4)
        .animation(reduceMotion ? nil : KadoMotion.base, value: fraction)
    }
}

/// The add-habit button, moved out of the top-right toolbar and into
/// thumb reach. Creating a habit is the one action on this screen that
/// isn't a row, and on a modern phone the top corner is the hardest
/// place on the display to reach one-handed.
struct AddHabitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.kadoOnBrandSolid)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.kadoBrandSolid))
                .shadow(color: Color.black.opacity(0.26), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "New habit"))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        TodayProgressHeader(doneCount: 3, scheduledCount: 5)
        TodayProgressHeader(doneCount: 0, scheduledCount: 4)
        TodayProgressHeader(doneCount: 4, scheduledCount: 4)
        AddHabitButton {}
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.kadoBackground)
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: 24) {
        TodayProgressHeader(doneCount: 3, scheduledCount: 5)
        AddHabitButton {}
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.kadoBackground)
    .preferredColorScheme(.dark)
}
