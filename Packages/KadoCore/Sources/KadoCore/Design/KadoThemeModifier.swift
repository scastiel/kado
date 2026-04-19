import SwiftUI
import UIKit

/// Root-level theme wiring. Applies sage as the process tint, paints
/// the view background in paper, hides SwiftUI's default scroll
/// background so `Form` / `List` inherit the paper surface, and
/// configures the nav bar + tab bar appearance once.
public struct KadoThemeModifier: ViewModifier {

    public init() {}

    public func body(content: Content) -> some View {
        content
            .tint(.kadoSage)
            .background(Color.kadoBackground.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .onAppear(perform: Self.applyUIKitAppearance)
    }

    /// Configures `UINavigationBarAppearance` + `UITabBarAppearance`
    /// once per process. Called from `.onAppear` on the root view; the
    /// `static let` once-semantics make repeat calls free.
    private static let applyUIKitAppearance: () -> Void = {
        let once = ApplyOnce()
        return { once.run() }
    }()

    private final class ApplyOnce {
        private var didRun = false

        @MainActor
        func run() {
            guard !didRun else { return }
            didRun = true

            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            nav.backgroundColor = UIColor(Color.kadoBackground).withAlphaComponent(0.85)
            nav.shadowColor = UIColor(Color.kadoHairline)
            nav.titleTextAttributes = [
                .foregroundColor: UIColor(Color.kadoForeground)
            ]
            nav.largeTitleTextAttributes = [
                .foregroundColor: UIColor(Color.kadoForeground),
                .font: UIFont(name: "Fraunces-Regular", size: 34)
                    ?? UIFont.systemFont(ofSize: 34, weight: .semibold)
            ]
            UINavigationBar.appearance().standardAppearance = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactAppearance = nav

            let tab = UITabBarAppearance()
            tab.configureWithDefaultBackground()
            tab.backgroundColor = UIColor(Color.kadoBackground).withAlphaComponent(0.8)
            tab.shadowColor = UIColor(Color.kadoHairline)
            UITabBar.appearance().standardAppearance = tab
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
    }
}

public extension View {
    /// Apply Kadō's theme at the root of the app — typically on
    /// `ContentView`'s body.
    func kadoTheme() -> some View { modifier(KadoThemeModifier()) }
}
