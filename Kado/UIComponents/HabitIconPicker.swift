import SwiftUI
import KadoCore

/// Grid of curated SF Symbols. The selected icon renders on a fill in
/// the habit's hue, its glyph in the page colour; others sit in a
/// neutral fill with the glyph in the hue's ink — the base itself is
/// under 3:1 on the hairline for half the palette.
struct HabitIconPicker: View {
    @Binding var selection: String
    var tint: HabitColor

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 36), spacing: 10),
        count: 5
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(HabitIcon.curated, id: \.self) { icon in
                Button {
                    selection = icon
                } label: {
                    cell(for: icon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon)
                .accessibilityAddTraits(selection == icon ? [.isSelected] : [])
            }
        }
    }

    private func cell(for icon: String) -> some View {
        Image(systemName: icon)
            .font(.title3)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .foregroundStyle(selection == icon ? tint.onFill : tint.onTint)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selection == icon ? tint.color : Color.kadoHairline)
            }
    }
}

#Preview("Picker") {
    @Previewable @State var icon: String = "book.fill"
    return Form {
        Section("Icon") {
            HabitIconPicker(selection: $icon, tint: .mint)
        }
    }
}

#Preview("Dark") {
    @Previewable @State var icon: String = "book.fill"
    return Form {
        Section("Icon") {
            HabitIconPicker(selection: $icon, tint: .yellow)
        }
    }
    .preferredColorScheme(.dark)
}
