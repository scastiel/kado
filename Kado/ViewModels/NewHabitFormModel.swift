import Foundation
import Observation
import SwiftData

/// Draft state for the New Habit sheet. Holds one stored property
/// per kind's associated value so toggling between `frequencyKind`
/// or `typeKind` options doesn't wipe partially-entered data.
/// Reused for edit mode via `init(editing:)`.
@MainActor
@Observable
final class NewHabitFormModel {
    var name: String = ""

    var frequencyKind: FrequencyKind = .daily
    var daysPerWeek: Int = 3
    var specificDays: Set<Weekday> = [.monday, .wednesday, .friday]
    var everyNDays: Int = 2

    var typeKind: HabitTypeKind = .binary
    var counterTarget: Double = 1
    var timerTargetMinutes: Int = 10

    /// When non-nil, save mutates this record in place instead of
    /// creating a new one.
    private(set) var editingRecord: HabitRecord?

    enum FrequencyKind: Hashable, CaseIterable {
        case daily, daysPerWeek, specificDays, everyNDays
    }

    enum HabitTypeKind: Hashable, CaseIterable {
        case binary, counter, timer, negative
    }

    init() {}

    /// Pre-fill the form from an existing habit and remember the
    /// record so `save(in:)` updates it in place.
    convenience init(editing record: HabitRecord) {
        self.init()
        self.editingRecord = record
        self.name = record.name
        switch record.frequency {
        case .daily:
            self.frequencyKind = .daily
        case .daysPerWeek(let n):
            self.frequencyKind = .daysPerWeek
            self.daysPerWeek = n
        case .specificDays(let days):
            self.frequencyKind = .specificDays
            self.specificDays = days
        case .everyNDays(let n):
            self.frequencyKind = .everyNDays
            self.everyNDays = n
        }
        switch record.type {
        case .binary:
            self.typeKind = .binary
        case .counter(let target):
            self.typeKind = .counter
            self.counterTarget = target
        case .timer(let seconds):
            self.typeKind = .timer
            // Round so sub-minute targets surface at least 1 minute on edit
            // rather than silently truncating to 0. Users editing a
            // 90-second habit see "2 min" rather than "1 min."
            self.timerTargetMinutes = max(1, Int((seconds / 60).rounded()))
        case .negative:
            self.typeKind = .negative
        }
    }

    var isEditing: Bool { editingRecord != nil }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var frequency: Frequency {
        switch frequencyKind {
        case .daily: .daily
        case .daysPerWeek: .daysPerWeek(daysPerWeek)
        case .specificDays: .specificDays(specificDays)
        case .everyNDays: .everyNDays(everyNDays)
        }
    }

    var type: HabitType {
        switch typeKind {
        case .binary: .binary
        case .counter: .counter(target: counterTarget)
        case .timer: .timer(targetSeconds: TimeInterval(timerTargetMinutes) * 60)
        case .negative: .negative
        }
    }

    var isValid: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch frequencyKind {
        case .daily: break
        case .daysPerWeek: guard (1...7).contains(daysPerWeek) else { return false }
        case .specificDays: guard !specificDays.isEmpty else { return false }
        case .everyNDays: guard everyNDays >= 1 else { return false }
        }
        switch typeKind {
        case .binary, .negative: break
        case .counter: guard counterTarget > 0 else { return false }
        case .timer: guard timerTargetMinutes > 0 else { return false }
        }
        // .negative + .daysPerWeek has ambiguous semantics (streak counts
        // completions that represent failures) — reject the combination
        // until there's a clear product call.
        if typeKind == .negative && frequencyKind == .daysPerWeek {
            return false
        }
        return true
    }

    func build() -> HabitRecord {
        HabitRecord(
            name: trimmedName,
            frequency: frequency,
            type: type
        )
    }

    /// Inserts a new record or mutates the existing one in place,
    /// then saves. Returns the final record (new or edited).
    @discardableResult
    func save(in context: ModelContext) -> HabitRecord {
        if let record = editingRecord {
            record.name = trimmedName
            record.frequency = frequency
            record.type = type
            try? context.save()
            return record
        } else {
            let record = build()
            context.insert(record)
            try? context.save()
            return record
        }
    }
}
