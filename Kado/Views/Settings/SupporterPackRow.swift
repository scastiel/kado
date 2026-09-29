import SwiftUI
import KadoCore

/// Settings entry point for the Supporter pack: one row pushing
/// ``SupporterPackView``, first in the "Support Kadō" section above the
/// tip jar. This and the pickers' locks are the only places the pack is
/// mentioned — no nag anywhere else in the app.
struct SupporterPackRow: View {
    @Environment(\.supporterPack) private var store

    var body: some View {
        NavigationLink {
            SupporterPackView()
        } label: {
            LabeledContent {
                if store.isSupporter {
                    Text("Owned")
                }
            } label: {
                Label("Supporter pack", systemImage: "sparkles")
                    .foregroundStyle(Color.kadoAccent)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Settings.supporterPackRow)
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
}

#Preview {
    NavigationStack {
        Form {
            SupporterPackRow()
        }
        .environment(\.supporterPack, MockSupporterPackStore())
    }
}

#Preview("Dark, owned") {
    NavigationStack {
        Form {
            SupporterPackRow()
        }
        .environment(\.supporterPack, MockSupporterPackStore(isSupporter: true))
    }
    .preferredColorScheme(.dark)
}
