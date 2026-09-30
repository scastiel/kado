import Foundation
import Testing
import UIKit
import KadoCore
@testable import Kado

/// The alternate app icons (#114): which ones the Supporter pack gates,
/// the names the system is handed, and the artwork the build has to
/// carry for each. The system switch itself is exercised by hand and in
/// `AppIconPickerTests`; here it is a `MockAppIconSwitcher`.
@Suite("App icon")
@MainActor
struct AppIconTests {
    // MARK: - Supporter pack

    @Test("Kadō's own icon is free; every alternate needs the pack")
    func onlyTheDefaultIsFree() {
        for icon in AppIcon.allCases {
            #expect(icon.requiresSupporterPack == (icon != .kado), "\(icon)")
        }
        #expect(!AppIcon.freeFallback.requiresSupporterPack)
    }

    @Test("A paid pick shows the default without the pack, and itself with it")
    func effectiveIsGated() {
        for icon in AppIcon.allCases {
            #expect(AppIcon.effective(preferred: icon, isSupporter: true) == icon)
            #expect(AppIcon.effective(preferred: icon, isSupporter: false) == .kado)
        }
    }

    // MARK: - System names

    @Test("Only the default is the primary icon")
    func primaryIsNil() {
        #expect(AppIcon.kado.alternateIconName == nil)
        for icon in AppIcon.allCases where icon != .kado {
            #expect(icon.alternateIconName != nil, "\(icon)")
        }
    }

    @Test("Every icon round-trips through the name the system reports")
    func namesRoundTrip() {
        for icon in AppIcon.allCases {
            #expect(AppIcon(alternateIconName: icon.alternateIconName) == icon)
        }
    }

    /// A downgrade from a build with more icons leaves the system on a
    /// name this build doesn't know.
    @Test("An unknown name reads as the default")
    func unknownNameIsDefault() {
        #expect(AppIcon(alternateIconName: "AppIconFromTheFuture") == .kado)
    }

    /// `setAlternateIconName(_:)` only accepts names the bundle declares
    /// under `CFBundleAlternateIcons`, which the asset catalog compiler
    /// writes from `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`. An
    /// icon added to the enum but not to that build setting compiles,
    /// shows in the picker, and fails only when tapped.
    ///
    /// Read from the raw `Info.plist` rather than `infoDictionary`, which
    /// resolves device-suffixed keys for the device it runs on: on an
    /// iPhone, `CFBundleIcons~ipad` isn't in it at all.
    @Test("The app bundle declares exactly the alternates the enum names", arguments: ["CFBundleIcons", "CFBundleIcons~ipad"])
    func bundleDeclaresEveryAlternate(iconsKey: String) throws {
        let url = try #require(Bundle.main.url(forResource: "Info", withExtension: "plist"))
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        let icons = try #require(plist[iconsKey] as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])
        let expected = Set(AppIcon.allCases.compactMap(\.alternateIconName))
        #expect(Set(alternates.keys) == expected)
    }

    @Test("Every icon has a preview for the picker")
    func everyIconHasAPreview() {
        for icon in AppIcon.allCases {
            #expect(UIImage(named: icon.previewImageName, in: .main, with: nil) != nil, "\(icon)")
        }
    }

    // MARK: - Stored pick

    private func makeSuite() -> (UserDefaults, String) {
        let name = "app-icon-tests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test("An unset pick, or one from a later build, reads as the default")
    func storedPickFallsBack() {
        let (suite, name) = makeSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }

        #expect(AppIconDefaults.icon(in: suite) == .kado)
        suite.set("fromTheFuture", forKey: AppIconDefaults.key)
        #expect(AppIconDefaults.icon(in: suite) == .kado)
    }

    @Test("Every pick round-trips")
    func storedPickRoundTrips() {
        let (suite, name) = makeSuite()
        defer { UserDefaults().removePersistentDomain(forName: name) }

        for icon in AppIcon.allCases {
            AppIconDefaults.setIcon(icon, in: suite)
            #expect(AppIconDefaults.icon(in: suite) == icon)
        }
    }

    // MARK: - Applying

    @Test("A supporter's pick reaches the Home Screen")
    func pickIsApplied() async throws {
        let switcher = MockAppIconSwitcher()
        let changed = try await AppIconApplier(switcher: switcher).apply(preferred: .umi, isSupporter: true)
        #expect(changed)
        #expect(switcher.requests == ["AppIconUmi"])
        #expect(switcher.alternateIconName == "AppIconUmi")
    }

    /// Every call raises the system's alert, so a foreground that finds
    /// the icon already right must leave the system alone.
    @Test("Nothing is asked when the icon already matches")
    func matchingIconIsLeftAlone() async throws {
        let onUmi = MockAppIconSwitcher(alternateIconName: "AppIconUmi")
        let onDefault = MockAppIconSwitcher()

        #expect(try await !AppIconApplier(switcher: onUmi).apply(preferred: .umi, isSupporter: true))
        #expect(try await !AppIconApplier(switcher: onDefault).apply(preferred: .kado, isSupporter: false))
        #expect(onUmi.requests.isEmpty)
        #expect(onDefault.requests.isEmpty)
    }

    @Test("A refund puts the default icon back")
    func revokeResetsToDefault() async throws {
        let switcher = MockAppIconSwitcher(alternateIconName: "AppIconFuji")
        try await AppIconApplier(switcher: switcher).apply(preferred: .fuji, isSupporter: false)
        #expect(switcher.requests == [nil])
        #expect(switcher.alternateIconName == nil)
    }

    /// The pick outlives the refund, so a restore needs nothing but
    /// another reconcile.
    @Test("A restore brings the pick back")
    func restoreBringsPickBack() async throws {
        let switcher = MockAppIconSwitcher()
        let applier = AppIconApplier(switcher: switcher)
        try await applier.apply(preferred: .sakura, isSupporter: false)
        #expect(switcher.requests.isEmpty)

        try await applier.apply(preferred: .sakura, isSupporter: true)
        #expect(switcher.requests == ["AppIconSakura"])
    }

    @Test("A device that can't change icons is never asked")
    func unsupportedIsNeverAsked() async throws {
        let switcher = MockAppIconSwitcher(supportsAlternateIcons: false)
        #expect(try await !AppIconApplier(switcher: switcher).apply(preferred: .ura, isSupporter: true))
        #expect(switcher.requests.isEmpty)
    }

    @Test("The system's refusal reaches the caller")
    func failureIsThrown() async {
        struct Refused: Error {}
        let switcher = MockAppIconSwitcher()
        switcher.failure = Refused()
        await #expect(throws: Refused.self) {
            try await AppIconApplier(switcher: switcher).apply(preferred: .hotaru, isSupporter: true)
        }
        #expect(switcher.alternateIconName == nil)
    }
}
