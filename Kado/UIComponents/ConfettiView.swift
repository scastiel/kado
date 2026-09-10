import SwiftUI
import KadoCore

/// Two party poppers, one at each side of the screen, firing inward
/// and up — drawn on a `Canvas`.
///
/// Every particle's position, spin and fade are closed-form functions
/// of the time elapsed since `startedAt`, so the view holds no
/// simulation state: `TimelineView` asks for a frame, the canvas
/// evaluates each particle at that instant and draws it. The particle
/// set comes from a seeded generator, so previews and repeated runs
/// look the same.
///
/// Each piece has two lives. The **pop**: a launch under gravity with
/// linear air drag, which has an exact solution and plays out as a
/// visible arc over most of a second. The **float**: what a flat piece of paper does
/// once it has stopped travelling — it glides sideways while it is
/// flat and slow, then tips edge-on and drops, over and over. That is
/// modelled as a sideways sine whose vertical speed is slowest at the
/// ends of each glide and fastest in the middle, integrated in closed
/// form, with a fall speed that differs piece to piece.
///
/// Purely decorative: it lets touches through and is hidden from
/// VoiceOver. The caller decides *when* to show it — and whether to,
/// under Reduce Motion.
struct ConfettiView: View {
    /// How long a burst lasts, fade included. The host removes the
    /// view after this.
    static let duration: TimeInterval = 3.6

    let startedAt: Date

    private let particles: [Particle]

    init(startedAt: Date, count: Int = 160, seed: UInt64 = 0x5EED_CAFE) {
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
        /// Air drag during the pop, per second. The launch velocity
        /// relaxes toward the float with time constant 1 / drag.
        let drag: Double
        /// Seconds after the burst starts before this piece leaves the
        /// popper — a little roll so the burst isn't a single frame.
        let delay: Double
        /// Steady fall once floating, phone points per second. A
        /// slip of paper and a heavier dot fall at different speeds,
        /// so the cloud stretches instead of sinking as a block.
        let terminal: Double
        /// A gentle constant sideways breeze, points per second, so
        /// pieces don't all settle on their own vertical.
        let breeze: Double
        /// The glide: amplitude in points, angular frequency, phase.
        let glide: Double
        let glideOmega: Double
        let glidePhase: Double
        /// How much the fall slows at the ends of a glide (0…1).
        let flutter: Double
        /// In-plane spin and a fake out-of-plane tumble (the x scale
        /// runs through a cosine so a rectangle appears to flip).
        let angle0: Double
        let spin: Double
        let flip: Double
        let flipPhase: Double

        /// The screen width the tuning was done on. Larger screens
        /// scale distances and speeds up by the same factor.
        static let referenceWidth: Double = 402
        /// The fraction of `duration` after which pieces start to fade.
        static let fadeStart: Double = 0.68

        init(side: Side, using generator: inout SeededGenerator) {
            func random(_ range: ClosedRange<Double>) -> Double {
                Double.random(in: range, using: &generator)
            }
            self.side = side
            color = Self.palette[Int.random(in: 0..<Self.palette.count, using: &generator)]
            // Sized for a phone at arm's length: on a 3× screen anything
            // under ~7pt reads as dust rather than paper.
            let isDot = random(0...1) < 0.22
            if isDot {
                shape = .circle(radius: random(3...5))
            } else {
                shape = .rectangle(width: random(7...15), height: random(4...8))
            }
            // Poppers sit low and fire along an axis about 68° above
            // horizontal, in a fan that bunches toward the axis (two
            // rolls averaged) the way a cannon's stream does. With the
            // drag below the flight is visible for most of a second:
            // the median piece peaks in the upper half of the screen
            // three-quarters of the way across, and leaves the bottom
            // just under three seconds in.
            originY = random(0.72...0.95)
            let speed = random(1000...1900)
            let spread = (random(-12...12) + random(-12...12)) / 2
            let angle = (68 + spread) * .pi / 180
            let direction: Double = side == .leading ? 1 : -1
            launchX = direction * speed * cos(angle)
            launchY = -speed * sin(angle)
            drag = random(1.3...2.1)
            // A stream, not a shell: the popper empties over a third
            // of a second.
            delay = random(0...0.3)
            // Dots are the heavy ones: they drop straighter and faster
            // and hardly glide. Strips linger.
            terminal = isDot ? random(480...680) : random(320...520)
            breeze = random(-18...18)
            glide = isDot ? random(4...10) : random(22...56)
            glideOmega = 2 * .pi * (isDot ? random(1.2...2) : random(0.5...1.0))
            glidePhase = random(0...(2 * .pi))
            flutter = isDot ? random(0.05...0.15) : random(0.35...0.6)
            angle0 = random(0...(2 * .pi))
            spin = random(-4...4)
            // The tumble rides on the glide's phase (see `draw`), so
            // this is only a slow drift on top of it — enough that two
            // pieces on the same glide don't flip in lockstep.
            flip = isDot ? 0 : random(0.3...1.2)
            flipPhase = random(-0.4...0.4)
        }

        func draw(in context: GraphicsContext, size: CGSize, at elapsed: Double) {
            let t = elapsed - delay
            guard t > 0 else { return }
            let fade = max(0, min(1, (1 - elapsed / ConfettiView.duration) / (1 - Self.fadeStart)))
            guard fade > 0 else { return }

            let scale = max(1, min(size.width, size.height) / Self.referenceWidth)
            let k = drag
            // 0 at launch, 1 once the pop has burned out. Also what
            // brings the float in, so the two lives blend rather than
            // switch.
            let settled = 1 - exp(-k * t)

            // The pop: linear drag under gravity, solved exactly —
            // velocity relaxes from the launch value toward the float.
            let popX = launchX / k * settled
            let popY = terminal * t + (launchY - terminal) / k * settled

            // The float. Sideways: a glide that starts from rest.
            // Vertical: the fall is slowest at the ends of each glide
            // (the piece is flat, sliding) and fastest in the middle
            // (edge-on, dropping) — speed ∝ 1 − flutter·cos 2θ, whose
            // integral is the sine term below.
            let theta = glideOmega * t + glidePhase
            let glideX = (glide * (sin(theta) - sin(glidePhase)) + breeze * t) * settled
            let flutterY = -terminal * flutter / (2 * glideOmega)
                * (sin(2 * theta) - sin(2 * glidePhase)) * settled

            // Just off the edge, so the first frame shows pieces
            // already in flight rather than popping into existence.
            let originX = side == .leading ? -0.03 * size.width : 1.03 * size.width
            let x = originX + scale * (popX + glideX)
            let y = originY * size.height + scale * (popY + flutterY)
            // Off the bottom: nothing to draw.
            guard y < size.height * 1.1 else { return }

            var local = context
            local.opacity = fade
            local.translateBy(x: x, y: y)
            local.rotate(by: .radians(angle0 + spin * t))
            switch shape {
            case .rectangle(let width, let height):
                // The tumble follows the glide: flat (cos θ = ±1) at
                // the ends where the piece slides slowly, on edge
                // (cos θ = 0) through the middle where it drops — the
                // same phase the fall speed keys off, so what the eye
                // sees and how the piece moves agree. Never fully
                // edge-on: a degenerate transform is a wasted fill,
                // and a hairline reads as a glint.
                let flipScale = max(0.12, abs(cos(theta + flip * t + flipPhase)))
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
