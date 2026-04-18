import Testing
import Foundation
import SwiftData
@testable import Kado
import KadoCore

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

    // MARK: - Edit mode

    @Test("init(editing:) pre-fills every field from the habit's current state")
    func editingInitPreFillsAllFields() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let record = HabitRecord(
            name: "Run",
            frequency: .everyNDays(3),
            type: .timer(targetSeconds: 25 * 60)
        )
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.isEditing)
        #expect(model.name == "Run")
        #expect(model.frequencyKind == .everyNDays)
        #expect(model.everyNDays == 3)
        #expect(model.typeKind == .timer)
        #expect(model.timerTargetMinutes == 25)
    }

    @Test("init(editing:) round-trips specificDays")
    func editingInitSpecificDays() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let record = HabitRecord(
            frequency: .specificDays([.tuesday, .thursday]),
            type: .counter(target: 5)
        )
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.frequencyKind == .specificDays)
        #expect(model.specificDays == [.tuesday, .thursday])
        #expect(model.typeKind == .counter)
        #expect(model.counterTarget == 5)
    }

    @Test("save(in:) on an editing model mutates the record in place")
    func editingSaveMutatesInPlace() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let original = HabitRecord(
            name: "Old",
            frequency: .daily,
            type: .binary
        )
        container.mainContext.insert(original)
        try container.mainContext.save()

        let model = NewHabitFormModel(editing: original)
        model.name = "New name"
        model.frequencyKind = .daysPerWeek
        model.daysPerWeek = 4
        model.typeKind = .counter
        model.counterTarget = 12

        let saved = model.save(in: container.mainContext)

        #expect(saved.id == original.id)
        #expect(original.name == "New name")
        #expect(original.frequency == .daysPerWeek(4))
        #expect(original.type == .counter(target: 12))

        let all = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(all.count == 1)
    }

    @Test("init(editing:) rounds sub-minute timer targets rather than truncating")
    func editingTimerSubMinuteRounds() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // 90 seconds rounds to 2 minutes (not 1 — truncation would).
        let record = HabitRecord(type: .timer(targetSeconds: 90))
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.timerTargetMinutes == 2)
    }

    @Test("init(editing:) floors a 30-second timer target to the 1-minute minimum")
    func editingTimerFloorsToOneMinute() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        // 30 seconds rounds to 0.5 → 1 (minimum). Silent truncation would
        // give 0, which would fail validation.
        let record = HabitRecord(type: .timer(targetSeconds: 30))
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.timerTargetMinutes >= 1)
    }

    @Test(".negative + .daysPerWeek is rejected by validation")
    func negativeDaysPerWeekInvalid() {
        let model = NewHabitFormModel()
        model.name = "Skip dessert"
        model.typeKind = .negative
        model.frequencyKind = .daysPerWeek
        model.daysPerWeek = 3
        #expect(!model.isValid)

        // Changing either half of the combo makes it valid.
        model.frequencyKind = .daily
        #expect(model.isValid)
        model.frequencyKind = .daysPerWeek
        model.typeKind = .binary
        #expect(model.isValid)
    }

    @Test("save(in:) on a new model inserts a new record")
    func newSaveInserts() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let model = NewHabitFormModel()
        model.name = "Fresh"

        let saved = model.save(in: container.mainContext)
        #expect(saved.name == "Fresh")

        let all = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(all.count == 1)
        #expect(all.first?.id == saved.id)
    }

    // MARK: - Appearance (color + icon)

    @Test("Default color is .blue and default icon is the curated default")
    func appearanceDefaults() {
        let model = NewHabitFormModel()
        #expect(model.color == .blue)
        #expect(model.icon == HabitIcon.default)
    }

    @Test("build() carries the picked color and icon")
    func buildCarriesAppearance() {
        let model = NewHabitFormModel()
        model.name = "Run"
        model.color = .mint
        model.icon = "figure.run"

        let record = model.build()
        #expect(record.color == .mint)
        #expect(record.icon == "figure.run")
    }

    @Test("init(editing:) pre-fills color and icon from the record")
    func editingInitAppearance() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let record = HabitRecord(name: "Read", color: .purple, icon: "book.fill")
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.color == .purple)
        #expect(model.icon == "book.fill")
    }

    // MARK: - Reminders

    @Test("Default reminder state is off at 9:00 local time")
    func reminderDefaults() {
        let model = NewHabitFormModel()
        #expect(model.remindersEnabled == false)
        let components = Calendar.current.dateComponents([.hour, .minute], from: model.reminderTime)
        #expect(components.hour == 9)
        #expect(components.minute == 0)
    }

    @Test("Toggling remindersEnabled off and back on preserves the chosen time")
    func reminderToggleIsNonDestructive() {
        let model = NewHabitFormModel()
        model.name = "Meditate"
        model.remindersEnabled = true
        let chosen = Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: .now)!
        model.reminderTime = chosen

        model.remindersEnabled = false
        model.remindersEnabled = true

        #expect(model.reminderTime == chosen)
    }

    @Test("build() maps reminderTime to hour and minute integers")
    func buildCarriesReminderFields() {
        let model = NewHabitFormModel()
        model.name = "Run"
        model.remindersEnabled = true
        model.reminderTime = Calendar.current.date(bySettingHour: 6, minute: 45, second: 0, of: .now)!

        let record = model.build()
        #expect(record.remindersEnabled == true)
        #expect(record.reminderHour == 6)
        #expect(record.reminderMinute == 45)
    }

    @Test("init(editing:) reconstitutes reminderTime from stored hour and minute")
    func editingInitReminder() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let record = HabitRecord(
            name: "Sleep",
            remindersEnabled: true,
            reminderHour: 22,
            reminderMinute: 30
        )
        container.mainContext.insert(record)

        let model = NewHabitFormModel(editing: record)
        #expect(model.remindersEnabled == true)
        let components = Calendar.current.dateComponents([.hour, .minute], from: model.reminderTime)
        #expect(components.hour == 22)
        #expect(components.minute == 30)
    }

    @Test("save(in:) on an editing model updates reminder fields in place")
    func editingSaveReminder() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let original = HabitRecord(name: "Stretch")
        container.mainContext.insert(original)
        try container.mainContext.save()

        let model = NewHabitFormModel(editing: original)
        model.remindersEnabled = true
        model.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 5, second: 0, of: .now)!
        _ = model.save(in: container.mainContext)

        #expect(original.remindersEnabled == true)
        #expect(original.reminderHour == 8)
        #expect(original.reminderMinute == 5)
    }

    @Test("save(in:) on an editing model updates color and icon in place")
    func editingSaveAppearance() throws {
        let container = try ModelContainer(
            for: HabitRecord.self, CompletionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let original = HabitRecord(name: "Swim", color: .blue, icon: "circle")
        container.mainContext.insert(original)
        try container.mainContext.save()

        let model = NewHabitFormModel(editing: original)
        model.color = .teal
        model.icon = "figure.pool.swim"
        _ = model.save(in: container.mainContext)

        #expect(original.color == .teal)
        #expect(original.icon == "figure.pool.swim")
    }
}
