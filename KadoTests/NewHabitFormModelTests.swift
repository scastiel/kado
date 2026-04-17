import Testing
import Foundation
@testable import Kado

@Suite("NewHabitFormModel")
@MainActor
struct NewHabitFormModelTests {
    @Test("Initial state is invalid due to empty name")
    func initialInvalid() {
        let model = NewHabitFormModel()
        #expect(!model.isValid)
    }

    @Test("A daily habit with a trimmed name is valid")
    func dailyBinaryValid() {
        let model = NewHabitFormModel()
        model.name = "Meditate"
        #expect(model.isValid)
    }

    @Test("Name with only whitespace is invalid")
    func whitespaceNameInvalid() {
        let model = NewHabitFormModel()
        model.name = "   \n\t "
        #expect(!model.isValid)
    }

    @Test(".daysPerWeek requires count in 1...7")
    func daysPerWeekBounds() {
        let model = NewHabitFormModel()
        model.name = "Run"
        model.frequencyKind = .daysPerWeek
        model.daysPerWeek = 0
        #expect(!model.isValid)
        model.daysPerWeek = 8
        #expect(!model.isValid)
        model.daysPerWeek = 3
        #expect(model.isValid)
    }

    @Test(".specificDays requires a non-empty set")
    func specificDaysRequireDays() {
        let model = NewHabitFormModel()
        model.name = "Gym"
        model.frequencyKind = .specificDays
        model.specificDays = []
        #expect(!model.isValid)
        model.specificDays = [.monday]
        #expect(model.isValid)
    }

    @Test(".everyNDays requires interval >= 1")
    func everyNDaysBounds() {
        let model = NewHabitFormModel()
        model.name = "Clean"
        model.frequencyKind = .everyNDays
        model.everyNDays = 0
        #expect(!model.isValid)
        model.everyNDays = 2
        #expect(model.isValid)
    }

    @Test(".counter requires target > 0")
    func counterRequiresTarget() {
        let model = NewHabitFormModel()
        model.name = "Water"
        model.typeKind = .counter
        model.counterTarget = 0
        #expect(!model.isValid)
        model.counterTarget = 8
        #expect(model.isValid)
    }

    @Test(".timer requires target minutes > 0")
    func timerRequiresMinutes() {
        let model = NewHabitFormModel()
        model.name = "Read"
        model.typeKind = .timer
        model.timerTargetMinutes = 0
        #expect(!model.isValid)
        model.timerTargetMinutes = 30
        #expect(model.isValid)
    }

    @Test("frequency projection matches picked kind + params")
    func frequencyProjection() {
        let model = NewHabitFormModel()
        #expect(model.frequency == .daily)

        model.frequencyKind = .daysPerWeek
        model.daysPerWeek = 5
        #expect(model.frequency == .daysPerWeek(5))

        model.frequencyKind = .specificDays
        model.specificDays = [.tuesday, .thursday]
        #expect(model.frequency == .specificDays([.tuesday, .thursday]))

        model.frequencyKind = .everyNDays
        model.everyNDays = 4
        #expect(model.frequency == .everyNDays(4))
    }

    @Test("type projection matches picked kind + params (timer minutes → seconds)")
    func typeProjection() {
        let model = NewHabitFormModel()
        #expect(model.type == .binary)

        model.typeKind = .counter
        model.counterTarget = 6
        #expect(model.type == .counter(target: 6))

        model.typeKind = .timer
        model.timerTargetMinutes = 30
        #expect(model.type == .timer(targetSeconds: 30 * 60))

        model.typeKind = .negative
        #expect(model.type == .negative)
    }

    @Test("build() produces a HabitRecord with the projected fields")
    func buildRecord() {
        let model = NewHabitFormModel()
        model.name = "  Meditate  "
        model.frequencyKind = .specificDays
        model.specificDays = [.monday, .wednesday, .friday]
        model.typeKind = .counter
        model.counterTarget = 3

        let record = model.build()
        #expect(record.name == "Meditate") // trimmed
        #expect(record.frequency == .specificDays([.monday, .wednesday, .friday]))
        #expect(record.type == .counter(target: 3))
        #expect(record.archivedAt == nil)
    }

    @Test("Changing frequencyKind preserves other kinds' draft params")
    func kindToggleIsNonDestructive() {
        let model = NewHabitFormModel()
        model.daysPerWeek = 5
        model.specificDays = [.saturday, .sunday]
        model.everyNDays = 3

        model.frequencyKind = .daysPerWeek
        model.frequencyKind = .specificDays
        model.frequencyKind = .everyNDays
        model.frequencyKind = .daily

        #expect(model.daysPerWeek == 5)
        #expect(model.specificDays == [.saturday, .sunday])
        #expect(model.everyNDays == 3)
    }
}
