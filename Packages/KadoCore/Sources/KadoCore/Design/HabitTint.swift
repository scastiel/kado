import Foundation

/// The habit-coloured surfaces, named after where they appear, each an
/// amount of the habit's base mixed over the page ground in Oklab
/// (`HabitColor.tint(_:)`). The design handoff's derivation table,
/// verbatim — views take a surface, never a number, so "every
/// habit-coloured surface is one of these" stays true.
nonisolated public enum HabitTint: Sendable, CaseIterable {
    /// The 38pt leading circle on a Today row, behind the icon.
    case mark
    /// The `+5m` chip on a timer row.
    case timerPill
    /// The `+` stepper button on a counter row, and the binary check
    /// circle that is styled to match it.
    case counterPill
    /// The "Slipped" tag on a negative row.
    case slippedTag
    /// The ring around a not-yet-complete mark.
    case outline
    /// An Overview tile at a middling day value.
    case tilePartial
    /// An Overview tile at the bottom of the scored ramp — a scheduled
    /// day with nothing logged. Kept coloured, not neutral, so it
    /// stays tellable from a day that was never due.
    case tileLight

    /// The fraction of the base over the page, 0…1.
    public var amount: Double {
        switch self {
        case .mark: 0.16
        case .timerPill: 0.18
        case .counterPill: 0.14
        case .slippedTag: 0.20
        case .outline: 0.36
        case .tilePartial: 0.45
        case .tileLight: 0.20
        }
    }
}
