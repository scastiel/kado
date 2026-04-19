import SwiftUI
import CoreText

/// Bundled display-serif typography. Fraunces (variable font, SIL OFL)
/// is loaded on first launch and used for large titles, the HabitDetail
/// hero name, and the Overview score number. Body chrome stays on
/// SF Pro via `Font.system(...)`.
public enum KadoFont {

    /// Register the bundled variable font. Idempotent — Swift's
    /// `static let` once-semantics guarantee `registration` runs at
    /// most once regardless of how many call sites dispatch it.
    public static func register() {
        _ = registration
    }

    private static let registration: Void = {
        let filename = "Fraunces[SOFT,WONK,opsz,wght]"
        guard let url = Bundle.module.url(forResource: filename, withExtension: "ttf") else {
            #if DEBUG
            print("[KadoFont] Fraunces TTF not found in bundle — did you add it to Resources/Fonts?")
            #endif
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            #if DEBUG
            print("[KadoFont] Failed to register Fraunces: \(error.debugDescription)")
            #endif
        }
    }()

    public enum Style {
        case display
        case displayBold
        case serif
    }
}

public extension Font {
    /// Kadō display-serif font. Falls back to `.system(.serif)` if
    /// Fraunces isn't registered yet — keeps previews working.
    static func kado(_ style: KadoFont.Style, size: CGFloat) -> Font {
        switch style {
        case .display:     .custom("Fraunces-Regular", size: size, relativeTo: .largeTitle)
        case .displayBold: .custom("Fraunces-Medium",  size: size, relativeTo: .largeTitle)
        case .serif:       .custom("Fraunces-Regular", size: size, relativeTo: .title2)
        }
    }
}

public extension View {
    /// Kadō display-serif style — large titles, hero numbers, habit
    /// detail name.
    func kadoDisplay(size: CGFloat = 40, weight: Font.Weight = .regular) -> some View {
        self
            .font(.kado(weight == .regular ? .display : .displayBold, size: size))
            .kerning(-0.4)
            .foregroundStyle(Color.kadoForeground)
    }

    /// Uppercase mono micro-label — "MORNING", "SYNC", etc. Kept on
    /// SF Pro monospaced.
    func kadoEyebrow() -> some View {
        self
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(Color.kadoForegroundTertiary)
    }
}
