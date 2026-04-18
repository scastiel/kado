import Foundation
import WidgetKit
import KadoCore

/// Thin wrapper around `WidgetCenter` so mutation sites don't
/// each have to import WidgetKit directly and so tests can see
/// the intent of the call from the call site.
///
/// Widgets also refresh hourly by their own timeline policy;
/// this just compresses the worst-case staleness from an hour
/// to a second or two when the user acts in-app.
@MainActor
enum WidgetReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
