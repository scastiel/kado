import SwiftData
import SwiftUI
import KadoCore

/// Detail screen for a single habit. Shows score, streak, frequency,
/// type, and a current-month completion grid. Toolbar actions open
/// the edit sheet and present an archive confirmation dialog; both
/// are disabled once the habit is archived.
///
/// Renders from value-type snapshots and never stores a
/// `HabitRecord`. `HabitDetailLoader` re-resolving the id on every
/// render is necessary but *not* sufficient on its own: SwiftUI
/// re-evaluates this view's retained struct against the previous
/// store's record before the loader's re-resolution reaches it, and
/// reading `habit.name` off an invalidated object traps inside
/// SwiftData. Holding only structs means there is nothing left to
/// invalidate; mutations resolve the record by id against the current
/// `@Query` (issue #63).
///
/// **A view that mutates records holds its own `@Query` and resolves
/// them from it — `TodayView`'s shape.** The first cut of #63 gave
/// this view no query and resolved the record with a
/// `modelContext.fetch(…)` inside each mutation, and the screen
/// stopped following its own edits: a counter stepped a second time,
/// a timer re-logged — any value-only save — landed in the store and
/// never re-rendered `HabitDetailLoader`. Only an insert or delete,
/// which changes the query's result set, woke it up (issue #80: the
/// popover, the quick-log, score, streak and history all froze
/// together). Two things were measured, and both halves of the rule
/// come from them: a fetch between a view's tracked read and the
/// mutation leaves the observer un-notified even for the same instance
/// (`ObservationAfterFetchTests`), and with `allHabits` in place the
/// loader re-renders on every save. Keep both.
struct HabitDetailView: View {
    let habit: Habit
    let completions: [Completion]

    /// Read only from mutations, never from `body`. Unfiltered for
    /// the same reasons as `HabitDetailLoader`'s query, and so an
    /// archived habit stays resolvable while its screen is up. Its
    /// presence is load-bearing — see the type comment.
    @Query(sort: \HabitRecord.sortOrder) private var allHabits: [HabitRecord]

    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var today
    @Environment(\.dayBoundary) private var dayBoundary
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingArchiveConfirmation = false
    @State private var showingTimerSheet = false
    @State private var showingScoreInfo = false
    @State private var editingDay: Date? = nil
    /// The latest quick-log or popover step, for the haptic — one seam
    /// for both, so a popover step on today doesn't also tick through
    /// the quick-log control that displays the same value.
    @State private var quickLog: QuickLogEvent?
    /// Seeded in `.onAppear` rather than defaulted to `.now`: `@State`
    /// is initialised before the environment is injected, so a wall-clock
    /// default would leak in ahead of `\.today` and open the grid on the
    /// wrong month before the rollover on the 1st.
    @State private var displayedMonth: Date?

    private var isArchived: Bool { habit.archivedAt != nil }

    /// The live record behind this screen, resolved against the store
    /// that is mounted now. Called from mutations only — never from a
    /// `body`, which is the whole point. A Swift-side lookup in the
    /// query's array, never a `fetch` — see the type comment.
    private var record: HabitRecord? {
        allHabits.first { $0.id == habit.id }
    }

    /// The live record behind one snapshotted completion, walked from
    /// `record`'s relationship for the same reason.
    private func completionRecord(for snapshot: Completion) -> CompletionRecord? {
        record?.completions?.first { $0.id == snapshot.id }
    }

