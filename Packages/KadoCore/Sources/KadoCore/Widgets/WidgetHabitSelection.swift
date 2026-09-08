import Foundation

/// How many habits each home widget family has room for.
///
/// One place rather than a `private let limit` per view, because each
/// number is written down three times over: here, in that widget's
/// gallery description, and — as a bare literal — in
/// `SelectHabitsIntent`'s `size:` dictionary, which caps the picker
/// itself. AppIntents forces the third one: its
/// `IntentCollectionSize.init(min:max:)` takes `_const Int` and
/// rejects even a `static let`, so the value cannot be shared from
/// here. `SelectHabitsIntentTests` reads the generated metadata back
/// and fails if the picker and these limits disagree.
public enum WidgetHabitLimit {
    public static let small = 5
    public static let medium = 8
    public static let large = 5
}

/// Resolves a widget's configured habit pick against the App Group
/// snapshot.
///
/// A pick is a list of `UUID`s, and it outlives the habits in it: the
/// user chooses once in the widget-edit sheet and the ids are stored
/// with the placed widget, while the habits behind them go on being
/// renamed, archived and deleted. Everything here is about that gap.
public enum WidgetHabitSelection {

    /// The today rows a widget should draw. Habits not due today are
    /// absent from `snapshot.today` and so drop out on their own —
    /// deliberate, since the small and medium tiles exist to complete
    /// what's due and a row you can't act on would be noise.
    public static func todayRows(
        from snapshot: WidgetSnapshot,
        selecting ids: [UUID],
        limit: Int
    ) -> [WidgetTodayRow] {
        pick(snapshot.today, ids: ids, limit: limit, id: \.habit.id)
    }

    /// The weekly-matrix rows a widget should draw. Unlike the today
    /// rows these cover every active habit, so a pick here is only
    /// ever narrowed by a habit having been archived or deleted.
    public static func matrixRows(
        from snapshot: WidgetSnapshot,
        selecting ids: [UUID],
        limit: Int
    ) -> [WidgetMatrixRow] {
        pick(snapshot.matrix, ids: ids, limit: limit, id: \.habit.id)
    }

    /// The "N / M done" summary the medium widget prints beside its
    /// title.
    ///
    /// With no pick this is the whole day, unchanged — a widget
    /// showing the first eight of twelve due habits still reports
    /// progress against all twelve, which is the number the user
    /// actually wants. With a pick it counts only what the tile
    /// shows, because "2 / 9 done" over three visible rows is a
    /// summary of something the user can't see.
    public static func progress(
        from snapshot: WidgetSnapshot,
        selecting ids: [UUID],
        limit: Int
    ) -> (completed: Int, total: Int) {
        guard !ids.isEmpty else {
            return (snapshot.completedToday, snapshot.totalDueToday)
        }
        let rows = todayRows(from: snapshot, selecting: ids, limit: limit)
        return (rows.filter { $0.status == .complete }.count, rows.count)
    }

    /// - Parameters:
    ///   - rows: the snapshot's rows, in the app's own order.
    ///   - ids: the user's pick, in the order they picked. Empty means
    ///     "no pick yet", which shows everything — the state a freshly
    ///     added widget is in, and the state an already-placed widget
    ///     inherits when a build swaps `StaticConfiguration` for
    ///     `AppIntentConfiguration` under it.
    ///   - limit: the family's capacity.
    ///
    /// A non-empty pick that matches nothing renders **empty**, not
    /// everything. The two cases look alike in the data and are
    /// opposites to the user: "I haven't chosen" versus "I chose, and
    /// none of them can be shown". Falling back to everything in the
    /// second case would fill the tile with the habits they excluded.
    private static func pick<Row>(
        _ rows: [Row],
        ids: [UUID],
        limit: Int,
        id: (Row) -> UUID
    ) -> [Row] {
        guard limit > 0 else { return [] }
        guard !ids.isEmpty else { return Array(rows.prefix(limit)) }

        let byID = Dictionary(rows.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
        var seen = Set<UUID>()
        var picked: [Row] = []
        picked.reserveCapacity(min(ids.count, limit))
        for identifier in ids {
            // `seen` gates on the id rather than on the lookup, so a
            // repeated id costs nothing even when it resolves.
            guard seen.insert(identifier).inserted else { continue }
            guard let row = byID[identifier] else { continue }
            picked.append(row)
            if picked.count == limit { break }
        }
        return picked
    }
}
