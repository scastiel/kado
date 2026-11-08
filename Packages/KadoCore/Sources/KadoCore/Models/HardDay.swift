import Foundation

/// A hard day on a yes/no habit: the user showed up and did the
/// minimum version of it. It keeps the streak and counts as done for
/// the day, but is recorded and drawn apart from a full day, and the
/// score gives it half credit.
///
/// Stored in the completion's `value` rather than in a field of its
/// own. A binary habit has always written `1`; a hard day writes
/// `HardDay.value`. `value` already travels through SwiftData,
/// CloudKit and both backup formats, so nothing needs a schema or a
/// backup-format bump — and a build that predates hard days reads any
/// value above zero as done, so a synced or imported hard day degrades
/// to a plain check rather than to a miss.
nonisolated public enum HardDay {
    /// What a hard day records, and what the score credits it with:
    /// half a full day, the same partial credit a counter gets at half
    /// its target.
    public static let value: Double = 0.5

    /// Whether `value` records a hard day on a habit of `type`. Only
    /// yes/no habits have hard days. Anything strictly between nothing
    /// and a full day counts, so a hand-edited backup can't land in a
    /// state that is neither.
    public static func isHardDay(value: Double, for type: HabitType) -> Bool {
        type == .binary && value > 0 && value < 1
    }
}