    private var trackingSinceLabel: String? {
        let effective = habit.effectiveStart(completions: completions, calendar: calendar)
        let createdDay = calendar.startOfDay(for: habit.createdAt)
        let effectiveDay = calendar.startOfDay(for: effective)
        guard effectiveDay != createdDay else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .medium
        return String(localized: "Tracking since \(formatter.string(from: effective))")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metricsRow
                quickLogSection
                MonthlyCalendarView(
                    habit: habit,
                    completions: completions,
                    month: Binding(
                        get: { displayedMonth ?? today },
                        set: { displayedMonth = $0 }
                    ),
                    selectedDay: isArchived ? .constant(nil) : $editingDay,
                    navigable: true,
                    popoverContent: { day in
                        DayEditPopover(
                            habit: habit,
                            date: day,
                            currentValue: currentValue(on: day),
                            currentNote: currentNote(on: day),
                            onToggle: { toggle(on: day) },
                            onSetCounter: { value in setCounter(value, on: day) },
                            onSetTimerSeconds: { seconds in setTimerSeconds(seconds, on: day) },
                            onClear: { clear(on: day) },
                            onNoteChanged: { note in setNote(note, on: day) }
                        )
                        .presentationCompactAdaptation(.popover)
                    }
                )
                CompletionHistoryList(
                    habitType: habit.type,
                    completions: completions,
                    onDelete: historyDelete
                )
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
        .quickLogFeedback(quickLog)
        .onAppear { if displayedMonth == nil { displayedMonth = today } }
        .navigationTitle("")
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
            if let record {
                NewHabitFormView(model: NewHabitFormModel(editing: record))
            } else {
                HabitUnavailableView()
            }
        }
        .sheet(isPresented: $showingTimerSheet) {
            if let record {
                TimerLogSheet(habit: record)
            } else {
                HabitUnavailableView()
            }
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

    /// The instant to stamp on anything logged right now — see the
    /// matching helper on `TodayView`.
    private var loggingInstant: Date {
        dayBoundary.loggingInstant(for: .now, on: today)
    }

    private func archive() {
        guard let record else { return }
        record.archivedAt = loggingInstant
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
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
            .accessibilityIdentifier(AccessibilityID.HabitDetail.logSessionButton)
        case .binary, .negative:
            EmptyView()
        }
    }

    private var todayCounterValue: Double {
        completion(on: today)?.value ?? 0
    }

    private func incrementCounter() {
        guard let record else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: loggingInstant)
        logger.incrementCounter(for: record, on: loggingInstant, in: modelContext)
        recordQuickLog(from: before, to: before + 1)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func decrementCounter() {
        guard let record else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: loggingInstant)
        logger.decrementCounter(for: record, on: loggingInstant, in: modelContext)
        recordQuickLog(from: before, to: max(0, before - 1))
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    /// Derived from the mutation, not read back: the store may still
    /// hold a just-deleted record until the save lands.
    private func recordQuickLog(from old: Double, to new: Double) {
        guard let event = QuickLogEvent.next(after: quickLog, type: habit.type, oldValue: old, newValue: new) else {
            return
        }
        quickLog = event
    }

    // MARK: - Past-day popover mutations

