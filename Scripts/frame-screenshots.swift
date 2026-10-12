#!/usr/bin/env swift
//
// Wraps the raw App Store captures in the listing's own artwork: Kadō's paper ground, a
// Fraunces headline, and a device the screenshot sits inside.
//
//   swift Scripts/frame-screenshots.swift <captures> <destination> <captions.json>
//
// It walks <captures>/<locale>/<device>/*.png — the tree `Scripts/screenshots.sh` writes — and
// puts a framed copy of each at the same path under <destination>, under the same file name, so
// the numbering that orders the set in App Store Connect survives.
//
// A folder beside the device folders, <captures>/<locale>/NN-name/, is an *assembly*: a shot
// composed here from the tiles inside it rather than photographed whole. The widgets shot is one
// — the Home Screen and Lock Screen widgets, each photographed on its own off the app's
// Debug-only gallery, arranged on the paper ground under the headline. It is drawn on every
// device's canvas from the same tiles, which is why it sits at the locale level.
//
// Once per locale it also draws the listing's landscape *creative* — the product page header
// and the search results banner, one 16:9 image for both — from that locale's iPhone Today
// capture, into <destination>/<locale>/creative/universal.png. See `Creative`.
//
// The raw captures stay the source of truth, which is the point of doing this as a second pass:
// a new headline or a different green is seconds of work here, where re-photographing the app
// is a simulator per language per device and the better part of half an hour.
//
// AppKit does all of it. Nothing here needs a dependency — the one non-system font is Fraunces,
// which the app already ships and this registers from the same file.

import AppKit
import CoreText
import Foundation

// MARK: - Palette
//
// The app's own tokens, read off `KadoCore/Design/Theme.swift` rather than invented. Kadō is a
// paper-and-sage app, not a saturated-gradient one: a listing drawn in somebody else's idiom
// stops looking like the product the moment the screenshot inside the frame loads.

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

let paper50 = rgb(0.984, 0.973, 0.949)   // kadoPaper50, light
let sage100 = rgb(0.878, 0.914, 0.886)   // kadoSage100, light
let sage900 = rgb(0.122, 0.227, 0.173)   // kadoSage900, light
let ink900 = rgb(0.106, 0.102, 0.090)    // kadoInk900, light

let paper50Dark = rgb(0.078, 0.075, 0.059)  // kadoPaper50, dark
let sage100Dark = rgb(0.122, 0.165, 0.137)  // kadoSage100, dark
let paper300Dark = rgb(0.227, 0.204, 0.173) // kadoPaper300, dark

/// The four colours a frame is drawn from.
struct Palette {
    let top: NSColor
    let bottom: NSColor
    let headline: NSColor
    let bezel: NSColor

    /// Paper at the top, where the headline is, easing into sage at the bottom, where the
    /// device is. Ink on paper is ~11.7:1 — far past the 3:1 large-text floor, which matters
    /// here because an App Store thumbnail is where a marginal choice shows first.
    static let light = Palette(top: paper50, bottom: sage100, headline: sage900, bezel: ink900)

    /// For the dark-mode capture, so the shot isn't a black rectangle marooned on white. The
    /// bezel goes *lighter* than the ground rather than darker: a near-black device on a
    /// near-black page has no edge at all.
    static let dark = Palette(
        top: paper50Dark, bottom: sage100Dark, headline: paper50, bezel: paper300Dark
    )
}

// MARK: - Typography
//
// Fraunces is what the app draws its large titles in, and it is already in the repo as the
// variable TTF `KadoCore` registers at launch. Registering the same file here is what keeps the
// listing and the product in one voice. If it can't be registered the frames still draw, in the
// system serif, with a warning — a missing font is worth a note, not a stopped run.

let frauncesPath = "Packages/KadoCore/Sources/KadoCore/Resources/Fonts/"
    + "Fraunces[SOFT,WONK,opsz,wght].ttf"

@discardableResult
func registerFraunces() -> Bool {
    let url = URL(fileURLWithPath: frauncesPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write(Data("note: \(frauncesPath) is missing\n".utf8))
        return false
    }
    var error: Unmanaged<CFError>?
    let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    if !registered {
        let message = (error?.takeRetainedValue()).map { "\($0)" } ?? "unknown error"
        FileHandle.standardError.write(Data("note: could not register Fraunces: \(message)\n".utf8))
    }
    return registered
}

let hasFraunces = registerFraunces()

