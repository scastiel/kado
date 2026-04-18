import SwiftUI
import KadoCore

/// Grid of curated SF Symbols. The selected icon renders on a tinted
/// background; others sit in a neutral fill.
struct HabitIconPicker: View {
    @Binding var selection: String
    var tint: Color = .accentColor

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
            .foregroundStyle(selection == icon ? Color.white : tint)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selection == icon ? tint : Color(.tertiarySystemFill))
            }
    }
}

#Preview("Picker") {
    @Previewable @State var icon: String = "book.fill"
    return Form {
        Section("Icon") {
            HabitIconPicker(selection: $icon, tint: HabitColor.mint.color)
        }
    }
}
