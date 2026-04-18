import SwiftUI

/// A curated palette of habit colors. Each case resolves to a SwiftUI
/// `Color` that adapts to light and dark mode via Apple's system hues.
///
/// Raw values are stable strings so the on-disk / CloudKit shape
/// survives enum reordering.
nonisolated public enum HabitColor: String, Codable, Sendable, Hashable, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case purple

    public var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .purple: .purple
        }
    }
}
