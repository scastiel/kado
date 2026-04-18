import SwiftData
import SwiftUI
import KadoCore

/// Modal sheet for creating a new habit. Scoped to the four core
/// fields (name, frequency, type) — icon, color, reminders, and
/// createdAt editing land with later PRs.
struct NewHabitFormView: View {
    @Bindable var model: NewHabitFormModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @FocusState private var nameFocused: Bool
    @State private var saveTick: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                appearanceSection
                frequencySection
                typeSection
            }
            .navigationTitle(model.isEditing
                ? String(localized: "Edit Habit")
                : String(localized: "New Habit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!model.isValid)
                }
            }
            .sensoryFeedback(.success, trigger: saveTick)
            .onAppear { nameFocused = true }
        }
    }

    private var nameSection: some View {
        Section {
            TextField(String(localized: "Habit name"), text: $model.name)
                .focused($nameFocused)
                .submitLabel(.done)
        }
    }

    private var appearanceSection: some View {
        Section(String(localized: "Appearance")) {
            HabitColorPicker(selection: $model.color)
            HabitIconPicker(selection: $model.icon, tint: model.color.color)
        }
    }

    private var frequencySection: some View {
        Section(String(localized: "Frequency")) {
            Picker(String(localized: "Repeats"), selection: $model.frequencyKind) {
                Text("Every day").tag(NewHabitFormModel.FrequencyKind.daily)
                Text("A few times a week").tag(NewHabitFormModel.FrequencyKind.daysPerWeek)
                Text("Specific days").tag(NewHabitFormModel.FrequencyKind.specificDays)
                Text("Every N days").tag(NewHabitFormModel.FrequencyKind.everyNDays)
            }

            switch model.frequencyKind {
            case .daily:
                EmptyView()
            case .daysPerWeek:
                Stepper(
                    String(localized: "\(model.daysPerWeek) days per week"),
                    value: $model.daysPerWeek,
                    in: 1...7
                )
            case .specificDays:
                WeekdayPicker(selection: $model.specificDays)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            case .everyNDays:
                Stepper(
                    String(localized: "Every \(model.everyNDays) days"),
                    value: $model.everyNDays,
                    in: 1...60
                )
            }
        }
    }

    private var typeSection: some View {
        Section(String(localized: "Type")) {
            Picker(String(localized: "How is it measured?"), selection: $model.typeKind) {
                Text("Yes / no").tag(NewHabitFormModel.HabitTypeKind.binary)
                Text("Counter").tag(NewHabitFormModel.HabitTypeKind.counter)
                Text("Timer").tag(NewHabitFormModel.HabitTypeKind.timer)
                Text("Avoid").tag(NewHabitFormModel.HabitTypeKind.negative)
            }

            switch model.typeKind {
            case .binary, .negative:
                EmptyView()
            case .counter:
                Stepper(
                    String(localized: "Target: \(Int(model.counterTarget))"),
                    value: $model.counterTarget,
                    in: 1...999,
                    step: 1
                )
            case .timer:
                Stepper(
                    String(localized: "Target: \(model.timerTargetMinutes) min"),
                    value: $model.timerTargetMinutes,
                    in: 1...240
                )
            }
        }
    }

    private func save() {
        guard model.isValid else { return }
        model.save(in: modelContext)
        saveTick += 1
        dismiss()
    }
}

#Preview("Default") {
    NewHabitFormView(model: NewHabitFormModel())
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Pre-filled counter") {
    let model = NewHabitFormModel()
    model.name = "Drink water"
    model.typeKind = .counter
    model.counterTarget = 8
    return NewHabitFormView(model: model)
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Pre-filled specific days") {
    let model = NewHabitFormModel()
    model.name = "Gym"
    model.frequencyKind = .specificDays
    model.specificDays = [.monday, .wednesday, .friday]
    return NewHabitFormView(model: model)
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Dark") {
    let model = NewHabitFormModel()
    model.name = "Gym"
    model.frequencyKind = .specificDays
    model.specificDays = [.monday, .wednesday, .friday]
    return NewHabitFormView(model: model)
        .modelContainer(PreviewContainer.emptyContainer())
        .preferredColorScheme(.dark)
}
