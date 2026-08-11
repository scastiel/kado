import SwiftUI

/// One cell in the Overview matrix. Fills with the habit's color at
/// an opacity derived from the day's value. Non-scored cells render
/// neutral placeholders (tertiary fill for not-due days, empty for
/// future days).
///
/// Off-schedule completions render **hollow** — the same color as a
/// solid completion, but as a border around a pale interior. The grid
/// is 30 columns of pure schedule shape, and the gray `.notDue` cell
/// is how that schedule gets drawn; rendering a bonus day as an
/// ordinary completion would make a Mon/Wed/Fri row claim Saturday
/// was scheduled. A border says "done" at a glance while still
/// reading as different from the days the habit actually asked for.
///
/// Opacity is not available as the differentiator — it already
/// encodes `DailyValue` — and a glyph would not survive the widget's
/// smaller cells.
public struct MatrixCell: View {
    public let state: DayCell
    public let color: HabitColor
    public var size: CGFloat = 32

    public init(state: DayCell, color: HabitColor, size: CGFloat = 32) {
        self.state = state
        self.color = color
        self.size = size
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
            .overlay {
                if case .offSchedule = state {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            color.color.opacity(state.colorOpacity ?? 0),
                            lineWidth: 2
                        )
                }
            }
            .frame(width: size, height: size)
    }

    private var fill: Color {
        switch state {
        case .future:
            Color.clear
        case .notDue:
            Color(.tertiarySystemFill)
        case .scored:
            color.color.opacity(state.colorOpacity ?? 0)
        case .offSchedule:
            // Pale interior so the border carries the signal.
            color.color.opacity((state.colorOpacity ?? 0) * 0.25)
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
                ForEach([0.1, 0.5, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
                }
                ForEach([0.0, 0.5, 1.0], id: \.self) { s in
                    MatrixCell(state: .offSchedule(s), color: color)
                }
            }
        }
    }
    .padding()
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
                ForEach([0.1, 0.5, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
                }
                ForEach([0.0, 0.5, 1.0], id: \.self) { s in
                    MatrixCell(state: .offSchedule(s), color: color)
                }
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
