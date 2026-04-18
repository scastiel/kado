import SwiftUI

/// One cell in the Overview matrix. Fills with the habit's color at
/// an opacity derived from its EMA score. Non-scored cells render
/// neutral placeholders (tertiary fill for not-due days, empty for
/// future days).
struct MatrixCell: View {
    let state: DayCell
    let color: HabitColor
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
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
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
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
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9, 1.0], id: \.self) { s in
                    MatrixCell(state: .scored(s), color: color)
                }
            }
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
