import StoreKit
import SwiftUI

struct ReviewPromptModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(\.reviewPromptService) private var reviewPromptService

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                if reviewPromptService.recordSession() {
                    requestReview()
                }
            }
    }
}

extension View {
    func reviewPromptOnForeground() -> some View {
        modifier(ReviewPromptModifier())
    }
}
