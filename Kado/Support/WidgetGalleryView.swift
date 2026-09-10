#if DEBUG
import SwiftData
import SwiftUI
import WidgetKit
import KadoCore

/// Every widget at its Home Screen / Lock Screen size, on the screenshot
/// seed, for the App Store listing's widget shot.
///
/// The listing does not photograph a Home Screen — a real one carries a
/// wallpaper, other apps' icons and a dock, none of them Kadō's, and
/// XCUITest adding widgets through jiggle mode is the most fragile thing
/// the suite could do. Instead `ScreenshotTests.testCaptureWidgetTiles`
/// launches the app with `-uiTestWidgetGallery`, which puts this screen
/// at the root, and photographs each tile by element.
/// `Scripts/frame-screenshots.swift` then arranges the tiles on the
/// paper ground under the headline, the way it frames the other shots.
///
/// So this view has one job: draw each widget the way WidgetKit would,
/// and nothing else. The tiles only have to *fit* the screen; where they
/// sit relative to one another is decided in the frame, where a layout
/// change costs seconds rather than a simulator run per language per
/// device.
///
/// What WidgetKit supplies and this view has to supply itself: the
/// container background (the `Widget` applies it, not the content view),
/// the rounded container shape, and the content margins. The Lock Screen
/// widgets get the `.vibrant` rendering mode they have on a real Lock
/// Screen, and a dark tile under them, so they read as monochrome glyphs
/// on a wallpaper rather than as full-colour views on paper.
struct WidgetGalleryView: View {
    @Environment(\.modelContext) private var modelContext

    /// Built once the seed is in, from the same context the app would
    /// build its App Group snapshot from.
    @State private var state: GalleryState = .loading

    private enum GalleryState {
        case loading
        case loaded(WidgetSnapshot)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
            case .loaded(let snapshot):
                tiles(for: snapshot)
            }
        }
        // Inside the safe area, deliberately: the simulator paints the
        // Dynamic Island over whatever sits under it, and a tile that
        // starts at the top edge is photographed with a black pill in
        // its corner. Only the paper runs edge to edge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.kadoBackground.ignoresSafeArea())
        .statusBarHidden()
        .task {
            // Idempotent: the app's own launch task seeds too, and
            // whichever runs first wins. Calling it here rather than
            // racing it is what guarantees the snapshot is built from a
            // seeded store and not an empty one.
            UITestSupport.seedProductionIfRequested(using: modelContext.container)
            let day = DayStartDefaults.boundary().startOfDay(for: .now)
            state = .loaded(
                WidgetSnapshotBuilder.build(
                    from: modelContext, asOf: day, calendar: WeekStartDefaults.calendar()
                )
            )
        }
    }

    /// Three rows, 364pt wide like the medium tile: medium; small beside
    /// the lock card; large. 806pt tall, which clears the 6.9" screen's
    /// safe area with room to spare.
    private func tiles(for snapshot: WidgetSnapshot) -> some View {
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)
        return VStack(spacing: WidgetTileMetrics.gap) {
            WidgetTile(size: .medium, identifier: AccessibilityID.Screenshot.widgetMedium) {
                TodayProgressMediumView(entry: entry)
            }
            HStack(alignment: .top, spacing: WidgetTileMetrics.gap) {
                WidgetTile(size: .small, identifier: AccessibilityID.Screenshot.widgetSmall) {
                    TodayGridSmallView(entry: entry)
                }
                LockCard(entry: entry)
            }
            WidgetTile(size: .large, identifier: AccessibilityID.Screenshot.widgetLarge) {
                WeeklyGridLargeView(entry: entry)
            }
        }
        .padding(.top, WidgetTileMetrics.gap)
    }
}

// MARK: - Metrics

/// The numbers the tiles are drawn with. `Scripts/frame-screenshots.swift`
/// lays the captured tiles out with the same sizes and clips them with
/// the same corner — change one, change both.
enum WidgetTileMetrics {
    /// Apple's point sizes for the 6.9" class (`iPhone 17 Pro Max`),
    /// which is the device the listing's captures come from. The iPad
    /// canvas uses the same tiles scaled by the frame's profile rather
    /// than iPad-native sizes — it is a marketing image, not a ruler.
    enum Size {
        case small, medium, large
        /// Not a WidgetKit size: the Lock Screen widgets on one tile,
        /// as tall as it needs to be and as wide as the medium tile
        /// leaves beside the small one, so the rows line up.
        case lockCard

        var points: CGSize {
            switch self {
            case .small: CGSize(width: 170, height: 170)
            case .medium: CGSize(width: 364, height: 170)
            case .large: CGSize(width: 364, height: 382)
            case .lockCard: CGSize(width: 186, height: 230)
            }
        }
    }

