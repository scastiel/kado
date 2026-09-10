import Foundation
import Observation

/// Process-scoped announcer for "the day just became complete".
///
/// Every mutation path — Today rows, Detail, the log sheets, backup
/// import, notification actions, the App Intents — ends in
/// `WidgetSnapshotBuilder.rebuildAndWrite`, and that is where
/// `observe(_:on:)` is called. The moment `DayCompletionTracker` says
/// the edge was crossed, `celebrationCount` moves, and whichever view
/// is watching it (the confetti overlay on `ContentView`) plays.
///
/// A singleton for the same reason `ActiveContainer` is one: the
/// intents run inside the app process but outside the SwiftUI
/// environment, and still need to reach the same instance the views
/// observe.
@MainActor
@Observable
public final class DayCompletionCelebration {
    public static let shared = DayCompletionCelebration()

    /// Bumps once per celebration. Observers key their animation run
    /// on the value rather than on a boolean, so two edges in quick
    /// succession restart the effect instead of being coalesced.
    public private(set) var celebrationCount = 0

    private var tracker = DayCompletionTracker()

    public init() {}

    /// Reports the progress just written to the widget snapshot, for
    /// the logical day it was built for.
    public func observe(_ progress: DayProgress, on day: Date) {
        if tracker.record(progress, on: day) {
            celebrationCount += 1
        }
    }

    /// Forgets the previous observation. Call before swapping the
    /// underlying store, so the first report from the new one is a
    /// baseline rather than a comparison across datasets.
    public func reset() {
        tracker.reset()
    }
}
