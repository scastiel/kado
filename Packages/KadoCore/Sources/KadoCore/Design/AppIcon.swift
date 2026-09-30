import Foundation

/// The icon Kadō wears on the Home Screen (#114). Every option is the
/// same mark in other colours; the artwork is rendered from
/// `branding/app-icons/` by `Scripts/render-app-icons.sh`.
///
/// Raw values are stored in `UserDefaults` (``AppIconDefaults``), so
/// they stay stable strings. What is stored is the user's *pick*; what
/// the Home Screen should show is `AppIcon.effective(preferred:isSupporter:)`,
/// since every icon but the default needs the Supporter pack.
nonisolated public enum AppIcon: String, CaseIterable, Codable, Sendable, Hashable {
    /// Sage on paper. The default, and the only free one.
    case kado
    /// The default's colours swapped: paper on sage.
    case ura
    /// Plum on blossom pink.
    case sakura
    /// Cream on maple red.
    case momiji
    /// Coral to violet.
    case yuyake
    /// Cyan to electric blue.
    case umi
    /// Lime to teal.
    case hotaru
    /// Violet to pink.
    case fuji

    /// The asset-name suffix shared by the `.appiconset` and the
    /// picker's preview image. Spelled out rather than derived from the
    /// raw value, so renaming a case can't silently orphan its artwork.
    private var assetSuffix: String {
        switch self {
        case .kado: "Kado"
        case .ura: "Ura"
        case .sakura: "Sakura"
        case .momiji: "Momiji"
        case .yuyake: "Yuyake"
        case .umi: "Umi"
        case .hotaru: "Hotaru"
        case .fuji: "Fuji"
        }
    }

    /// What `UIApplication.setAlternateIconName(_:)` takes: `nil` for
    /// the primary icon, else the `.appiconset` name listed in the
    /// Kado target's `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
    public var alternateIconName: String? {
        self == .kado ? nil : "AppIcon\(assetSuffix)"
    }

    /// The icon the system reports as current. A name no case claims —
    /// one a future build added, then a downgrade dropped — reads as
    /// the default rather than trapping.
    public init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .kado
    }

    /// The picker's thumbnail: an image set, since an `.appiconset`
    /// can't be read back at runtime. Light and dark variants, so the
    /// row shows the icon the Home Screen would.
    public var previewImageName: String {
        "AppIconPreview\(assetSuffix)"
    }
}

// MARK: - Supporter pack

/// Kadō's own icon is free; every alternate needs the Supporter pack.
/// Without it a paid pick shows the default — the stored choice is
/// kept, so it comes back the moment the pack does.
extension AppIcon: SupporterGated {
    public var requiresSupporterPack: Bool { self != .kado }

    public static let freeFallback = AppIcon.kado
}
