import Foundation
import Testing
@testable import Kado

@Suite("SharedStore")
struct SharedStoreTests {
    private func makeSandbox() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SharedStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.data(using: .utf8)!.write(to: url)
    }

    @Test("Migration is a no-op when no legacy store exists")
    func migrationSkippedWhenLegacyMissing() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let legacy = sandbox.appendingPathComponent("legacy/default.store")
        let target = sandbox.appendingPathComponent("group/Library/Application Support/Kado.sqlite")

        SharedStore.migrateLegacyStoreIfNeeded(from: legacy, to: target)

        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test("Migration copies sqlite plus sidecars when legacy exists and target is empty")
    func migrationCopiesAllFiles() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let legacy = sandbox.appendingPathComponent("legacy/default.store")
        let target = sandbox.appendingPathComponent("group/Library/Application Support/Kado.sqlite")

        try write("main", to: legacy)
        try write("shm", to: URL(fileURLWithPath: legacy.path + "-shm"))
        try write("wal", to: URL(fileURLWithPath: legacy.path + "-wal"))

        SharedStore.migrateLegacyStoreIfNeeded(from: legacy, to: target)

        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(FileManager.default.fileExists(atPath: target.path + "-shm"))
        #expect(FileManager.default.fileExists(atPath: target.path + "-wal"))

        let main = try String(contentsOf: target, encoding: .utf8)
        #expect(main == "main", "Main sqlite must be copied byte-for-byte")
    }

    @Test("Legacy store stays in place after migration (copy, not move)")
    func migrationLeavesLegacyUntouched() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let legacy = sandbox.appendingPathComponent("legacy/default.store")
        let target = sandbox.appendingPathComponent("group/Library/Application Support/Kado.sqlite")

        try write("main", to: legacy)

        SharedStore.migrateLegacyStoreIfNeeded(from: legacy, to: target)

        #expect(FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test("Migration is idempotent when target already exists")
    func migrationSkippedWhenTargetPresent() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let legacy = sandbox.appendingPathComponent("legacy/default.store")
        let target = sandbox.appendingPathComponent("group/Library/Application Support/Kado.sqlite")

        try write("legacy-bytes", to: legacy)
        try write("target-bytes", to: target)

        SharedStore.migrateLegacyStoreIfNeeded(from: legacy, to: target)

        let stillThere = try String(contentsOf: target, encoding: .utf8)
        #expect(stillThere == "target-bytes", "Existing target must not be overwritten")
    }

    @Test("Sidecar-less legacy store still migrates the main file")
    func migrationHandlesMissingSidecars() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let legacy = sandbox.appendingPathComponent("legacy/default.store")
        let target = sandbox.appendingPathComponent("group/Library/Application Support/Kado.sqlite")

        try write("main-only", to: legacy)

        SharedStore.migrateLegacyStoreIfNeeded(from: legacy, to: target)

        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(!FileManager.default.fileExists(atPath: target.path + "-shm"))
        #expect(!FileManager.default.fileExists(atPath: target.path + "-wal"))
    }

    @Test("App Group identifier matches the entitlement convention")
    func appGroupIdentifierIsStable() {
        #expect(SharedStore.appGroupID == "group.dev.scastiel.kado")
    }
}