    /// The Home Screen's container corner on iPhone. Off by a few points
    /// it reads as drawn rather than photographed, like the bezel note
    /// in the frame script says.
    static let cornerRadius: CGFloat = 22
    /// What WidgetKit pads content by inside the container.
    static let contentMargin: CGFloat = 16
    /// Between tiles. Wide enough that a tile's screenshot never catches
    /// its neighbour, and no wider than it has to be.
    static let gap: CGFloat = 8
}

// MARK: - Home Screen tiles

/// One Home Screen widget as the Home Screen draws it: the content on
/// its container background, inside the container shape, behind the
/// content margins.
private struct WidgetTile<Content: View>: View {
    let size: WidgetTileMetrics.Size
    let identifier: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(WidgetTileMetrics.contentMargin)
            .frame(width: size.points.width, height: size.points.height)
            .background(Color.kadoBackgroundSecondary)
            .clipShape(
                RoundedRectangle(cornerRadius: WidgetTileMetrics.cornerRadius, style: .continuous)
            )
            // A container, not a leaf: the cells inside keep their own
            // labels, and the identifier lands on the tile itself, which
            // is what the screenshot run crops to.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

// MARK: - The Lock Screen card

/// The four Lock Screen widgets on one dark tile, rendered `.vibrant`
/// the way the Lock Screen renders them.
///
/// Top to bottom, the order they take on a real Lock Screen: the inline
/// summary that sits above the clock, then the row under it — the
/// day's ring and one habit's ring — and one habit's rectangular card.
/// The accessory sizes are Apple's for the 6.9" class.
private struct LockCard: View {
    let entry: SnapshotEntry

    private static let circular = CGSize(width: 76, height: 76)
    private static let rectangular = CGSize(width: 172, height: 76)

    var body: some View {
        VStack(spacing: 12) {
            // Footnote, which is about what the Lock Screen sets the
            // inline line in, and a little give for French: "4 sur 6
            // faites aujourd'hui" is the widest thing on the card.
            LockInlineView(entry: entry)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
            HStack(spacing: 12) {
                LockDayProgressView(entry: entry)
                    .frame(width: Self.circular.width, height: Self.circular.height)
                LockCircularView(entry: picked)
                    .frame(width: Self.circular.width, height: Self.circular.height)
            }
            LockRectangularView(entry: picked)
                .frame(width: Self.rectangular.width, height: Self.rectangular.height)
        }
        // Dark, so the tokens resolve to their night values and
        // `.primary` is white — the same reading the widgets get on a
        // Lock Screen, without inventing a palette for one tile.
        .environment(\.colorScheme, .dark)
        .environment(\.widgetRenderingMode, .vibrant)
        .frame(
            width: WidgetTileMetrics.Size.lockCard.points.width,
            height: WidgetTileMetrics.Size.lockCard.points.height
        )
        .background {
            LinearGradient(
                colors: [Color.kadoSage100, Color.kadoPaper50],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .environment(\.colorScheme, .dark)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: WidgetTileMetrics.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Screenshot.lockCard)
    }

    /// The habit the two picked widgets show: the first completed one
    /// whose name fits the rectangular card, so the ring is closed and
    /// nothing is truncated. The seed's hero ("Morning meditation",
    /// "Méditation du matin") is what a real Lock Screen would cut to
    /// "Morning medi…" at 172pt — honest, and the wrong thing to lead a
    /// listing image with. "Running" / "Course à pied" is what this
    /// picks on the screenshot seed, in both languages.
    private var picked: PickedSnapshotEntry {
        let rows = entry.snapshot.today
        let fits = rows.first { $0.status == .complete && $0.habit.name.count <= Self.fittingNameLength }
        return PickedSnapshotEntry(
            date: entry.date,
            snapshot: entry.snapshot,
            habitID: (fits ?? rows.first)?.habit.id
        )
    }

    /// About what `.headline` fits beside the icon on a 172pt card.
    private static let fittingNameLength = 14
}

// MARK: - Previews

#Preview("Gallery") {
    WidgetGalleryPreview()
}

#Preview("Dark") {
    WidgetGalleryPreview()
        .preferredColorScheme(.dark)
}

/// The gallery on `DevModeSeed`, which needs a container the preview
/// can seed. Not the screenshot seed: a preview only needs *some*
/// habits on the tiles.
private struct WidgetGalleryPreview: View {
    var body: some View {
        WidgetGalleryView()
            .modelContainer(previewContainer)
    }

    private var previewContainer: ModelContainer {
        let schema = Schema(versionedSchema: KadoSchemaV4.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: configuration)
        DevModeSeed.seed(into: container.mainContext)
        return container
    }
}
#endif
