import SwiftData
import SwiftUI
import KadoCore

/// Overview tab: habits × days, one hue per row at four intensities.
///
/// The point of the screen is comparison — which habits are holding up
/// and which are slipping — so every row is drawn on the same grid and
/// the tiles carry only intensity. The shipping build alternated light
/// and full-saturation tiles with no key, which encoded nothing the eye
/// could read back, and sized its date header separately from its tiles
/// so the two drifted out of alignment.
///
/// Layout:
/// - Ten columns fill the width. `columnWidth` is derived once from the
///   viewport and used by the header *and* the tiles, in the same
///   container with the same spacing, so alignment is structural rather
///   than maintained by hand.
/// - A single horizontal `ScrollView` holds the header and every tile
///   row, so they can only ever scroll together. Habit labels sit in a
///   sibling overlay pinned to the page margin, positioned over clear
///   spacers left for them in the scrolling stack.
/// - The outer vertical `ScrollView` carries the title, the summary,
///   and the legend.
struct OverviewView: View {
    @Query(
        filter: #Predicate<HabitRecord> { $0.archivedAt == nil },
        sort: \HabitRecord.sortOrder
    )
    private var records: [HabitRecord]

    @Environment(\.calendar) private var calendar
    @Environment(\.today) private var now
    @Environment(\.frequencyEvaluator) private var frequencyEvaluator
    @Environment(\.habitScoreCalculator) private var scoreCalculator

    @State private var selection: CellSelection?
    @State private var showingNewHabit = false

    /// Days of history kept in the grid. Ten of them are on screen; the
    /// rest are a horizontal drag away.
    private static let dayWindow = 30
    /// Columns visible at once. Also the window the summary line
    /// reports on, so the sentence describes what the user can see.
    private static let visibleColumns = 10
    private static let columnSpacing: CGFloat = 5
    private static let pageMargin: CGFloat = 20
    private static let labelHeight: CGFloat = 22
    private static let labelBottomPadding: CGFloat = 7
    private static let rowGap: CGFloat = 16
    private static let headerHeight: CGFloat = 30
    private static let headerBottomPadding: CGFloat = 10

    struct CellSelection: Identifiable, Equatable {
        let habit: Habit
        let date: Date
        let cell: DayCell

