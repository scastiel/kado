import SwiftData
import SwiftUI

/// Detail screen for a single habit. Shows score, streak, frequency,
/// type, and a current-month completion grid. Toolbar actions open
/// the edit sheet and present an archive confirmation dialog; both
/// are disabled once the habit is archived.
struct HabitDetailView: View {
    @Bindable var habit: HabitRecord

    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingArchiveConfirmation = false
    @State private var showingTimerSheet = false

    private var isArchived: Bool { habit.archivedAt != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metricsRow
                quickLogSection
                MonthlyCalendarView(
                    habit: habit.snapshot,
                    completions: (habit.completions ?? []).map(\.snapshot)
                )
                CompletionHistoryList(habit: habit)
            }
            .padding()
        }
        .navigationTitle(Text(habit.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Edit")) {
                    showingEdit = true
                }
                .disabled(isArchived)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(
                    String(localized: "Archive"),
                    systemImage: "archivebox"
                ) {
                    showingArchiveConfirmation = true
                }
                .disabled(isArchived)
            }
        }
        .sheet(isPresented: $showingEdit) {
            NewHabitFormView(model: NewHabitFormModel(editing: habit))
        }
        .sheet(isPresented: $showingTimerSheet) {
            TimerLogSheet(habit: habit)
        }
        .confirmationDialog(
            String(localized: "Archive this habit?"),
            isPresented: $showingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Archive"), role: .destructive) {
                archive()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("Archived habits stop appearing on Today but keep their history.")
        }
    }

    private func archive() {
        habit.archivedAt = .now
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Quick-log

    @ViewBuilder
    private var quickLogSection: some View {
        switch habit.type {
        case .counter(let target):
            CounterQuickLogView(
                target: target,
                todayValue: todayCounterValue,
                onIncrement: incrementCounter,
                onDecrement: decrementCounter
            )
            .disabled(isArchived)
        case .timer:
            Button {
                showingTimerSheet = true
            } label: {
                Label("Log a session", systemImage: "timer")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(isArchived)
        case .binary, .negative:
            EmptyView()
        }
    }

    private var todayCounterValue: Double {
        habit.completions?
            .first { calendar.isDate($0.date, inSameDayAs: .now) }?
            .value ?? 0
    }

    private func incrementCounter() {
        CompletionLogger(calendar: calendar).incrementCounter(for: habit, in: modelContext)
        try? modelContext.save()
    }

    private func decrementCounter() {
        CompletionLogger(calendar: calendar).decrementCounter(for: habit, in: modelContext)
        try? modelContext.save()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(habit.name)
                .font(.largeTitle.weight(.bold))
            HStack(spacing: 12) {
                Label(frequencyLabel, systemImage: frequencyIcon)
                Label(typeLabel, systemImage: typeIcon)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if habit.archivedAt != nil {
                Text("Archived")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color(.tertiarySystemFill))
                    )
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricCard(
                title: String(localized: "Score"),
                value: scorePercent,
                systemImage: "chart.line.uptrend.xyaxis"
            )
            metricCard(
                title: String(localized: "Streak"),
                value: String(localized: "\(currentStreak) / best \(bestStreak)"),
                systemImage: "flame.fill"
            )
        }
    }

    private func metricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Computed metrics

    private var scorePercent: String {
        let score = scoreCalculator.currentScore(
            for: habit.snapshot,
            completions: (habit.completions ?? []).map(\.snapshot),
            asOf: .now
        )
        return "\(Int((score * 100).rounded()))%"
    }

    private var currentStreak: Int {
        streakCalculator.current(
            for: habit.snapshot,
            completions: (habit.completions ?? []).map(\.snapshot),
            asOf: .now
        )
    }

    private var bestStreak: Int {
        streakCalculator.best(
            for: habit.snapshot,
            completions: (habit.completions ?? []).map(\.snapshot),
            asOf: .now
        )
    }

    private var frequencyLabel: String {
        switch habit.frequency {
        case .daily:
            return String(localized: "Every day")
        case .daysPerWeek(let n):
            return String(localized: "\(n) days per week")
        case .specificDays(let days):
            let ordered: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
            let labels = ordered.filter(days.contains).map(shortWeekday(_:))
            return labels.joined(separator: " · ")
        case .everyNDays(let n):
            return String(localized: "Every \(n) days")
        }
    }

    private var frequencyIcon: String {
        switch habit.frequency {
        case .daily: "calendar"
        case .daysPerWeek: "calendar.badge.clock"
        case .specificDays: "calendar.day.timeline.left"
        case .everyNDays: "clock.arrow.circlepath"
        }
    }

    private var typeLabel: String {
        switch habit.type {
        case .binary: String(localized: "Yes / no")
        case .counter(let target): String(localized: "Counter · target \(Int(target))")
        case .timer(let seconds): String(localized: "Timer · target \(Int(seconds / 60)) min")
        case .negative: String(localized: "Avoid")
        }
    }

    private var typeIcon: String {
        switch habit.type {
        case .binary: "checkmark.circle"
        case .counter: "number.circle"
        case .timer: "timer"
        case .negative: "hand.raised"
        }
    }

    private func shortWeekday(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: String(localized: "Mon")
        case .tuesday: String(localized: "Tue")
        case .wednesday: String(localized: "Wed")
        case .thursday: String(localized: "Thu")
        case .friday: String(localized: "Fri")
        case .saturday: String(localized: "Sat")
        case .sunday: String(localized: "Sun")
        }
    }
}

/// Small wrapper for previews — fetches a seeded habit from the
/// preview container by name so the detail view sees a realistic
/// populated record.
private struct HabitDetailPreviewWrapper: View {
    let habitName: String
    let archived: Bool

    @Query private var habits: [HabitRecord]

    init(habitName: String, archived: Bool = false) {
        self.habitName = habitName
        self.archived = archived
        _habits = Query(
            filter: #Predicate<HabitRecord> { $0.name == habitName },
            sort: \HabitRecord.createdAt
        )
    }

    var body: some View {
        if let habit = habits.first {
            HabitDetailView(habit: habit)
                .onAppear {
                    if archived { habit.archivedAt = .now }
                }
        } else {
            ContentUnavailableView(
                "Seed habit not found",
                systemImage: "questionmark.diamond"
            )
        }
    }
}

#Preview("Daily — populated") {
    NavigationStack {
        HabitDetailPreviewWrapper(habitName: "Morning meditation")
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Specific days (Gym)") {
    NavigationStack {
        HabitDetailPreviewWrapper(habitName: "Gym")
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Counter (Drink water)") {
    NavigationStack {
        HabitDetailPreviewWrapper(habitName: "Drink water")
    }
    .modelContainer(PreviewContainer.shared)
}

#Preview("Archived") {
    NavigationStack {
        HabitDetailPreviewWrapper(habitName: "Morning meditation", archived: true)
    }
    .modelContainer(PreviewContainer.shared)
}
