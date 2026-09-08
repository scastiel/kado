import SwiftUI
import Testing
import UIKit
import WidgetKit
@testable import Kado
import KadoCore

/// Guards the invariant the Home Screen's Tinted / Clear appearance
/// broke: under `.accented` WidgetKit re-tints every opaque pixel
/// with one colour and keeps only alpha, so any two opaque colours we
/// picked render identically.
///
/// Every assertion here is therefore about **alpha**, never about
/// `Color` identity — two different `Color` values are not evidence of
/// anything once hue has been discarded.
@Suite("WidgetPalette")
struct WidgetPaletteTests {

    private let tinted: [WidgetRenderingMode] = [.accented, .vibrant]
    private let everyStatus: [WidgetStatus] = [.none, .partial, .complete]

    // MARK: - Full colour is untouched

    @Test("Full colour reproduces the paper / ink palette")
    func fullColourIsUnchanged() {
        let palette = WidgetPalette(renderingMode: .fullColor)
        #expect(palette.isTinted == false)
        #expect(palette.foreground == .kadoForeground)
        #expect(palette.foregroundSecondary == .kadoForegroundSecondary)
        #expect(palette.restingFill == .kadoHairline)
        #expect(palette.notDueFill == .kadoHairline)
    }

    /// The `.partial` curve is the one arm that was physically moved
    /// out of `HabitWidgetCell.background`, so it is the one most
    /// exposed to a transcription slip.
    @Test("Full colour keeps the habit hue and the 0.3 + 0.4p partial ramp")
    func fullColourHabitFills() {
        let palette = WidgetPalette(renderingMode: .fullColor)
        for color in HabitColor.allCases {
            #expect(palette.habitFill(color, status: .complete, progress: 1) == color.color)
            #expect(palette.habitFill(color, status: .none, progress: 0) == .kadoHairline)
            for (progress, expected) in [(0.0, 0.3), (0.5, 0.5), (1.0, 0.7)] {
                #expect(
                    palette.habitFill(color, status: .partial, progress: progress)
                        == color.color.opacity(expected)
                )
            }
        }
    }

    @Test("Full colour knocks the label out to white only once complete")
    func fullColourGlyphAndLabel() {
        let palette = WidgetPalette(renderingMode: .fullColor)
        for color in HabitColor.allCases {
            #expect(palette.glyphColor(color, status: .complete) == .white)
            #expect(palette.labelColor(color, status: .complete) == .white)
            for status in [WidgetStatus.none, .partial] {
                #expect(palette.glyphColor(color, status: status) == color.color)
                #expect(palette.labelColor(color, status: status) == .kadoForeground)
            }
        }
    }

    // MARK: - Tinted hierarchy is carried by alpha

    /// The shipped bug, stated as a bound: a label drawn at the same
    /// strength as the fill under it is invisible once the tint
    /// removes the hue between them.
    @Test("Tinted labels clear their own fill by a wide alpha margin")
    func labelClearsItsFill() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            #expect(palette.isTinted)
            for color in HabitColor.allCases {
                for status in everyStatus {
                    for progress in [0.0, 0.5, 1.0] {
                        let fill = opacity(of: palette.habitFill(color, status: status, progress: progress))
                        let label = opacity(of: palette.labelColor(color, status: status))
                        let glyph = opacity(of: palette.glyphColor(color, status: status))
                        #expect(
                            label - fill >= 0.5,
                            "\(mode)/\(color)/\(status)@\(progress): label \(label) vs fill \(fill)"
                        )
                        #expect(glyph - fill >= 0.5)
                    }
                }
            }
        }
    }

    @Test("Tinted fills stay translucent so the tint can't flatten them")
    func tintedFillsKeepAlpha() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            for status in everyStatus {
                for progress in [0.0, 0.5, 1.0] {
                    let fill = palette.habitFill(.green, status: status, progress: progress)
                    #expect(opacity(of: fill) < 0.75, "\(mode)/\(status)/\(progress) fill is too solid")
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

    /// `.notDue` and a scheduled-but-unscored day are told apart by
    /// hue in full colour and by alpha alone under the tint. The
    /// scored ramp floors at 0.2, so the not-due wash has to clear it
    /// downwards — pulled from `WidgetDayCell` rather than retyped, so
    /// that moving the ramp fails this test.
    @Test("Not-due sits clear of the scored ramp's floor under the tint")
    func notDueClearsTheScoredFloor() throws {
        let scoredFloor = try #require(WidgetDayCell.scored(0).colorOpacity)
        #expect(scoredFloor == 0.2)
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            let notDue = opacity(of: palette.notDueFill)
            #expect(notDue < scoredFloor - 0.05, "\(mode): not-due \(notDue) vs scored floor \(scoredFloor)")
        }
    }

    /// Secondary text is already dimmed once by landing in the
    /// non-accented group; a heavy alpha on top of that dims it twice
    /// and buries it.
    @Test("Secondary text ranks below primary without being buried")
    func secondaryTextIsRankedNotBuried() {
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            let primary = opacity(of: palette.foreground)
            let secondary = opacity(of: palette.foregroundSecondary)
            #expect(secondary < primary)
            #expect(secondary >= 0.7, "\(mode): secondary \(secondary) dims twice over")
        }
    }

    /// The streak flame is the one place the widgets reach for a hue
    /// that is neither the habit's nor the palette's. It survives in
    /// full colour; under the tint it has to stop being a second
    /// colour, because it isn't one — every opaque pixel arrives the
    /// same shade, and an orange that is silently `.primary` would
    /// read a whole step louder than the percentage beside it.
    @Test("The streak flame keeps its orange in full colour and folds into secondary under the tint")
    func streakAccentFoldsIntoSecondary() {
        #expect(WidgetPalette(renderingMode: .fullColor).streakAccent == .orange)
        for mode in tinted {
            let palette = WidgetPalette(renderingMode: mode)
            #expect(palette.streakAccent == palette.foregroundSecondary)
            #expect(opacity(of: palette.streakAccent) < opacity(of: palette.foreground))
            #expect(opacity(of: palette.streakAccent) >= 0.7, "\(mode): the flame dims twice over")
        }
    }

    /// Out-of-range progress reaches the palette straight from the
    /// App Group JSON, so clamp rather than trust it.
    @Test("Progress outside 0...1 stays inside the fill's alpha band")
    func progressIsClamped() {
        for mode in [WidgetRenderingMode.fullColor, .accented] {
            let palette = WidgetPalette(renderingMode: mode)
            let low = palette.habitFill(.green, status: .partial, progress: -3)
            let high = palette.habitFill(.green, status: .partial, progress: 12)
            #expect(low == palette.habitFill(.green, status: .partial, progress: 0))
            #expect(high == palette.habitFill(.green, status: .partial, progress: 1))
        }
    }

    /// `.primary` bridges to a dynamic `UIColor`, which only yields
    /// components once it is resolved against a trait collection.
    private func opacity(of color: Color) -> Double {
        let resolved = UIColor(color)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        return Double(resolved.cgColor.alpha)
    }
}