        var id: String { "\(habit.id)-\(date.timeIntervalSince1970)" }
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kadoBackground.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
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
        GeometryReader { proxy in
            let columnWidth = Self.columnWidth(in: proxy.size.width)
            let today = calendar.startOfDay(for: now)
            let days = dayRange(endingAt: today)
            let rows = orderedRows(days: days, today: today)
            let summary = OverviewMatrix.summary(for: rows, lastDays: Self.visibleColumns)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock(summary: summary)
                        .padding(.horizontal, Self.pageMargin)

                    ZStack(alignment: .topLeading) {
                        scrollingGrid(rows: rows, days: days, columnWidth: columnWidth)
                        labelsOverlay(rows: rows, columnWidth: columnWidth)
                    }

                    OverviewLegend()
                        .padding(.horizontal, Self.pageMargin)
                }
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
        }
    }

    /// Ten columns and their nine gaps, inside the page margins.
    static func columnWidth(in totalWidth: CGFloat) -> CGFloat {
        let available = totalWidth
            - pageMargin * 2
            - columnSpacing * CGFloat(visibleColumns - 1)
        return max(available / CGFloat(visibleColumns), 1)
    }

    private func titleBlock(summary: OverviewSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Overview")
                .kadoDisplay(size: 40, weight: .medium)
                .accessibilityAddTraits(.isHeader)
            Text(
                "Last \(Self.visibleColumns) days · \(summary.loggedDays) of \(summary.scheduledDays) scheduled days logged"
            )
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Color.kadoForegroundSecondary)
        }
    }

    // MARK: - Grid

    private func scrollingGrid(
        rows: [MatrixRow],
        days: [Date],
        columnWidth: CGFloat
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Self.columnSpacing) {
                    ForEach(days, id: \.self) { day in
                        DayColumnHeader(date: day, width: columnWidth)
                    }
                }
                .frame(height: Self.headerHeight)
                Color.clear.frame(height: Self.headerBottomPadding)

                ForEach(rows, id: \.habit.id) { row in
                    // Transparent slot the label overlay sits in.
                    Color.clear.frame(height: Self.labelHeight + Self.labelBottomPadding)
                    tileRow(row, days: days, columnWidth: columnWidth)
                    if row.habit.id != rows.last?.habit.id {
                        Color.clear.frame(height: Self.rowGap)
                    }
                }
            }
        }
        // Padding the scroll view *itself*, not its content, is what
        // fixes the shipping build's clipped left edge. An inset
        // applied inside the scroll view (or via `safeAreaPadding`)
        // leaves the viewport full-width, so content keeps drawing to
        // the screen edge and a half-column bleeds past the margin.
        // Padding the view narrows the viewport to exactly ten columns
        // and nine gaps — so the grid lands on whole columns at rest
        // and any partial column during a drag clips at the margin.
        .padding(.horizontal, Self.pageMargin)
        .defaultScrollAnchor(.trailing)
    }

    private func tileRow(_ row: MatrixRow, days: [Date], columnWidth: CGFloat) -> some View {
        HStack(spacing: Self.columnSpacing) {
            ForEach(Array(zip(days, row.days).enumerated()), id: \.offset) { _, pair in
                let (day, cell) = pair
                Button {
                    selection = CellSelection(habit: row.habit, date: day, cell: cell)
                } label: {
                    MatrixCell(state: cell, color: row.habit.color, size: columnWidth)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Self.accessibilityLabel(
                        habit: row.habit,
                        date: day,
                        cell: cell,
                        calendar: calendar
                    )
                )
                .popover(isPresented: selectionBinding(habit: row.habit, date: day)) {
                    CellPopoverContent(habit: row.habit, date: day, cell: cell)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .frame(height: columnWidth)
    }

    /// Habit names and strengths, pinned to the page while the grid
    /// scrolls under them. Hit testing is off so drags and cell taps
    /// pass straight through to the layer below.
    private func labelsOverlay(rows: [MatrixRow], columnWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: Self.headerHeight + Self.headerBottomPadding)

            ForEach(rows, id: \.habit.id) { row in
                labelRow(row)
                    .frame(height: Self.labelHeight)
                Color.clear.frame(height: Self.labelBottomPadding)
                // The tile row this label belongs to. Tiles are square,
                // so its height is the column width.
                Color.clear.frame(height: columnWidth)
                if row.habit.id != rows.last?.habit.id {
                    Color.clear.frame(height: Self.rowGap)
                }
            }
        }
        .padding(.horizontal, Self.pageMargin)
        .allowsHitTesting(false)
    }

    private func labelRow(_ row: MatrixRow) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(row.habit.color.color)
                .frame(width: 9, height: 9)
            Text(row.habit.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kadoForeground)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(TodayRowMeta.percent(strengthPercent(for: row.habit)))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(Color.kadoForegroundSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    /// Matrix rows in **Today's** display order: the habits the
    /// schedule asks for today first, then the rest, each group in
    /// `sortOrder`. `OverviewMatrix` sorts purely by `sortOrder`, which
    /// is why the two screens listed the same habits in different
    /// orders in the shipping build.
    private func orderedRows(days: [Date], today: Date) -> [MatrixRow] {
        let snapshots = records.map { record -> (Habit, [Completion]) in
            (record.snapshot, (record.completions ?? []).compactMap(\.snapshot))
        }
        let rows = OverviewMatrix.compute(
            habits: snapshots.map(\.0),
            completions: snapshots.flatMap(\.1),
            days: days,
            today: today,
            calendar: calendar,
            frequencyEvaluator: frequencyEvaluator
        )

        let (due, other) = TodayRow.sections(
            from: records,
            on: now,
            evaluator: frequencyEvaluator,
            calendar: calendar
        )
        let position = Dictionary(
            uniqueKeysWithValues: (due + other).enumerated().map { ($0.element.id, $0.offset) }
        )
        return rows.sorted {
            (position[$0.habit.id] ?? .max) < (position[$1.habit.id] ?? .max)
        }
    }

    private func strengthPercent(for habit: Habit) -> Int {
        guard let record = records.first(where: { $0.id == habit.id }) else { return 0 }
        let completions = (record.completions ?? []).compactMap(\.snapshot)
        let score = scoreCalculator.currentScore(for: habit, completions: completions, asOf: now)
        return Int((score * 100).rounded())
    }

    private func dayRange(endingAt today: Date) -> [Date] {
        (0..<Self.dayWindow).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    /// Binding that reflects whether a specific (habit, date) cell is
    /// the currently selected one. Used to attach `.popover` per-cell
    /// so the popover anchors to the tapped button rather than the
    /// whole matrix.
    private func selectionBinding(habit: Habit, date: Date) -> Binding<Bool> {
        Binding(
            get: {
                guard let sel = selection else { return false }
                return sel.habit.id == habit.id && sel.date == date
            },
            set: { newValue in
                if !newValue,
                   let sel = selection,
                   sel.habit.id == habit.id,
                   sel.date == date {
                    selection = nil
                }
            }
        )
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