func headlineFont(_ size: CGFloat) -> NSFont {
    if hasFraunces, let fraunces = NSFont(name: "Fraunces-Medium", size: size) {
        return fraunces
    }
    // The system serif at the same optical weight, so a machine without the font still
    // produces something that reads as the same design rather than as a different one.
    let descriptor = NSFont.systemFont(ofSize: size, weight: .semibold)
        .fontDescriptor.withDesign(.serif)
    return descriptor.flatMap { NSFont(descriptor: $0, size: size) }
        ?? NSFont.systemFont(ofSize: size, weight: .semibold)
}

// MARK: - Device profiles

struct Profile {
    /// The canvas App Store Connect accepts for this device, which is also the size of the
    /// capture: the frame is drawn around a screenshot at its own scale, never a resized one.
    let canvas: NSSize
    /// The screen's width as a fraction of the canvas.
    let screenWidthFraction: CGFloat
    /// Corner radius as a fraction of the screen's width, taken from the real hardware — the
    /// iPhone's corners are dramatic and the iPad's are nearly square, and getting this wrong
    /// is the detail that makes a frame look drawn rather than photographed.
    let cornerFraction: CGFloat
    let bezel: CGFloat
    let headlineSize: CGFloat
    /// Distance from the top of the canvas to the top of the first line of the headline.
    let headlineTop: CGFloat
    /// From the last line of the headline to the top of the device.
    let headlineGap: CGFloat
    /// The clear space the headline keeps either side of it. A translation that would run past
    /// it shrinks to fit rather than crowding the edge — French is reliably the longer of the
    /// two, and a line that nearly touches the canvas reads as a mistake at thumbnail size.
    let headlineMargin: CGFloat
    /// How the widget tiles are arranged on this canvas.
    let assembly: Assembly

    static func named(_ name: String) -> Profile? {
        switch name {
        case "iphone-6.9":
            return Profile(
                canvas: NSSize(width: 1320, height: 2868),
                screenWidthFraction: 0.80,
                cornerFraction: 0.125,
                bezel: 14,
                headlineSize: 82,
                headlineTop: 150,
                headlineGap: 96,
                headlineMargin: 110,
                assembly: .column
            )
        case "ipad-13":
            return Profile(
                canvas: NSSize(width: 2064, height: 2752),
                screenWidthFraction: 0.76,
                cornerFraction: 0.030,
                bezel: 18,
                headlineSize: 100,
                headlineTop: 180,
                headlineGap: 110,
                headlineMargin: 170,
                assembly: .twoColumns
            )
        default:
            return nil
        }
    }
}

// MARK: - The widget assembly
//
// The tiles are photographed at their Home Screen / Lock Screen point sizes — the ones in
// `WidgetTileMetrics`, in the app — so they are laid out in points here and scaled once, as a
// group, onto the canvas. The tile PNGs are 3× and every canvas asks for a little under that,
// so nothing is upscaled: a soft tile beside a pixel-exact device frame is the one thing that
// would give the assembly away.

/// One tile's file name (under `NN-name/`) and its size in points.
struct Tile {
    let part: String
    let size: NSSize

    static let medium = Tile(part: "medium", size: NSSize(width: 364, height: 170))
    static let small = Tile(part: "small", size: NSSize(width: 170, height: 170))
    static let large = Tile(part: "large", size: NSSize(width: 364, height: 382))
    static let lock = Tile(part: "lock", size: NSSize(width: 186, height: 230))
}

/// Where each tile sits, in points from the assembly's top-left corner.
struct Assembly {
    let placements: [(tile: Tile, origin: NSPoint)]
    /// The whole arrangement's size in points, which is what gets scaled to the canvas.
    let size: NSSize
    /// The arrangement's width as a fraction of the canvas — the device's role, played by the
    /// tiles. Chosen so the 3× tiles land at or a touch under 1:1.
    let widthFraction: CGFloat

    /// The Home Screen's container corner on iPhone, in points. `WidgetTileMetrics.cornerRadius`
    /// in the app — the gallery clips with it and so does this.
    static let cornerRadius: CGFloat = 22
    /// Between tiles, in points. About what the Home Screen leaves between two widgets.
    static let gap: CGFloat = 16

