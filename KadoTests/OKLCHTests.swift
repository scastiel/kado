import Testing
import Foundation
@testable import Kado
import KadoCore

/// The habit palette is generated from these conversions rather than
/// pasted as hex, so a wrong matrix would retint the whole app quietly.
@Suite("OKLCH")
struct OKLCHTests {

    private func expectRGB(
        _ color: OKLCH,
        _ expected: (Double, Double, Double),
        tolerance: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = color.sRGB
        #expect(abs(actual.red - expected.0) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.green - expected.1) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(actual.blue - expected.2) < tolerance, sourceLocation: sourceLocation)
    }

    @Test("Achromatic lightness maps to grey")
    func greyAxis() {
        // Chroma 0 must produce equal channels at every lightness and
        // every hue angle — the cheapest check that the matrices are
        // transcribed the right way round.
        for lightness in [0.0, 0.25, 0.5, 0.75, 1.0] {
            for hue in [0.0, 90.0, 210.0, 330.0] {
                let (red, green, blue) = OKLCH(lightness, 0, hue).sRGB
                #expect(abs(red - green) < 0.001)
                #expect(abs(green - blue) < 0.001)
            }
        }
    }

    @Test("Black and white land on the ends of the range")
    func endpoints() {
        expectRGB(OKLCH(0, 0, 0), (0, 0, 0))
        expectRGB(OKLCH(1, 0, 0), (1, 1, 1))
    }

    @Test("Known conversions match Ottosson's reference values")
    func knownValues() {
        // sRGB white, mid grey and pure red, expressed in OKLCH and
        // converted back. Values from the OKLab reference conversions.
        expectRGB(OKLCH(0.6279, 0.2577, 29.23), (1, 0, 0))
        expectRGB(OKLCH(0.8664, 0.2948, 142.5), (0, 1, 0))
        expectRGB(OKLCH(0.4520, 0.3132, 264.05), (0, 0, 1))
    }

    @Test("Out-of-gamut requests clamp instead of wrapping")
    func clamping() {
        // A chroma far beyond what sRGB can express must not produce a
        // negative or >1 channel that would wrap to a wildly wrong hue.
        let (red, green, blue) = OKLCH(0.5, 0.9, 200).sRGB
        for channel in [red, green, blue] {
            #expect(channel >= 0)
            #expect(channel <= 1)
        }
    }

    @Test("Raising lightness keeps hue and chroma, and brightens")
    func lightnessDerivation() {
        let base = OKLCH(0.58, 0.12, 250)
        let lifted = base.lightness(0.72)

        #expect(lifted.chroma == base.chroma)
        #expect(lifted.hue == base.hue)

        // Every channel of the lifted color is at least as bright —
        // the property the dark-mode palette depends on.
        let dark = base.sRGB
        let light = lifted.sRGB
        #expect(light.red > dark.red)
        #expect(light.green > dark.green)
        #expect(light.blue > dark.blue)
    }
}
