import Foundation
import Observation

/// Draft state for the New Habit sheet. Holds one stored property
/// per kind's associated value so toggling between `frequencyKind`
/// or `typeKind` options doesn't wipe partially-entered data.
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

    enum FrequencyKind: Hashable, CaseIterable {
        case daily, daysPerWeek, specificDays, everyNDays
    }

    enum HabitTypeKind: Hashable, CaseIterable {
        case binary, counter, timer, negative
    }

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
        return true
    }

    func build() -> HabitRecord {
        HabitRecord(
            name: trimmedName,
            frequency: frequency,
            type: type
        )
    }
}
