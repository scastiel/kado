import Foundation

/// Counts reported by an import run, used both as a dry-run preview in
/// the confirmation sheet and as the outcome after a successful merge.
public struct ImportSummary: Hashable, Sendable {
    public var totalHabits: Int
    public var newHabits: Int
    public var updatedHabits: Int
    public var totalCompletions: Int
    public var newCompletions: Int
    public var updatedCompletions: Int

    public init(
        totalHabits: Int = 0,
        newHabits: Int = 0,
        updatedHabits: Int = 0,
        totalCompletions: Int = 0,
        newCompletions: Int = 0,
        updatedCompletions: Int = 0
    ) {
        self.totalHabits = totalHabits
        self.newHabits = newHabits
        self.updatedHabits = updatedHabits
        self.totalCompletions = totalCompletions
        self.newCompletions = newCompletions
        self.updatedCompletions = updatedCompletions
    }
}
