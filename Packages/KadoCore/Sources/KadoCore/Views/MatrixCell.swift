import SwiftUI

/// One cell in the Overview matrix.
///
/// A row is a single hue at a small number of fixed intensities —
/// complete, partial, barely started — so the eye can compare rows
/// without a legend for each. The two states that are *not* the hue
/// carry the most meaning:
///
/// - **Missed** (scheduled, nothing logged) is a neutral fill. Drawing
///   it in the habit's own color, as the previous continuous ramp did
///   at its 0.2 floor, made a missed day and a barely-started day the
///   same picture.
/// - **Not scheduled** is a ring around an almost-empty tile. For a
///   habit that runs three days a week, most of the row is this state,
///   and it must not read as failure.
///
/// Off-schedule completions keep their hollow treatment — pale
/// interior, full-hue ring. The grid is a picture of the schedule, and
/// rendering a bonus day as an ordinary completion would make a
/// Mon/Wed/Fri row claim Saturday was scheduled (issue #57).
public struct MatrixCell: View {
    public let state: DayCell
    public let color: HabitColor
    /// Fixed edge length, or `nil` to fill the available width and
    /// stay square — which is what the Overview grid wants, since its
    /// columns divide the screen evenly.
    public var size: CGFloat?

    public init(state: DayCell, color: HabitColor, size: CGFloat? = 32) {
        self.state = state
        self.color = color
        self.size = size
    }

    public var body: some View {
        shape
            .fill(fill)
            .overlay { ring }
            .modifier(CellSizing(size: size))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: KadoRadius.tile, style: .continuous)
    }

    private var fill: Color {
        switch state.appearance {
        case .empty: Color.clear
        case .missed: Color.kadoTileMissed
        case .notScheduled: Color.kadoTileOffSchedule
        case .hue(let opacity, _): color.color.opacity(opacity)
        }
    }

    @ViewBuilder
    private var ring: some View {
        switch state.appearance {
        case .notScheduled:
            shape.strokeBorder(Color.kadoTileOffScheduleRing, lineWidth: 1)
        case .hue(_, ringed: true):
            shape.strokeBorder(color.color, lineWidth: 2)
        case .empty, .missed, .hue(_, ringed: false):
            EmptyView()
        }
    }
}

/// Fixed square, or flexible-width square. Split into a modifier
/// because the two branches aren't the same opaque type.
private struct CellSizing: ViewModifier {
    let size: CGFloat?

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size, height: size)
        } else {
            content.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        }
    }
}

#Preview("Cell states") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(HabitColor.allCases, id: \.self) { color in
            HStack(spacing: 4) {
                Text(color.rawValue.capitalized)
                    .font(.caption.monospaced())
                    .frame(width: 60, alignment: .leading)
                MatrixCell(state: .future, color: color)
                MatrixCell(state: .notDue, color: color)
                ForEach([0.0, 0.3, 0.7, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
                }
                ForEach([0.0, 1.0], id: \.self) { s in
                    MatrixCell(state: .offSchedule(s), color: color)
                }
            }
        }
    }
    .padding()
    .background(Color.kadoBackground)
}

#Preview("Dark") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(HabitColor.allCases, id: \.self) { color in
            HStack(spacing: 4) {
                Text(color.rawValue.capitalized)
                    .font(.caption.monospaced())
                    .frame(width: 60, alignment: .leading)
                MatrixCell(state: .future, color: color)
                MatrixCell(state: .notDue, color: color)
                ForEach([0.0, 0.3, 0.7, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
                }
                ForEach([0.0, 1.0], id: \.self) { s in
                    MatrixCell(state: .offSchedule(s), color: color)
                }
            }
        }
    }
    .padding()
    .background(Color.kadoBackground)
    .preferredColorScheme(.dark)
}
