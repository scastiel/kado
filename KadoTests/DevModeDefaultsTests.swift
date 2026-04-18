import Foundation
import Testing
@testable import Kado
import KadoCore

@Suite("DevModeDefaults")
struct DevModeDefaultsTests {
    private func makeSuite() -> (UserDefaults, String) {
        let name = "DevModeDefaultsTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        return (suite, name)
    }

    private func removeSuite(named name: String) {
        UserDefaults().removePersistentDomain(forName: name)
    }

    @Test("migrate copies the toggle and confirmation flags when destination is empty")
    func migrateCopiesBothKeys() {
        let (source, sourceName) = makeSuite()
        let (destination, destinationName) = makeSuite()
        defer {
            removeSuite(named: sourceName)
            removeSuite(named: destinationName)
        }

        source.set(true, forKey: DevModeDefaults.key)
        source.set(true, forKey: DevModeDefaults.hasConfirmedKey)

        DevModeDefaults.migrate(from: source, to: destination)

        #expect(destination.bool(forKey: DevModeDefaults.key) == true)
        #expect(destination.bool(forKey: DevModeDefaults.hasConfirmedKey) == true)
    }

    @Test("migrate does not overwrite an existing destination value")
    func migrateRespectsExistingValue() {
        let (source, sourceName) = makeSuite()
        let (destination, destinationName) = makeSuite()
        defer {
            removeSuite(named: sourceName)
            removeSuite(named: destinationName)
        }

        source.set(true, forKey: DevModeDefaults.key)
        destination.set(false, forKey: DevModeDefaults.key)

        DevModeDefaults.migrate(from: source, to: destination)

        #expect(destination.bool(forKey: DevModeDefaults.key) == false)
    }

    @Test("migrate is a no-op when the source key is unset")
    func migrateSkipsMissingKey() {
        let (source, sourceName) = makeSuite()
        let (destination, destinationName) = makeSuite()
        defer {
            removeSuite(named: sourceName)
            removeSuite(named: destinationName)
        }

        DevModeDefaults.migrate(from: source, to: destination)

        #expect(destination.object(forKey: DevModeDefaults.key) == nil)
        #expect(destination.object(forKey: DevModeDefaults.hasConfirmedKey) == nil)
    }

    @Test("migrate is a no-op when source and destination are the same instance")
    func migrateRefusesIdenticalSuites() {
        let (suite, name) = makeSuite()
        defer { removeSuite(named: name) }

        suite.set(true, forKey: DevModeDefaults.key)

        DevModeDefaults.migrate(from: suite, to: suite)

        // Still true — we didn't blow the value away.
        #expect(suite.bool(forKey: DevModeDefaults.key) == true)
    }
}
