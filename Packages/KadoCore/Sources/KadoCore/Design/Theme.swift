import SwiftUI
import UIKit

public extension Color {

    // MARK: - Paper (surfaces)
    static let kadoPaper50  = Color(light: rgb(0.984, 0.973, 0.949), dark: rgb(0.078, 0.075, 0.059))
    static let kadoPaper100 = Color(light: rgb(0.957, 0.937, 0.902), dark: rgb(0.110, 0.102, 0.086))
    static let kadoPaper200 = Color(light: rgb(0.914, 0.882, 0.824), dark: rgb(0.153, 0.141, 0.125))
    static let kadoPaper300 = Color(light: rgb(0.851, 0.808, 0.722), dark: rgb(0.227, 0.204, 0.173))

    // MARK: - Ink (text)
    static let kadoInk900 = Color(light: rgb(0.106, 0.102, 0.090), dark: rgb(0.957, 0.937, 0.902))
    static let kadoInk700 = Color(light: rgb(0.216, 0.204, 0.180), dark: rgb(0.867, 0.835, 0.773))
    static let kadoInk500 = Color(light: rgb(0.376, 0.357, 0.318), dark: rgb(0.663, 0.627, 0.576))
    static let kadoInk300 = Color(light: rgb(0.576, 0.537, 0.482), dark: rgb(0.467, 0.431, 0.376))
    static let kadoInk100 = Color(light: rgb(0.749, 0.710, 0.643), dark: rgb(0.306, 0.275, 0.224))

    // MARK: - Sage (brand accent)
    static let kadoSage100 = Color(light: rgb(0.878, 0.914, 0.886), dark: rgb(0.122, 0.165, 0.137))
    static let kadoSage300 = Color(light: rgb(0.647, 0.741, 0.682), dark: rgb(0.208, 0.349, 0.267))
    static let kadoSage500 = Color(light: rgb(0.341, 0.478, 0.400), dark: rgb(0.431, 0.584, 0.506))
    /// Primary brand accent. Replaces the system blue tint.
    static let kadoSage    = Color(light: rgb(0.208, 0.349, 0.267), dark: rgb(0.620, 0.745, 0.663))
    static let kadoSage900 = Color(light: rgb(0.122, 0.227, 0.173), dark: rgb(0.769, 0.851, 0.796))

    // MARK: - Semantic aliases
    static let kadoBackground          = kadoPaper50
    static let kadoBackgroundSecondary = kadoPaper100
    static let kadoHairline            = kadoPaper200
    static let kadoDivider             = kadoPaper300
    static let kadoForeground          = kadoInk900
    static let kadoForegroundSecondary = kadoInk500
    static let kadoForegroundTertiary  = kadoInk300
    static let kadoAccent              = kadoSage
    static let kadoAccentTint          = kadoSage100
}

/// Corner radii. `card` is the default for habit rows and cells.
public enum KadoRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let card: CGFloat = 10
    public static let sheet: CGFloat = 14
    public static let hero: CGFloat = 20
}

/// 4pt baseline spacing — matches the web design system.
public enum KadoSpace {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s7: CGFloat = 32
    public static let s8: CGFloat = 40
}

/// Calm, ease-out motion. No springs, no bounces.
public enum KadoMotion {
    /// 200ms ease-out — default for toggles, progress rings, row fills.
    public static let base: Animation = .easeOut(duration: 0.20)
    /// 120ms ease-out — button presses, quick tap feedback.
    public static let fast: Animation = .easeOut(duration: 0.12)
    /// 320ms ease-out — ring fills, cross-screen transitions.
    public static let slow: Animation = .easeOut(duration: 0.32)
}

// MARK: - Private helpers

private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
    UIColor(red: r, green: g, blue: b, alpha: 1)
}

private extension Color {
    /// Dynamic color that resolves light vs. dark on every trait change.
    init(light: UIColor, dark: UIColor) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}
