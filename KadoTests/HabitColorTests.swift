import Testing
@testable import Kado
import KadoCore

@Suite("HabitColor palette")
struct HabitColorTests {
    @Test("Palette exposes eight distinct cases")
    func paletteSize() {
        #expect(HabitColor.allCases.count == 8)
        #expect(Set(HabitColor.allCases).count == 8)
    }

    @Test("Raw values match case names (stable for migration)")
    func rawValuesStable() {
        let expected: [(HabitColor, String)] = [
            (.red, "red"),
            (.orange, "orange"),
            (.yellow, "yellow"),
            (.green, "green"),
            (.mint, "mint"),
            (.teal, "teal"),
            (.blue, "blue"),
            (.purple, "purple"),
        ]
        for (value, raw) in expected {
            #expect(value.rawValue == raw)
        }
    }

    // MARK: - Palette shape

    @Test("Every habit sits at the same lightness")
    func matchedLightness() {
        // This is the whole reason the palette is declared in OKLCH
        // rather than mapped onto system colors. System yellow is far
        // lighter than system purple, so a card of habit marks drawn
        // from them reads as a set of unrelated intensities.
        for color in HabitColor.allCases {
            #expect(color.oklch.lightness == HabitColor.baseLightness)
        }
    }

    @Test("Chroma stays inside the muted band")
    func mutedChroma() {
        // Full-chroma hues are what made the old screens loud against
        // the warm cream ground.
        for color in HabitColor.allCases {
            #expect(color.oklch.chroma >= 0.09)
            #expect(color.oklch.chroma <= 0.15)
        }
    }

    @Test("Hues are distinct and spread around the wheel")
    func distinctHues() {
        let hues = HabitColor.allCases.map(\.oklch.hue)
        #expect(Set(hues).count == hues.count)
        // Adjacent palette entries must be far enough apart to be told
        // apart in a 13pt legend swatch.
        for (lower, higher) in zip(hues.sorted(), hues.sorted().dropFirst()) {
            #expect(higher - lower >= 15)
        }
    }

    @Test("Ink is darker than the base hue in light mode")
    func inkIsDarkerInLight() {
        // Text and icons sit on a 14–20% tint of the base, which barely
        // shifts the cream ground — so a mid-lightness hue on it would
        // land well under 4.5:1.
        #expect(HabitColor.inkLightness < HabitColor.baseLightness)
    }

    @Test("Dark mode lifts both the hue and its ink")
    func darkModeLifts() {
        // Marks and tiles sit on a near-black ground in dark mode, and
        // the tint they carry is dark, so both have to move up.
        #expect(HabitColor.darkLightness > HabitColor.baseLightness)
        #expect(HabitColor.darkInkLightness > HabitColor.darkLightness)
    }

    @Test("Every hue resolves to a real in-gamut color")
    func resolvesInGamut() {
        for color in HabitColor.allCases {
            let (red, green, blue) = color.oklch.sRGB
            for channel in [red, green, blue] {
                #expect(channel >= 0)
                #expect(channel <= 1)
            }
            // Not grey: a habit hue that clamped to the achromatic axis
            // would make two habits indistinguishable.
            #expect(max(red, green, blue) - min(red, green, blue) > 0.05)
        }
    }
}
