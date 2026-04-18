import Foundation
import KadoCore

/// Process-wide handle on the current notification scheduler, mirrored
/// on `ActiveContainer.shared` for the same reason: static call sites
/// (view actions, NotificationManager delegate path) need to reach the
/// scheduler without plumbing it through every call.
///
/// `KadoApp` sets this once at launch. Dev-mode swaps don't need to
/// replace the scheduler (its state is in `UNUserNotificationCenter`,
/// not in the container), so we leave the instance alone.
@MainActor
final class ActiveScheduler {
    static let shared = ActiveScheduler()

    private(set) var scheduler: (any NotificationScheduling)?

    func set(_ scheduler: any NotificationScheduling) {
        self.scheduler = scheduler
    }

    func get() -> (any NotificationScheduling)? {
        scheduler
    }
}
