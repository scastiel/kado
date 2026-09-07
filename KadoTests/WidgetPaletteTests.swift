import SwiftUI
import Testing
import UIKit
import WidgetKit
@testable import Kado
import KadoCore

/// Guards the invariant the Home Screen's Tinted / Clear appearance
/// broke: under `.accented` WidgetKit re-tints every opaque pixel
/// with one colour and keeps only alpha, so any two opaque colours
/// we picked render identically. Text sitting on a fill must
/// therefore always differ from that fill.
@Suite("WidgetPalette")
struct WidgetPaletteTests {

    private let tinted: [WidgetRenderingMode] = [.accented, .vibrant]
    private let everyStatus: [WidgetStatus] = [.none, .partial, .complete]

    @Test("Full colour reproduces the paper / ink palette")
    func fullColourIsUnchanged() {
        let palette = WidgetPalette(renderingMode: .fullColor)
        #expect(palette.isTinted == false)
        #expect(palette.foreground == .kadoForeground)
        #expect(palette.foregroundSecondary == .kadoForegroundSecondary)
        #expect(palette.restingFill == .kadoHairline)
        #expect(palette.habitFill(.blue, status: .complete, progress: 1) == HabitColor.blue.color)
        #expect(palette.habitFill(.blue, status: .none, progress: 0) == .kadoHairline)
        #expect(palette.onHabitFill(.blue, status: .complete) == .white)
        #expect(palette.onHabitFill(.blue, status: .none) == HabitColor.blue.color)
    }

    @Test("Tinted modes never draw a label in its own fill's colour")
    func labelNeverMatchesItsFill() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            #expect(palette.isTinted)
            for color in HabitColor.allCases {
                for status in everyStatus {
                    let fill = palette.habitFill(color, status: status, progress: 0.5)
                    let label = palette.onHabitFill(color, status: status)
                    #expect(fill != label, "\(mode) / \(color) / \(status) flattens label into fill")
                }
            }
            #expect(palette.restingFill != palette.foreground)
            #expect(palette.foreground != palette.foregroundSecondary)
        }
    }

    @Test("Tinted fills stay translucent so the tint can't flatten them")
    func tintedFillsKeepAlpha() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            for status in everyStatus {
                for progress in [0.0, 0.5, 1.0] {
                    let fill = palette.habitFill(.green, status: status, progress: progress)
                    #expect(opacity(of: fill) < 0.75, "\(mode) / \(status) / \(progress) fill is too solid")
                }
            }
            #expect(opacity(of: palette.restingFill) < 0.75)
        }
    }

    @Test("Tinted fills stay ordered: complete reads stronger than untouched")
    func tintedFillsAreOrdered() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            let untouched = opacity(of: palette.habitFill(.green, status: .none, progress: 0))
            let half = opacity(of: palette.habitFill(.green, status: .partial, progress: 0.5))
            let done = opacity(of: palette.habitFill(.green, status: .complete, progress: 1))
            #expect(untouched < half)
            #expect(half < done)
        }
    }

    /// Out-of-range progress reaches the palette straight from the
    /// snapshot, so clamp rather than trust it.
    @Test("Progress outside 0...1 stays inside the fill's alpha band")
    func progressIsClamped() {
        let palette = WidgetPalette(renderingMode: .accented)
        let low = opacity(of: palette.habitFill(.green, status: .partial, progress: -3))
        let high = opacity(of: palette.habitFill(.green, status: .partial, progress: 12))
        #expect(low == opacity(of: palette.habitFill(.green, status: .partial, progress: 0)))
        #expect(high == opacity(of: palette.habitFill(.green, status: .partial, progress: 1)))
    }

    /// `.primary` bridges to a dynamic `UIColor`, which only yields
    /// components once it is resolved against a trait collection.
    private func opacity(of color: Color) -> Double {
        let resolved = UIColor(color)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        return Double(resolved.cgColor.alpha)
    }
}