    /// The phone's canvas is tall: one column, the width of the medium tile — medium; small
    /// beside the lock card; large.
    static let column: Assembly = {
        let gap = Assembly.gap
        let row2 = Tile.medium.size.height + gap
        let row3 = row2 + Tile.lock.size.height + gap
        return Assembly(
            placements: [
                (.medium, NSPoint(x: 0, y: 0)),
                (.small, NSPoint(x: 0, y: row2)),
                (.lock, NSPoint(x: Tile.small.size.width + gap, y: row2)),
                (.large, NSPoint(x: 0, y: row3)),
            ],
            size: NSSize(width: Tile.medium.size.width, height: row3 + Tile.large.size.height),
            widthFraction: 0.78
        )
    }()

    /// The iPad's canvas is nearly square, and a phone's column on it would be a strip down the
    /// middle. Two columns instead: the Home Screen tiles stacked on the left, the small tile
    /// and the lock card down the right, each row's tops aligned. The small tile is narrower
    /// than the lock card and sits flush with its outer edge, so the arrangement's silhouette
    /// is a rectangle rather than a rectangle with a notch.
    static let twoColumns: Assembly = {
        let gap = Assembly.gap
        let right = Tile.medium.size.width + gap
        let row2 = Tile.medium.size.height + gap
        let smallInset = Tile.lock.size.width - Tile.small.size.width
        return Assembly(
            placements: [
                (.medium, NSPoint(x: 0, y: 0)),
                (.small, NSPoint(x: right + smallInset, y: 0)),
                (.large, NSPoint(x: 0, y: row2)),
                (.lock, NSPoint(x: right, y: row2)),
            ],
            size: NSSize(
                width: right + Tile.lock.size.width,
                height: row2 + Tile.large.size.height
            ),
            // A touch over 1:1 on the 3× tiles — 1.03 — which is invisible at this size, and
            // buys the arrangement enough of the canvas not to float in the top half.
            widthFraction: 0.84
        )
    }()
}

// MARK: - Drawing

/// One line of the headline, measured so it can be centred and stacked by hand.
///
/// Laid out a line at a time rather than handed to a text container: the breaks come from
/// `captions.json`, where somebody chose them, and automatic wrapping would quietly override
/// that the first time a translation ran a word longer.
func attributed(_ line: String, size: CGFloat, color: NSColor) -> NSAttributedString {
    NSAttributedString(
        string: line,
        attributes: [
            .font: headlineFont(size),
            .foregroundColor: color,
            // Display type is drawn too loose at these sizes; a touch of negative tracking is
            // what the system does for itself in its own large titles.
            .kern: -size * 0.012,
        ]
    )
}

/// Sets up a canvas, draws the ground and the headline, and hands `content` the distance from
/// the top of the canvas to where whatever sits under the headline starts — the same for a
/// device and for an assembly, so the two kinds of shot line up in the strip.
func canvas(
    caption: String, profile: Profile, palette: Palette, content: (_ top: CGFloat) -> Void
) -> NSBitmapImageRep {
    let canvas = profile.canvas
    return ground(canvas, palette: palette) {
        // The headline, stacked downwards from `headlineTop`. The context is unflipped, so a
        // line's drawing origin is its lower-left corner and the arithmetic runs from the top of
        // the canvas.
        let lines = caption.components(separatedBy: "\n")
        // One size for the whole headline, chosen so its longest line clears the margin.
        // Scaling the offending line alone would be the smaller change and would look like a
        // mistake.
        let headlineSize = fitted(
            lines, size: profile.headlineSize, color: palette.headline,
            within: canvas.width - profile.headlineMargin * 2
        )
        // The grid the lines sit on stays at the profile's size even when the glyphs shrink, so
        // the device below starts at the same height in every shot and every language. Sizing
        // the grid to the fitted text instead would lift the phone a few pixels wherever French
        // ran long, and the set is looked at as a strip.
        let lineHeight = profile.headlineSize * 1.16
        for (index, line) in lines.enumerated() {
            let text = attributed(line, size: headlineSize, color: palette.headline)
            let width = text.size().width
            let bottom = canvas.height - profile.headlineTop - lineHeight * CGFloat(index + 1)
            text.draw(at: NSPoint(x: (canvas.width - width) / 2, y: bottom))
        }

        content(profile.headlineTop + lineHeight * CGFloat(lines.count) + profile.headlineGap)
    }
}

/// The largest size, up to `size`, at which the widest of `lines` fits in `available`.
func fitted(_ lines: [String], size: CGFloat, color: NSColor, within available: CGFloat) -> CGFloat {
    let widest = lines
        .map { attributed($0, size: size, color: color).size().width }
        .max() ?? 0
    return widest > available ? (size * available / widest).rounded(.down) : size
}

