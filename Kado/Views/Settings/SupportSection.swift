import SwiftUI

struct SupportSection: View {
    var body: some View {
        Section("Feedback") {
            Link(destination: Self.appStoreReviewURL) {
                Label("Rate Kado on the App Store", systemImage: "star.bubble")
            }
            Link(destination: Self.feedbackURL) {
                Label("Send Feedback", systemImage: "envelope")
            }
        }
    }

    private static let appStoreReviewURL = URL(
        string: "https://apps.apple.com/app/id6762570244?action=write-review"
    )!

    private static let feedbackURL = URL(
        string: "mailto:sebastien@castiel.me?subject=Kado%20Feedback"
    )!
}

#Preview {
    Form {
        SupportSection()
    }
}

#Preview("Dark") {
    Form {
        SupportSection()
    }
    .preferredColorScheme(.dark)
}
