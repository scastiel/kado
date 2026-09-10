import SwiftUI
import KadoCore

/// A short burst of confetti, drawn on a `Canvas`.
///
/// Every particle's position, spin and fade are closed-form functions
/// of the time elapsed since `startedAt`, so the view holds no
/// simulation state: `TimelineView` asks for a frame, the canvas
/// evaluates each particle at that instant and draws it. The particle
/// set itself comes from a seeded generator, so previews and repeated
/// runs look the same.
///
/// Purely decorative: it lets touches through and is hidden from
/// VoiceOver. The caller decides *when* to show it — and whether to,
/// under Reduce Motion.
struct ConfettiView: View {
    /// How long a burst lasts, fade included. The host removes the
    /// view after this.
    static let duration: TimeInterval = 3.2

    let startedAt: Date

    private let particles: [Particle]

    init(startedAt: Date, count: Int = 140, seed: UInt64 = 0x5EED_CAFE) {
        self.startedAt = startedAt
        var generator = SeededGenerator(seed: seed)
        particles = (0..<count).map { _ in Particle(using: &generator) }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                guard elapsed >= 0, elapsed <= Self.duration else { return }
                for particle in particles {
                    particle.draw(in: context, size: size, at: elapsed)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Particle

    /// One piece of confetti. Positions are normalised — `x` in widths,
    /// `y` in heights — and scaled to the canvas at draw time, so the
    /// same burst fills an iPhone and an iPad.
    private struct Particle {
        /// The eight habit hues and the brand sage: a fistful of the
        /// colours the user already lives with, not a new palette.
        static let palette: [Color] = HabitColor.allCases.map(\.color) + [.kadoSage]

        enum Shape {
            case rectangle(width: CGFloat, height: CGFloat)
            case circle(radius: CGFloat)
        }

        let color: Color
        let shape: Shape
        /// Starting point: spread across the width, just above the top
        /// edge so the first frame shows nothing popping into existence.
        let x0: Double
        let y0: Double
        /// Drift, in widths per second, and initial fall, in heights per
        /// second. Some pieces start with a slight lift — the "pop".
        let vx: Double
        let vy: Double
        /// Side-to-side flutter: amplitude in widths, frequency in Hz.
        let sway: Double
        let swayFrequency: Double
        let swayPhase: Double
        /// In-plane spin and a fake out-of-plane tumble (the x scale
        /// runs through a cosine so a rectangle appears to flip).
        let angle0: Double
        let spin: Double
        let flip: Double
        let flipPhase: Double

        /// Heights per second squared. Real confetti falls slowly.
        static let gravity: Double = 0.18
        /// The fraction of `duration` after which pieces start to fade.
        static let fadeStart: Double = 0.7

        init(using generator: inout SeededGenerator) {
            func random(_ range: ClosedRange<Double>) -> Double {
                Double.random(in: range, using: &generator)
            }
            color = Self.palette[Int.random(in: 0..<Self.palette.count, using: &generator)]
            if random(0...1) < 0.25 {
                shape = .circle(radius: random(2.5...4.5))
            } else {
                shape = .rectangle(width: random(6...11), height: random(3...6))
            }
            x0 = random(0...1)
            y0 = random(-0.14 ... -0.02)
            vx = random(-0.18...0.18)
            vy = random(-0.08...0.28)
            sway = random(0.015...0.06)
            swayFrequency = random(0.7...1.7)
            swayPhase = random(0...(2 * .pi))
            angle0 = random(0...(2 * .pi))
            spin = random(-5...5)
            flip = random(2.5...7)
            flipPhase = random(0...(2 * .pi))
        }

        func draw(in context: GraphicsContext, size: CGSize, at t: Double) {
            let x = x0 + vx * t + sway * sin(2 * .pi * swayFrequency * t + swayPhase)
            let y = y0 + vy * t + 0.5 * Self.gravity * t * t
            // Off the bottom, or faded out: nothing to draw.
            guard y < 1.1 else { return }
            let fade = max(0, min(1, (1 - t / ConfettiView.duration) / (1 - Self.fadeStart)))
            guard fade > 0 else { return }

            var local = context
            local.opacity = fade
            local.translateBy(x: x * size.width, y: y * size.height)
            local.rotate(by: .radians(angle0 + spin * t))
            switch shape {
            case .rectangle(let width, let height):
                // Never let the scale reach zero: a degenerate transform
                // is a wasted fill, and a hairline reads as a glint.
                let scale = max(0.15, abs(cos(flip * t + flipPhase)))
                local.scaleBy(x: scale, y: 1)
                local.fill(
                    Path(CGRect(x: -width / 2, y: -height / 2, width: width, height: height)),
                    with: .color(color)
                )
            case .circle(let radius):
                local.fill(
                    Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                    with: .color(color)
                )
            }
        }
    }

    // MARK: - Seeded generator

    /// SplitMix64. Deterministic, so a burst is the same burst every
    /// time it is drawn — which is what makes it previewable.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

#Preview("Burst") {
    ConfettiView(startedAt: .now)
        .background(Color.kadoBackground)
}

#Preview("Dark") {
    ConfettiView(startedAt: .now)
        .background(Color.kadoBackground)
        .preferredColorScheme(.dark)
}
