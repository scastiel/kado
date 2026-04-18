import SwiftUI
import KadoCore

/// Horizontal row of color swatches. The selected swatch shows a
/// check; others are plain circles in their own color.
struct HabitColorPicker: View {
    @Binding var selection: HabitColor

    var body: some View {
        HStack(spacing: 12) {
            ForEach(HabitColor.allCases, id: \.self) { color in
                Button {
                    selection = color
                } label: {
                    swatch(for: color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
                .accessibilityAddTraits(selection == color ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatch(for color: HabitColor) -> some View {
        Circle()
            .fill(color.color)
            .frame(width: 30, height: 30)
            .overlay {
                if selection == color {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        selection == color ? Color.primary.opacity(0.25) : Color.clear,
                        lineWidth: 2
                    )
            }
    }
}

#Preview("Picker") {
    @Previewable @State var color: HabitColor = .mint
    return Form {
        Section("Color") {
            HabitColorPicker(selection: $color)
        }
    }
}
