import SwiftUI
import UIKit
import os
import KadoCore

/// `UIColor(_ color: Color)` for tests that run on many threads at once.
///
/// SwiftUI caches that bridge in an `NSMapTable` with no lock of its
/// own, and Swift Testing runs each argument of a parameterised test in
/// parallel. Two threads growing the table together crash the test host
/// with `EXC_BAD_ACCESS` in `-[NSConcreteMapTable rehash]`, and the
/// crash is reported against whichever unrelated test happened to be
/// running. It stayed hidden with two habit themes and surfaced with
/// six (#113). The palette itself bridges once, building its tables on
/// first use, so ``warmUp()`` builds them under the same lock before
/// any test reads a colour.
enum ResolvedColor {
    private static let lock = OSAllocatedUnfairLock()

    /// `color` as a `UIColor`, bridged under the shared lock.
    static func uiColor(_ color: Color) -> UIColor {
        lock.withLock { UIColor(color) }
    }

    /// `color` resolved in one appearance.
    static func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> UIColor {
        uiColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    /// Forces `HabitColor`'s palette tables to build under the lock.
    /// Call from the `init` of every suite that reads habit colours.
    static func warmUp() {
        lock.withLock { _ = HabitColor.red.color(in: .kado) }
    }
}
