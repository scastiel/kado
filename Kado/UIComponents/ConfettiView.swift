import SwiftUI
import KadoCore

/// Two party poppers, one at each side of the screen, firing inward
/// and up — drawn on a `Canvas`.
///
/// Every particle's position, spin and fade are closed-form functions
/// of the time elapsed since `startedAt`, so the view holds no
/// simulation state: `TimelineView` asks for a frame, the canvas
/// evaluates each particle at that instant and draws it. Motion is a
/// launch velocity under gravity with linear air drag — the pop, then
/// the float — which has an exact solution and needs no integration.
/// The particle set comes from a seeded generator, so previews and
/// repeated runs look the same.
///
/// Purely decorative: it lets touches through and is hidden from
/// VoiceOver. The caller decides *when* to show it — and whether to,
/// under Reduce Motion.
struct ConfettiView: View {
    /// How long a burst lasts, fade included. The host removes the
    /// view after this.
    static let duration: TimeInterval = 3.4

    let startedAt: Date

    private let particles: [Particle]

    init(startedAt: Date, count: Int = 220, seed: UInt64 = 0x5EED_CAFE) {
        self.startedAt = startedAt
        var generator = SeededGenerator(seed: seed)
        // Alternating sides, so an odd count still splits evenly.
        particles = (0..<count).map { index in
            Particle(side: index.isMultiple(of: 2) ? .leading : .trailing, using: &generator)
        }
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

    /// One piece of confetti, fired from one edge.
    ///
    /// Launch speed, gravity and drag are tuned in points on a phone
    /// and scaled with the shorter screen side, so an iPad gets the
    /// same burst shape rather than a phone-sized puff in a corner.
    private struct Particle {
        /// The eight habit hues and the brand sage: a fistful of the
        /// colours the user already lives with, not a new palette.
        static let palette: [Color] = HabitColor.allCases.map(\.color) + [.kadoSage]

        enum Side {
            case leading
            case trailing
        }

        enum Shape {
            case rectangle(width: CGFloat, height: CGFloat)
            case circle(radius: CGFloat)
        }

        let side: Side
        let color: Color
        let shape: Shape
        /// Where along the edge the popper sits, in heights.
        let originY: Double
        /// Launch velocity in phone points per second: the horizontal
        /// part already carries the side's direction.
        let launchX: Double
        let launchY: Double
        /// Air drag, per second. Paper decelerates fast, and the more
        /// drag a piece has the sooner it stops travelling and starts
        /// floating.
        let drag: Double
        /// Seconds after the burst starts before this piece leaves the
        /// popper — a little roll so the burst isn't a single frame.
        let delay: Double
        /// Side-to-side flutter once it floats: amplitude in points,
        /// frequency in Hz.
        let sway: Double
        let swayFrequency: Double
        let swayPhase: Double
        /// In-plane spin and a fake out-of-plane tumble (the x scale
        /// runs through a cosine so a rectangle appears to flip).
        let angle0: Double
        let spin: Double
        let flip: Double
        let flipPhase: Double

        /// Phone points per second squared. With the drag above this
        /// gives a terminal fall of roughly 250–375 pt/s: a float, not
        /// a drop.
        static let gravity: Double = 900
        /// The screen width the tuning was done on. Larger screens
        /// scale speeds and gravity up by the same factor.
        static let referenceWidth: Double = 402
        /// The fraction of `duration` after which pieces start to fade.
        static let fadeStart: Double = 0.7

        init(side: Side, using generator: inout SeededGenerator) {
            func random(_ range: ClosedRange<Double>) -> Double {
                Double.random(in: range, using: &generator)
            }
            self.side = side
            color = Self.palette[Int.random(in: 0..<Self.palette.count, using: &generator)]
            // Sized for a phone at arm's length: on a 3× screen anything
            // under ~7pt reads as dust rather than paper.
            if random(0...1) < 0.25 {
                shape = .circle(radius: random(3...5.5))
            } else {
                shape = .rectangle(width: random(7...15), height: random(4...8))
            }
            // Poppers sit low; the burst has to climb the whole screen.
            // With these numbers half the pieces peak in the top
            // eighth, a tenth briefly leave the top and fall back in,
            // and the median piece crosses nearly the full width.
            originY = random(0.7...0.95)
            let speed = random(2200...3400)
            let angle = random(45...85) * .pi / 180
            let direction: Double = side == .leading ? 1 : -1
            launchX = direction * speed * cos(angle)
            launchY = -speed * sin(angle)
            drag = random(2.4...3.6)
            delay = random(0...0.18)
            sway = random(6...22)
            swayFrequency = random(0.8...1.8)
            swayPhase = random(0...(2 * .pi))
            angle0 = random(0...(2 * .pi))
            spin = random(-9...9)
            flip = random(3...9)
            flipPhase = random(0...(2 * .pi))
        }

        func draw(in context: GraphicsContext, size: CGSize, at elapsed: Double) {
            let t = elapsed - delay
            guard t > 0 else { return }
            let fade = max(0, min(1, (1 - elapsed / ConfettiView.duration) / (1 - Self.fadeStart)))
            guard fade > 0 else { return }

            let scale = max(1, min(size.width, size.height) / Self.referenceWidth)
            let k = drag
            let decay = 1 - exp(-k * t)
            // Just off the edge, so the first frame shows pieces
            // already in flight rather than popping into existence.
            let originX = side == .leading ? -0.03 * size.width : 1.03 * size.width
            // Linear drag under gravity, solved exactly: velocity
            // relaxes from the launch value toward terminal (gravity /
            // drag) with time constant 1 / drag.
            let x = originX
                + scale * launchX / k * decay
                + scale * sway * sin(2 * .pi * swayFrequency * t + swayPhase) * decay
            let terminal = Self.gravity / k
            let y = originY * size.height
                + scale * (terminal * t + (launchY - terminal) / k * decay)
            // Off the bottom: nothing to draw.
            guard y < size.height * 1.1 else { return }

            var local = context
            local.opacity = fade
            local.translateBy(x: x, y: y)
            local.rotate(by: .radians(angle0 + spin * t))
            switch shape {
            case .rectangle(let width, let height):
                // Never let the scale reach zero: a degenerate transform
                // is a wasted fill, and a hairline reads as a glint.
                let flipScale = max(0.15, abs(cos(flip * t + flipPhase)))
                local.scaleBy(x: flipScale * scale, y: scale)
                local.fill(
                    Path(CGRect(x: -width / 2, y: -height / 2, width: width, height: height)),
                    with: .color(color)
                )
            case .circle(let radius):
                local.scaleBy(x: scale, y: scale)
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
