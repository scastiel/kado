import SwiftUI
import WidgetKit

/// Explicit fallback when even the compact grid cannot accommodate the
/// user's text size. The enclosing widget's existing widgetURL opens
/// Today or Overview, without silently dropping a picked habit.
struct WidgetOpenAppHint: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.habitTheme) private var habitTheme

    var body: some View {
        Text("Open Kadō to see all habits")
            .font(.caption)
            .foregroundStyle(WidgetPalette(renderingMode: renderingMode, theme: habitTheme).foregroundSecondary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }
}