/// A bitmap of `canvas`'s size with the palette's ground already on it, current while `body`
/// draws over it.
func ground(_ canvas: NSSize, palette: Palette, _ body: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = canvas

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let bounds = NSRect(origin: .zero, size: canvas)

    // The background. Angle 270 puts the starting colour at the top; AppKit's zero is to the
    // right and it turns anticlockwise.
    NSGradient(starting: palette.top, ending: palette.bottom)?.draw(in: bounds, angle: 270)

    body()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// A rounded, shadowed slab — the phone's body, or a widget tile's — filled with `color`.
///
/// Shadow on the fill only: set on the fill and cleared before anything goes in over it, or
/// every pixel of the picture picks it up as a halo.
func slab(_ rect: NSRect, radius: CGFloat, color: NSColor, shadowOffset: CGFloat, shadowBlur: CGFloat, shadowAlpha: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -shadowOffset)
    shadow.shadowBlurRadius = shadowBlur
    shadow.shadowColor = NSColor.black.withAlphaComponent(shadowAlpha)
    shadow.set()
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()
}

/// Draws `image` into `rect`, clipped to a rounded rectangle.
func draw(_ image: NSImage, in rect: NSRect, radius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    image.draw(
        in: rect,
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
}

func frame(
    capture: NSImage, caption: String, profile: Profile, palette: Palette
) -> NSBitmapImageRep {
    canvas(caption: caption, profile: profile, palette: palette) { top in
        let canvas = profile.canvas
        // The device. Its width is fixed by the profile and its height follows the capture's
        // own aspect, so a screenshot is never stretched to fit a frame that disagrees with it.
        let screenWidth = (canvas.width * profile.screenWidthFraction).rounded()
        let screenHeight = (screenWidth * canvas.height / canvas.width).rounded()
        let screen = NSRect(
            x: ((canvas.width - screenWidth) / 2).rounded(),
            y: canvas.height - top - screenHeight,
            width: screenWidth,
            height: screenHeight
        )
        let screenRadius = screenWidth * profile.cornerFraction
        slab(
            screen.insetBy(dx: -profile.bezel, dy: -profile.bezel),
            radius: screenRadius + profile.bezel,
            color: palette.bezel,
            shadowOffset: profile.bezel * 2,
            shadowBlur: profile.bezel * 4,
            shadowAlpha: 0.28
        )
        draw(capture, in: screen, radius: screenRadius)
    }
}

/// The widget shot: the tiles laid out per the profile's `Assembly`, centred under the
/// headline where a device would start.
func assemble(
    tiles: [String: NSImage], caption: String, profile: Profile, palette: Palette
) -> NSBitmapImageRep {
    canvas(caption: caption, profile: profile, palette: palette) { top in
        let canvas = profile.canvas
        let layout = profile.assembly
        // One scale for the group, from the arrangement's width — the same role the device's
        // width plays in the other frames.
        let scale = (canvas.width * layout.widthFraction) / layout.size.width
        let originX = ((canvas.width - layout.size.width * scale) / 2).rounded()
        let radius = Assembly.cornerRadius * scale

        for (tile, origin) in layout.placements {
            guard let image = tiles[tile.part] else {
                fail("the widgets assembly has no \(tile.part) tile")
            }
            let rect = NSRect(
                x: (originX + origin.x * scale).rounded(),
                y: (canvas.height - top - (origin.y + tile.size.height) * scale).rounded(),
                width: (tile.size.width * scale).rounded(),
                height: (tile.size.height * scale).rounded()
            )
            // Lighter than the phone's: these are tiles resting on paper, not a device. The fill
            // under the image is paper so an antialiased edge blends into the tile, not into a
            // dark ring.
            slab(
                rect,
                radius: radius,
                color: paper50,
                shadowOffset: profile.bezel,
                shadowBlur: profile.bezel * 3,
                shadowAlpha: 0.16
            )
            draw(image, in: rect, radius: radius)
        }
    }
}

// MARK: - The creative asset
//
// iOS 27 gives a listing two landscape slots — a header across the top of the product page and
// a creative in search results — and one 16:9 image fills both. Apple crops it to roughly 21:9
// for the header and roughly 3:2 for search and publishes no numbers, so everything that has to
// survive both crops sits in `safe`, a centred band assumed to be 60% of the width and 75% of
// the height. The ground runs edge to edge under it; nothing else is allowed outside.

enum Creative {
    /// App Store Connect's universal creative canvas: 16:9, and refused at any other size.
    static let canvas = NSSize(width: 5244, height: 2950)
    static let safe = NSRect(
        x: canvas.width * 0.2, y: canvas.height * 0.125,
        width: canvas.width * 0.6, height: canvas.height * 0.75
    )

    /// The capture the device shows — read out of each locale's captures, so the French
    /// creative shows the French app.
    static let device = "iphone-6.9"
    static let shot = "01-today"
    /// Its key in each locale of `captions.json`, and its file name under `creative/`.
    static let caption = "creative-universal"
    static let name = "universal"

    /// The phone's screen height. Its width follows the capture, and the bezel, corner and
    /// shadow follow the portrait iPhone frame in proportion, so the two read as one device.
    static let screenHeight: CGFloat = 2060
    static let headlineSize: CGFloat = 230
    /// Between the end of the headline's longest line and the phone.
    static let gap: CGFloat = 240

    /// The lockup over the headline: the icon and the name, so a banner seen in search results
    /// says whose it is before it says anything else.
    static let appName = "Kadō"
    static let nameSize: CGFloat = 150
    static let iconSize: CGFloat = 230
    static let iconGap: CGFloat = 56
    static let lockupGap: CGFloat = 170
    /// The app's default icon, the one a first-time visitor sees beside the listing.
    static let icon = NSImage(
        contentsOfFile: "Kado/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    )

    /// The sign-off at the foot of Settings, under the headline. Verbatim, as `SettingsView`
    /// draws it — 稼働 is brand art, not a phrase, and the app doesn't translate it either.
    static let wordmark = "稼 働 · in operation"
    static let wordmarkSize: CGFloat = 80
    static let wordmarkGap: CGFloat = 130
    /// From the wordmark down to the Overview grid that closes the column. See `Matrix`.
    static let matrixGap: CGFloat = 150
}

// MARK: - The Overview matrix, in monochrome
//
// The creative's lowest tier is a slice of the Overview tab's habit × day grid, drawn here
// rather than cropped from a capture: the capture is in the habits' own hues, and the banner
// wants the app's monochrome sage theme, which no screenshot photographs. Everything below is
// a port, not an approximation — the colours are mixed the way `MatrixCell` mixes them, in
// Oklab, so a cell here is the colour the same cell is on the phone.

/// The Oklab ↔ sRGB pair from `KadoCore/Design/OKLCH.swift`.
enum Oklab {
    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    static func gamma(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    static func fromSRGB(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let (r, g, b) = (linear(r), linear(g), linear(b))
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    static func toSRGB(_ L: Double, _ a: Double, _ b: Double) -> NSColor {
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        let clip = { (c: Double) in CGFloat(min(max(gamma(c), 0), 1)) }
        return rgb(
            clip(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            clip(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            clip(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }
}

/// One row's sage: `HabitTheme.monochromeSageBase` in light mode — hue 158, chroma 0.065, and
/// a lightness stepped by the habit's colour slot (red 0 … purple 7), darkest first.
struct MonochromeHabit {
    let base: (L: Double, a: Double, b: Double)

    init(slot: Int) {
        let hue = 158 * Double.pi / 180
        base = (0.36 + Double(slot) * 0.06, 0.065 * cos(hue), 0.065 * sin(hue))
    }

    /// `lerp(paper, base, amount)` in Oklab, the way a scored cell is filled.
    func color(_ amount: Double) -> NSColor {
        let ground = Oklab.fromSRGB(0.984, 0.973, 0.949)
        let t = (amount * 100).rounded() / 100
        return Oklab.toSRGB(
            ground.0 + (base.L - ground.0) * t,
            ground.1 + (base.a - ground.1) * t,
            ground.2 + (base.b - ground.2) * t
        )
    }
}

/// A day in a row: a score in 0…1, or nil for a day the habit wasn't due.
typealias MatrixDay = Double?

/// Two weeks of four of the screenshot seed's habits, by their colour slots. Hand-set, not
/// computed: mostly done, some partial, one plain miss, and the scheduled habits' off days —
/// a grid that looks lived in and makes the headline's point, that a gap isn't a zero.
let creativeMatrix: [(slot: Int, days: [MatrixDay])] = [
    // No social media (red): daily, one slip.
    (0, [1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1]),
    // Gym (orange): three days a week.
    (1, [1, nil, 1, nil, nil, 1, nil, 1, nil, 1, nil, nil, 1, nil]),
    // Running (green): most days, the rest off.
    (3, [1, 1, nil, 1, 1, nil, nil, 1, 1, nil, 1, 1, nil, 1]),
    // Read (mint): a timer, so it lands short of the target as often as on it.
    (4, [1, 0.6, 1, 1, 0.45, 1, 0.8, 1, 1, 0.55, 1, 1, 0.7, 0.3]),
]

/// The grid's proportions, from `OverviewView` in points: 36pt cells, 6pt apart, 6pt corners.
enum Matrix {
    static let cell: CGFloat = 36
    static let spacing: CGFloat = 6
    static let corner: CGFloat = 6
    static let notDueFill = rgb(0.957, 0.937, 0.902)  // kadoBackgroundSecondary, light
    static let hairline = rgb(0.914, 0.882, 0.824)    // kadoHairline, light

    /// The grid's height when its width is `width`.
    static func height(width: CGFloat) -> CGFloat {
        let columns = CGFloat(creativeMatrix[0].days.count)
        let rows = CGFloat(creativeMatrix.count)
        let scale = width / (columns * cell + (columns - 1) * spacing)
        return (rows * cell + (rows - 1) * spacing) * scale
    }

    /// Draws the grid with its top-left corner at `origin`, `width` wide.
    static func draw(at origin: NSPoint, width: CGFloat) {
        let columns = CGFloat(creativeMatrix[0].days.count)
        let scale = width / (columns * cell + (columns - 1) * spacing)
        let size = cell * scale
        let step = (cell + spacing) * scale
        let radius = corner * scale
        for (row, habit) in creativeMatrix.enumerated() {
            let sage = MonochromeHabit(slot: habit.slot)
            for (column, day) in habit.days.enumerated() {
                let rect = NSRect(
                    x: origin.x + CGFloat(column) * step,
                    y: origin.y - CGFloat(row) * step - size,
                    width: size, height: size
                ).integral
                let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
                if let score = day {
                    // `0.2 + 0.8 × score`: a miss is the ramp's floor, never blank.
                    sage.color(0.2 + 0.8 * min(max(score, 0), 1)).setFill()
                    path.fill()
                } else {
                    notDueFill.setFill()
                    path.fill()
                    // `strokeBorder`: 1pt, inside the shape.
                    let inset = rect.insetBy(dx: scale / 2, dy: scale / 2)
                    let ring = NSBezierPath(roundedRect: inset, xRadius: radius - scale / 2, yRadius: radius - scale / 2)
                    ring.lineWidth = scale
                    hairline.setStroke()
                    ring.stroke()
                }
            }
        }
    }
}

/// `kadoInk300`, light — `kadoForegroundTertiary`, the colour Settings sets the wordmark in.
let ink300 = rgb(0.576, 0.537, 0.482)

/// The Settings wordmark: the system serif, regular, tracked open the way the app tracks it
/// (2pt at 13pt). The 稼働 glyphs come from the system's fallback cascade, as they do on iOS.
func wordmark(_ text: String, size: CGFloat) -> NSAttributedString {
    let descriptor = NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
    let font = descriptor.flatMap { NSFont(descriptor: $0, size: size) } ?? NSFont.systemFont(ofSize: size)
    return NSAttributedString(
        string: text,
        attributes: [.font: font, .foregroundColor: ink300, .kern: size * 2 / 13]
    )
}

/// The universal creative: a left-aligned headline and the Today screen in a phone, centred as
/// one group in the safe band.
///
/// The phone alone, on purpose. A mock with two widget tiles leaning on its edge
/// (`docs/plans/2026-10/listing-creative/`) repeated the list's own rows at a smaller size and
/// covered the one marked "Slipped" — the row that *is* the headline's claim.
func creative(capture: NSImage, caption: String, palette: Palette) -> NSBitmapImageRep {
    let canvas = Creative.canvas
    let safe = Creative.safe
    let iphone = Profile.named(Creative.device)!
    let screenHeight = Creative.screenHeight
    let screenWidth = (screenHeight * capture.size.width / capture.size.height).rounded()
    let bezel = (iphone.bezel * screenWidth / (iphone.canvas.width * iphone.screenWidthFraction))
        .rounded()

    return ground(canvas, palette: palette) {
        let lines = caption.components(separatedBy: "\n")
        let phoneWidth = screenWidth + bezel * 2
        let headlineSize = fitted(
            lines, size: Creative.headlineSize, color: palette.headline,
            within: safe.width - Creative.gap - phoneWidth
        )
        let texts = lines.map { attributed($0, size: headlineSize, color: palette.headline) }
        let name = attributed(Creative.appName, size: Creative.nameSize, color: palette.headline)
        let mark = wordmark(Creative.wordmark, size: Creative.wordmarkSize)
        let iconSize = Creative.iconSize
        let lockupWidth = iconSize + Creative.iconGap + name.size().width
        let columnWidth = max(
            texts.map { $0.size().width }.max() ?? 0, lockupWidth, mark.size().width
        )

        // The text column, three tiers stacked top-down and centred as a block against the
        // phone: who it is, what it believes, and the app's own sign-off from the foot of
        // Settings.
        let lineHeight = headlineSize * 1.16
        let headlineHeight = lineHeight * CGFloat(lines.count)
        let markHeight = mark.size().height
        let matrixHeight = Matrix.height(width: columnWidth)
        let columnHeight = iconSize + Creative.lockupGap + headlineHeight
            + Creative.wordmarkGap + markHeight + Creative.matrixGap + matrixHeight

        // One group, centred: the crops are centred, so a group that is centred survives both
        // of them by the same margin on either side.
        let left = ((canvas.width - columnWidth - Creative.gap - phoneWidth) / 2).rounded()
        var top = ((canvas.height + columnHeight) / 2).rounded()

        if let icon = Creative.icon {
            let rect = NSRect(x: left, y: top - iconSize, width: iconSize, height: iconSize)
            // The icon's own corner, as the Home Screen masks it. The PNG is square; iOS
            // supplies the shape.
            let radius = iconSize * 0.2237
            slab(rect, radius: radius, color: palette.top, shadowOffset: 8, shadowBlur: 28, shadowAlpha: 0.14)
            draw(icon, in: rect, radius: radius)
        }
        // The name's cap height centred on the icon, not its line box, which carries the
        // descender space a word with no descenders doesn't use.
        let font = headlineFont(Creative.nameSize)
        let nameBaseline = top - iconSize / 2 - font.capHeight / 2
        name.draw(at: NSPoint(x: left + iconSize + Creative.iconGap, y: nameBaseline + font.descender))
        top -= iconSize + Creative.lockupGap

        for (index, text) in texts.enumerated() {
            text.draw(at: NSPoint(x: left, y: top - lineHeight * CGFloat(index + 1)))
        }
        top -= headlineHeight + Creative.wordmarkGap
        mark.draw(at: NSPoint(x: left, y: top - markHeight))
        top -= markHeight + Creative.matrixGap
        Matrix.draw(at: NSPoint(x: left, y: top), width: columnWidth)

        let screen = NSRect(
            x: left + columnWidth + Creative.gap + bezel,
            y: ((canvas.height - screenHeight) / 2).rounded(),
            width: screenWidth,
            height: screenHeight
        )
        let screenRadius = screenWidth * iphone.cornerFraction
        slab(
            screen.insetBy(dx: -bezel, dy: -bezel),
            radius: screenRadius + bezel,
            color: palette.bezel,
            shadowOffset: bezel * 2,
            shadowBlur: bezel * 4,
            shadowAlpha: 0.28
        )
        draw(capture, in: screen, radius: screenRadius)
    }
}

/// `rep` as a PNG with no alpha channel at all — not an opaque alpha channel, which is still
/// one. App Store Connect refuses a creative that carries alpha, whatever its values.
func opaquePNG(_ rep: NSBitmapImageRep) -> Data? {
    guard
        let image = rep.cgImage,
        let space = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
            data: nil, width: rep.pixelsWide, height: rep.pixelsHigh, bitsPerComponent: 8,
            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh))
    guard
        let flattened = context.makeImage(),
        let data = CFDataCreateMutable(nil, 0),
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, flattened, nil)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
}

// MARK: - Walking the tree

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fail("usage: frame-screenshots.swift <captures> <destination> <captions.json>")
}
let captures = URL(fileURLWithPath: arguments[1])
let destination = URL(fileURLWithPath: arguments[2])
let captionsPath = URL(fileURLWithPath: arguments[3])

guard
    let raw = try? Data(contentsOf: captionsPath),
    let parsed = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
else {
    fail("could not read captions from \(captionsPath.path)")
}
/// Every locale's headlines. `compactMapValues` is what drops `_comment` and `_darkFrames`,
/// which are documentation and a list rather than a locale.
let captions = parsed.compactMapValues { $0 as? [String: String] }
/// The shots drawn on the dark ground instead of the paper one.
let darkFrames = Set((parsed["_darkFrames"] as? [String]) ?? [])

let manager = FileManager.default

func directories(in url: URL) -> [URL] {
    ((try? manager.contentsOfDirectory(
        at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
    )) ?? [])
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

/// The PNG files directly inside `url`, sorted by name.
func pngs(in url: URL) -> [URL] {
    ((try? manager.contentsOfDirectory(
        at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    )) ?? [])
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

/// Encodes and writes one framed shot.
func write(_ rep: NSBitmapImageRep, named name: String, to out: URL, locale: String, device: String) {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fail("could not encode \(name) for \(locale) on \(device)")
    }
    let target = out.appendingPathComponent("\(name).png")
    try! png.write(to: target)
    print("  \(target.path)  \(rep.pixelsWide)x\(rep.pixelsHigh)")
}

/// An assembly folder is named like a shot — two digits and a dash — where a device folder is
/// named after a canvas. That is the whole of how the two are told apart.
func isAssembly(_ url: URL) -> Bool {
    url.lastPathComponent.range(of: #"^\d\d-"#, options: .regularExpression) != nil
}

var written = 0
for localeDirectory in directories(in: captures) {
    let locale = localeDirectory.lastPathComponent
    guard let localeCaptions = captions[locale] else {
        fail("captions.json says nothing about \(locale)")
    }

    let entries = directories(in: localeDirectory)
    let deviceDirectories = entries.filter { !isAssembly($0) }
    // Read once per locale: the same tiles go onto every canvas.
    let assemblies: [(name: String, tiles: [String: NSImage])] = entries
        .filter(isAssembly)
        .map { folder in
            var tiles: [String: NSImage] = [:]
            for file in pngs(in: folder) {
                guard let image = NSImage(contentsOf: file) else {
                    fail("could not read \(file.path)")
                }
                tiles[file.deletingPathExtension().lastPathComponent] = image
            }
            return (folder.lastPathComponent, tiles)
        }

    for deviceDirectory in deviceDirectories {
        let device = deviceDirectory.lastPathComponent
        guard let profile = Profile.named(device) else {
            fail("no frame is defined for the \(device) canvas")
        }

        let out = destination.appendingPathComponent(locale).appendingPathComponent(device)
        try? manager.removeItem(at: out)
        try! manager.createDirectory(at: out, withIntermediateDirectories: true)

        for shot in pngs(in: deviceDirectory) {
            let name = shot.deletingPathExtension().lastPathComponent
            // A shot with no headline is a shot nobody wrote copy for, and shipping it untitled
            // beside six that are titled is worse than stopping here.
            guard let caption = localeCaptions[name] else {
                fail("captions.json has no \(locale) headline for \(name)")
            }
            guard let capture = NSImage(contentsOf: shot) else {
                fail("could not read \(shot.path)")
            }
            let rep = frame(
                capture: capture,
                caption: caption,
                profile: profile,
                palette: darkFrames.contains(name) ? .dark : .light
            )
            write(rep, named: name, to: out, locale: locale, device: device)
            written += 1
        }

        for assembly in assemblies {
            guard let caption = localeCaptions[assembly.name] else {
                fail("captions.json has no \(locale) headline for \(assembly.name)")
            }
            let rep = assemble(
                tiles: assembly.tiles,
                caption: caption,
                profile: profile,
                palette: darkFrames.contains(assembly.name) ? .dark : .light
            )
            write(rep, named: assembly.name, to: out, locale: locale, device: device)
            written += 1
        }
    }

    // The creative, once per locale: it belongs to neither device's screenshot set.
    guard let caption = localeCaptions[Creative.caption] else {
        fail("captions.json has no \(locale) headline for \(Creative.caption)")
    }
    let shot = localeDirectory.appendingPathComponent(Creative.device)
        .appendingPathComponent("\(Creative.shot).png")
    guard let capture = NSImage(contentsOf: shot) else {
        fail("the creative is drawn from \(shot.path), which could not be read")
    }
    let rep = creative(capture: capture, caption: caption, palette: .light)
    let out = destination.appendingPathComponent(locale).appendingPathComponent("creative")
    try? manager.removeItem(at: out)
    try! manager.createDirectory(at: out, withIntermediateDirectories: true)
    guard let png = opaquePNG(rep) else {
        fail("could not encode the creative for \(locale)")
    }
    let target = out.appendingPathComponent("\(Creative.name).png")
    try! png.write(to: target)
    print("  \(target.path)  \(rep.pixelsWide)x\(rep.pixelsHigh)")
    written += 1
}

if written == 0 {
    fail("there was nothing to frame in \(captures.path)")
}
