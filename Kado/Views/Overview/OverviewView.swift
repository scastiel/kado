import SwiftData
import SwiftUI
import KadoCore

/// Overview tab: habits × days matrix.
///
/// Layout (single horizontal scroll):
/// - One full-width `ScrollView(.horizontal)` holds a VStack that,
///   per habit, alternates a clear "name" spacer and a cells row.
///   Every cell row moves together because there's only one scroll
///   state.
/// - A sibling VStack overlays the scroll view with the habit
///   labels, positioned over the clear spacer rows. It has a
///   transparent background and `.allowsHitTesting(false)` so the
///   scroll + cell taps still reach the layer below.
/// - Outer `ScrollView(.vertical)` keeps the "Overview" title
///   collapsing like Today and Settings.
///
/// Tapping a cell opens `DayEditPopover` on that (habit × day). The
/// popover is fed value snapshots — the same `Completion` array the
/// matrix is computed from — and its callbacks resolve the live
/// `HabitRecord` from `records` only inside the mutation, never a
/// fetch. That is what keeps the matrix following its own edits: a
/// view mutating through its own `@Query` re-renders on a value-only
/// save (issue #80), and nothing retained across renders holds a
/// record that a container swap could invalidate (issue #63).
struct OverviewView: View {
    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.sortOrder
    )
    private var records: [HabitRecord]

    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var now
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.streakCalculator) private var streakCalculator
    @Environment(\.habitScoreCalculator) private var scoreCalculator
    @Environment(\.modelContext) private var modelContext

    @State private var selection: CellSelection?
    @State private var showingNewHabit = false
    /// The latest popover step, for the haptic — recorded at the
    /// mutation site, as on the detail screen.
    @State private var quickLog: QuickLogEvent?

    private static let dayWindow = 30
    private static let cellSize: CGFloat = 36
    private static let cellSpacing: CGFloat = 6
    private static let labelHeight: CGFloat = 28
    private static let labelBottomPadding: CGFloat = 8
    private static let rowGap: CGFloat = 12
    private static let headerHeight: CGFloat = 40

    /// The cell whose popover is up. Addressed by id and day only: the
    /// popover reads its value from the current render, so nothing
    /// captured at tap time can go stale under it.
    struct CellSelection: Equatable {
        let habitID: UUID
        let date: Date
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kadoBackground.ignoresSafeArea())
                .navigationTitle("Overview")
                .sheet(isPresented: $showingNewHabit) {
                    NewHabitFormView(model: NewHabitFormModel())
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if records.isEmpty {
            emptyState
        } else {
            matrix
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No habits yet", systemImage: "square.grid.2x2")
        } description: {
            Text("Habits you create will appear here.")
        } actions: {
            Button {
                showingNewHabit = true
            } label: {
                Label("Create your first habit", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var matrix: some View {
        let today = calendar.startOfDay(for: now)
        let days = dayRange(endingAt: today)
        let snapshots = records.map { record -> (Habit, [Completion]) in
            (record.snapshot, (record.completions ?? []).compactMap(\.snapshot))
        }
        let habits = snapshots.map(\.0)
        let completions = snapshots.flatMap(\.1)
        let rows = OverviewMatrix.compute(
            habits: habits,
            completions: completions,
            days: days,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )
        let metrics = Dictionary(uniqueKeysWithValues: snapshots.map { (habit, comps) in
            let streak = streakCalculator.current(for: habit, completions: comps, asOf: now)
            let score = scoreCalculator.currentScore(for: habit, completions: comps, asOf: now)
            return (habit.id, (streak: streak, scorePercent: Int((score * 100).rounded())))
        })
        // What the popover reads its value from — the same snapshots the
        // cells were drawn from, so the two can't disagree.
        let completionsByHabit = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $1) })

        return ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                scrollingCells(rows: rows, days: days, completionsByHabit: completionsByHabit)
                labelsOverlay(rows: rows, metrics: metrics)
            }
            .padding(.vertical, 8)
        }
        .scrollContentBackground(.hidden)
        .background(Color.kadoBackground.ignoresSafeArea())
        .quickLogFeedback(quickLog)
    }

    /// Binding that reflects whether a specific (habit, date) cell is
    /// the currently selected one. Used to attach `.popover` per-cell
    /// so the popover anchors to the tapped button rather than the
    /// whole matrix. Days compare by calendar day, as the detail
    /// calendar's binding does, not by instant.
    private func selectionBinding(habitID: UUID, date: Date) -> Binding<Bool> {
        Binding(
            get: {
                guard let sel = selection else { return false }
                return sel.habitID == habitID && calendar.isDate(sel.date, inSameDayAs: date)
            },
            set: { newValue in
                if !newValue,
                   let sel = selection,
                   sel.habitID == habitID,
                   calendar.isDate(sel.date, inSameDayAs: date) {
                    selection = nil
                }
            }
        )
    }

    private func scrollingCells(
        rows: [MatrixRow],
        days: [Date],
        completionsByHabit: [UUID: [Completion]]
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Date column headers — scroll horizontally with the cells.
                HStack(spacing: Self.cellSpacing) {
                    ForEach(days, id: \.self) { day in
                        DayColumnHeader(date: day, width: Self.cellSize)
                    }
                }
                .frame(height: Self.headerHeight)

                Color.clear.frame(height: Self.rowGap)

                ForEach(rows, id: \.habit.id) { row in
                    // Transparent spacer where the label + padding overlay.
                    Color.clear.frame(height: Self.labelHeight + Self.labelBottomPadding)
                    cellRow(row, days: days, completions: completionsByHabit[row.habit.id] ?? [])
                    if row.habit.id != rows.last?.habit.id {
                        Color.clear.frame(height: Self.rowGap)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .defaultScrollAnchor(.trailing)
    }

    private func labelsOverlay(
        rows: [MatrixRow],
        metrics: [UUID: (streak: Int, scorePercent: Int)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Match the date-header row + its trailing gap so the first
            // label lands in the first habit's spacer slot.
            Color.clear.frame(height: Self.headerHeight + Self.rowGap)

            ForEach(rows, id: \.habit.id) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.habit.icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(row.habit.color.color)
                    Text(row.habit.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.kadoForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        // On the `Text` rather than the enclosing
                        // `HStack`: an identifier on the row would be
                        // stamped over the `MetricsChip` beside it.
                        .accessibilityIdentifier(
                            AccessibilityID.Overview.habitLabel(row.habit.id)
                        )
                    Spacer(minLength: 8)
                    if let m = metrics[row.habit.id] {
                        MetricsChip(streak: m.streak, scorePercent: m.scorePercent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.labelHeight)

                // Spacer for the breathing room below the name + the
                // cell row itself, so the next label lines up with the
                // next habit's spacer slot.
                Color.clear.frame(height: Self.labelBottomPadding + Self.cellSize)
                if row.habit.id != rows.last?.habit.id {
                    Color.clear.frame(height: Self.rowGap)
                }
            }
        }
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
    }

    private func cellRow(_ row: MatrixRow, days: [Date], completions: [Completion]) -> some View {
        HStack(spacing: Self.cellSpacing) {
            ForEach(Array(zip(days, row.days).enumerated()), id: \.offset) { offset, pair in
                let (day, cell) = pair
                matrixCell(
                    row: row,
                    day: day,
                    cell: cell,
                    daysAgo: days.count - 1 - offset,
                    completions: completions
                )
            }
        }
        .frame(height: Self.cellSize)
    }

    /// Grey cells inside the tracked range open the editor — a day the
    /// schedule didn't ask for can still be logged, as on the detail
    /// calendar. A day before the habit's start does not: logging it
    /// would quietly move the start back and turn the month in between
    /// into misses (issue #104). Back-dating stays on the detail
    /// calendar, which says so before it happens. The window ends
    /// today, so `.future` never reaches this row.
    @ViewBuilder
    private func matrixCell(
        row: MatrixRow,
        day: Date,
        cell: DayCell,
        daysAgo: Int,
        completions: [Completion]
    ) -> some View {
        let label = Self.accessibilityLabel(habit: row.habit, date: day, cell: cell, calendar: calendar)
        let identifier = AccessibilityID.Overview.cell(row.habit.id, daysAgo: daysAgo)
        let visual = MatrixCell(state: cell, color: row.habit.color, size: Self.cellSize)
        if cell.isEditable {
            Button {
                selection = CellSelection(habitID: row.habit.id, date: day)
            } label: {
                visual
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityHint(Text("Double-tap to edit this day."))
            .accessibilityIdentifier(identifier)
            .popover(isPresented: selectionBinding(habitID: row.habit.id, date: day)) {
                dayEditPopover(for: row.habit, on: day, cell: cell, completions: completions)
            }
        } else {
            visual
                .accessibilityElement()
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
    }

    /// The editor for one cell, fed from the render's value snapshots.
    /// Kept out of `cellRow` so the type-checker has one closure fewer
    /// to fit inside the `ForEach`.
    private func dayEditPopover(
        for habit: Habit,
        on day: Date,
        cell: DayCell,
        completions: [Completion]
    ) -> some View {
        let completion = completions.first { calendar.isDate($0.date, inSameDayAs: day) }
        let notScheduled: Bool
        switch cell {
        case .notDue, .offSchedule:
            notScheduled = true
        case .future, .beforeStart, .scored:
            notScheduled = false
        }
        return DayEditPopover(
            habit: habit,
            date: day,
            currentValue: completion?.value ?? 0,
            currentNote: completion?.note,
            onToggle: { toggle(habit, on: day) },
            onSetCounter: { value in setCounter(value, for: habit, on: day) },
            onSetTimerSeconds: { seconds in setTimerSeconds(seconds, for: habit, on: day) },
            onClear: { clear(habit, on: day) },
            onNoteChanged: { note in setNote(note, for: habit, on: day) },
            notScheduled: notScheduled
        )
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Cell popover mutations

    private var dayEditor: DayCompletionEditor { DayCompletionEditor(calendar: calendar) }

    /// The live record behind a cell, resolved against the query that
    /// is mounted now. Called from the mutations only, never from a
    /// render — see the type comment.
    private func record(for habit: Habit) -> HabitRecord? {
        records.first { $0.id == habit.id }
    }

    private func recordQuickLog(_ change: DayCompletionEditor.Change, type: HabitType) {
        guard let event = QuickLogEvent.next(
            after: quickLog, type: type, oldValue: change.before, newValue: change.after
        ) else { return }
        quickLog = event
    }

    private func toggle(_ habit: Habit, on day: Date) {
        guard let record = record(for: habit) else { return }
        let change = dayEditor.toggle(for: record, on: day, in: modelContext)
        recordQuickLog(change, type: habit.type)
    }

    private func setCounter(_ value: Double, for habit: Habit, on day: Date) {
        guard let record = record(for: habit) else { return }
        let change = dayEditor.setCounter(value, for: record, on: day, in: modelContext)
        recordQuickLog(change, type: habit.type)
    }

    private func setTimerSeconds(_ seconds: TimeInterval, for habit: Habit, on day: Date) {
        guard let record = record(for: habit) else { return }
        let change = dayEditor.setTimerSeconds(seconds, for: record, on: day, in: modelContext)
        recordQuickLog(change, type: habit.type)
    }

    private func clear(_ habit: Habit, on day: Date) {
        guard let record = record(for: habit) else { return }
        let change = dayEditor.clear(for: record, on: day, in: modelContext)
        recordQuickLog(change, type: habit.type)
    }

    private func setNote(_ note: String?, for habit: Habit, on day: Date) {
        guard let record = record(for: habit) else { return }
        dayEditor.setNote(note, for: record, on: day, in: modelContext)
    }

    private func dayRange(endingAt today: Date) -> [Date] {
        (0..<Self.dayWindow).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    /// Composes a per-cell VoiceOver label:
    /// `"{habit}, {localized date}, {state}"`.
    private static func accessibilityLabel(
        habit: Habit,
        date: Date,
        cell: DayCell,
        calendar: Calendar
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateStyle = .full
        let dateString = formatter.string(from: date)

        let state: String
        switch cell {
        case .future:
            state = String(localized: "upcoming")
        case .notDue:
            state = String(localized: "not scheduled")
        case .beforeStart:
            state = String(localized: "before tracking started")
        case .scored(let s):
            state = completionPhrase(for: s)
        case .offSchedule(let s):
            // The hollow cell is a purely visual distinction, so
            // VoiceOver has to say it out loud.
            state = String(
                localized: "\(completionPhrase(for: s)), off schedule",
                comment: "Overview cell state for a day logged outside the habit's schedule. Argument: the completion phrase, e.g. 'completed'."
            )
        }
        return "\(habit.name), \(dateString), \(state)"
    }

    /// Shared wording for a day's value, used on its own for
    /// scheduled days and embedded in the off-schedule phrasing.
    private static func completionPhrase(for value: Double) -> String {
        if value >= 1.0 {
            return String(localized: "completed")
        } else if value <= 0.0 {
            return String(localized: "missed")
        } else {
            let percent = Int((value * 100).rounded())
            return String(localized: "\(percent)% complete")
        }
    }
}

#Preview("Populated") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
}

#Preview("Empty") {
    OverviewView()
        .modelContainer(PreviewContainer.emptyContainer())
}

#Preview("Dark") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    OverviewView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.dynamicTypeSize, .accessibility3)
}