    /// The snapshotted completion covering a day, if there is one.
    private func completion(on day: Date) -> Completion? {
        completions.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    private func currentValue(on day: Date) -> Double {
        completion(on: day)?.value ?? 0
    }

    private func currentNote(on day: Date) -> String? {
        completion(on: day)?.note
    }

    private func toggle(on day: Date) {
        guard let record else { return }
        CompletionToggler(calendar: calendar).toggleToday(for: record, on: day, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func setCounter(_ value: Double, on day: Date) {
        guard let record else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: day)
        logger.setCounter(for: record, on: day, to: value, in: modelContext)
        recordQuickLog(from: before, to: max(0, value))
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func setTimerSeconds(_ seconds: TimeInterval, on day: Date) {
        // logTimerSession would create a zero-value record for 0 seconds;
        // route "stepped to 0" through clear() so the day returns to missed.
        if seconds <= 0 {
            clear(on: day)
            return
        }
        guard let record else { return }
        let logger = CompletionLogger(calendar: calendar)
        let before = logger.value(for: record, on: day)
        logger.logTimerSession(
            for: record,
            seconds: seconds,
            on: day,
            in: modelContext
        )
        recordQuickLog(from: before, to: seconds)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func setNote(_ note: String?, on day: Date) {
        guard let record else { return }
        CompletionLogger(calendar: calendar).setNote(for: record, on: day, to: note, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private func clear(on day: Date) {
        // Matched on the snapshot's id rather than re-derived from the
        // day, so the record cleared is the one the user was looking at.
        guard let snapshot = completion(on: day),
              let existing = completionRecord(for: snapshot)
        else { return }
        let before = existing.value
        if existing.note != nil {
            existing.value = 0
        } else {
            CompletionLogger(calendar: calendar).delete(existing, in: modelContext)
        }
        recordQuickLog(from: before, to: 0)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    /// What the History list gets to delete with: nothing once the
    /// habit is archived, like every other mutation on this screen.
    /// A `guard` rather than `isArchived ? nil : deleteCompletion` —
    /// the ternary over a `@MainActor` method reference is one the
    /// compiler can't type ("failed to produce diagnostic"), and
    /// inline in the body it surfaces as "ambiguous use of 'init'" on
    /// the enclosing `ScrollView`.
    private var historyDelete: ((Completion) -> Void)? {
        guard !isArchived else { return nil }
        return { deleteCompletion($0) }
    }

    /// Delete from a History row's long-press menu.
    private func deleteCompletion(_ snapshot: Completion) {
        guard let existing = completionRecord(for: snapshot) else { return }
        CompletionLogger(calendar: calendar).delete(existing, in: modelContext)
        try? modelContext.save()
        WidgetReloader.reloadAll(using: modelContext)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(habit.name)
                .kadoDisplay(size: 34)
            HStack(spacing: 12) {
                Label(frequencyLabel, systemImage: frequencyIcon)
                Label(typeLabel, systemImage: typeIcon)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let trackingSince = trackingSinceLabel {
                Label(trackingSince, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            if habit.archivedAt != nil {
                Text("Archived")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.kadoHairline)
                    )
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            scoreCard
            metricCard(
                title: String(localized: "Streak"),
                value: String(localized: "\(currentStreak) / best \(bestStreak)"),
                systemImage: "flame.fill"
            )
        }
    }

    private var scoreCard: some View {
        Button {
            showingScoreInfo = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Label("Score", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                Text(scorePercent)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: KadoRadius.card)
                    .fill(Color.kadoBackgroundSecondary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.HabitDetail.scoreCard)
        .accessibilityHint(Text("Shows how the score is calculated."))
        .sheet(isPresented: $showingScoreInfo) {
            ScoreExplanationSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
            RoundedRectangle(cornerRadius: KadoRadius.card)
                .fill(Color.kadoBackgroundSecondary)
        )
    }

    // MARK: - Computed metrics

    private var scorePercent: String {
        let score = scoreCalculator.currentScore(
            for: habit,
            completions: completions,
            asOf: today
        )
        return "\(Int((score * 100).rounded()))%"
    }

    private var currentStreak: Int {
        streakCalculator.current(for: habit, completions: completions, asOf: today)
    }

    private var bestStreak: Int {
        streakCalculator.best(for: habit, completions: completions, asOf: today)
    }

    private var frequencyLabel: String {
        switch habit.frequency {
        case .daily:
            return String(localized: "Every day")
        case .daysPerWeek(let n):
            return String(localized: "\(n) days per week")
        case .specificDays(let days):
            let ordered = Weekday.week(startingOn: calendar.firstWeekday)
            let labels = ordered.filter(days.contains).map(\.localizedMedium)
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
            HabitDetailView(
                habit: habit.snapshot,
                completions: (habit.completions ?? []).compactMap(\.snapshot)
            )
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

#Preview("Dark") {
    NavigationStack {
        HabitDetailPreviewWrapper(habitName: "Drink water")
    }
    .modelContainer(PreviewContainer.shared)
    .preferredColorScheme(.dark)
}
