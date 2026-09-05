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
                headlineMargin: 110
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
                headlineMargin: 170
            )
        default:
            return nil
        }
    }
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

func frame(
    capture: NSImage, caption: String, profile: Profile, palette: Palette
) -> NSBitmapImageRep {
    let canvas = profile.canvas
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

    // The headline, stacked downwards from `headlineTop`. The context is unflipped, so a line's
    // drawing origin is its lower-left corner and the arithmetic runs from the top of the canvas.
    let lines = caption.components(separatedBy: "\n")
    // One size for the whole headline, chosen so its longest line clears the margin. Scaling
    // the offending line alone would be the smaller change and would look like a mistake.
    let available = canvas.width - profile.headlineMargin * 2
    let widest = lines
        .map { attributed($0, size: profile.headlineSize, color: palette.headline).size().width }
        .max() ?? 0
    let headlineSize = widest > available
        ? (profile.headlineSize * available / widest).rounded(.down)
        : profile.headlineSize
    // The grid the lines sit on stays at the profile's size even when the glyphs shrink, so the
    // device below starts at the same height in every shot and every language. Sizing the grid
    // to the fitted text instead would lift the phone a few pixels wherever French ran long,
    // and the set is looked at as a strip.
    let lineHeight = profile.headlineSize * 1.16
    for (index, line) in lines.enumerated() {
        let text = attributed(line, size: headlineSize, color: palette.headline)
        let width = text.size().width
        let bottom = canvas.height - profile.headlineTop - lineHeight * CGFloat(index + 1)
        text.draw(at: NSPoint(x: (canvas.width - width) / 2, y: bottom))
    }

    // The device. Its width is fixed by the profile and its height follows the capture's own
    // aspect, so a screenshot is never stretched to fit a frame that disagrees with it.
    let screenWidth = (canvas.width * profile.screenWidthFraction).rounded()
    let screenHeight = (screenWidth * canvas.height / canvas.width).rounded()
    let screenTop = profile.headlineTop + lineHeight * CGFloat(lines.count) + profile.headlineGap
    let screen = NSRect(
        x: ((canvas.width - screenWidth) / 2).rounded(),
        y: canvas.height - screenTop - screenHeight,
        width: screenWidth,
        height: screenHeight
    )
    let body = screen.insetBy(dx: -profile.bezel, dy: -profile.bezel)
    let screenRadius = screenWidth * profile.cornerFraction

    // Shadow on the body only: set on the fill and cleared before the screenshot goes in, or
    // every pixel of the app picks it up as a halo.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -profile.bezel * 2)
    shadow.shadowBlurRadius = profile.bezel * 4
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.set()
    palette.bezel.setFill()
    NSBezierPath(
        roundedRect: body,
        xRadius: screenRadius + profile.bezel,
        yRadius: screenRadius + profile.bezel
    ).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: screenRadius, yRadius: screenRadius).addClip()
    capture.draw(
        in: screen,
        from: NSRect(origin: .zero, size: capture.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
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

var written = 0
for localeDirectory in directories(in: captures) {
    let locale = localeDirectory.lastPathComponent
    guard let localeCaptions = captions[locale] else {
        fail("captions.json says nothing about \(locale)")
    }

    for deviceDirectory in directories(in: localeDirectory) {
        let device = deviceDirectory.lastPathComponent
        guard let profile = Profile.named(device) else {
            fail("no frame is defined for the \(device) canvas")
        }

        let out = destination.appendingPathComponent(locale).appendingPathComponent(device)
        try? manager.removeItem(at: out)
        try! manager.createDirectory(at: out, withIntermediateDirectories: true)

        let shots = ((try? manager.contentsOfDirectory(
            at: deviceDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for shot in shots {
            let name = shot.deletingPathExtension().lastPathComponent
            // A shot with no headline is a shot nobody wrote copy for, and shipping it untitled
            // beside five that are titled is worse than stopping here.
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
            guard let png = rep.representation(using: .png, properties: [:]) else {
                fail("could not encode \(name) for \(locale) on \(device)")
            }
            let target = out.appendingPathComponent(shot.lastPathComponent)
            try! png.write(to: target)
            print("  \(target.path)  \(rep.pixelsWide)x\(rep.pixelsHigh)")
            written += 1
        }
    }
}

if written == 0 {
    fail("there was nothing to frame in \(captures.path)")
}
