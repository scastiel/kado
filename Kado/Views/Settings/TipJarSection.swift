import SwiftUI
import KadoCore

/// Settings entry point for the Tip Jar. A single row that pushes
/// ``TipJarView``. Kept in its own "Support Kadō" section — separate from
/// the Feedback section — so tipping carries its own visual weight.
struct TipJarSection: View {
    var body: some View {
        Section("Support Kadō") {
            NavigationLink {
                TipJarView()
            } label: {
                Label("Leave a tip", systemImage: "heart")
            }
            .listRowBackground(Color.kadoBackgroundSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            TipJarSection()
        }
        .environment(\.tipJarStore, MockTipJarStore())
    }
}

#Preview("Dark") {
    NavigationStack {
        Form {
            TipJarSection()
        }
        .environment(\.tipJarStore, MockTipJarStore())
    }
    .preferredColorScheme(.dark)
}
