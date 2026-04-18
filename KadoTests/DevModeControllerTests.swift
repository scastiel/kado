import Foundation
import SwiftData
import Testing
@testable import Kado

@Suite("DevModeController")
@MainActor
struct DevModeControllerTests {
    private func makeController() throws -> (DevModeController, URL) {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DevModeControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("KadoDev.sqlite")

        let factory: () -> ModelContainer = {
            let schema = Schema(versionedSchema: KadoSchemaV2.self)
            return try! ModelContainer(
                for: schema,
                migrationPlan: KadoMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true
                )
            )
        }

        let controller = DevModeController(
            devStoreURL: storeURL,
            productionContainerFactory: factory
        )
        return (controller, tempDir)
    }

    @Test("activateDevMode seeds at least one habit of each HabitType")
    func activateSeedsAllTypes() throws {
        let (controller, tempDir) = try makeController()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        controller.activateDevMode()
        let container = controller.container(forDevMode: true)
        let habits = try container.mainContext.fetch(FetchDescriptor<HabitRecord>())
        let types = Set(habits.map(\.type))

        #expect(types.contains(.binary))
        #expect(types.contains(.negative))
        #expect(types.contains { if case .counter = $0 { return true } else { return false } })
        #expect(types.contains { if case .timer = $0 { return true } else { return false } })
    }

    @Test("Off then on wipes sandbox edits")
    func offOnWipesEdits() throws {
        let (controller, tempDir) = try makeController()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        controller.activateDevMode()
        let firstContainer = controller.container(forDevMode: true)
        let sentinelName = "Sentinel-\(UUID().uuidString)"
        firstContainer.mainContext.insert(
            HabitRecord(name: sentinelName, frequency: .daily, type: .binary)
        )
        try firstContainer.mainContext.save()

        controller.deactivateDevMode()
        controller.activateDevMode()

        let secondContainer = controller.container(forDevMode: true)
        let habits = try secondContainer.mainContext.fetch(FetchDescriptor<HabitRecord>())
        #expect(!habits.contains(where: { $0.name == sentinelName }))
        #expect(!habits.isEmpty, "Reseed should repopulate the sandbox")
    }

    @Test("Off then on returns a new dev container instance")
    func offOnReturnsNewContainer() throws {
        let (controller, tempDir) = try makeController()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        controller.activateDevMode()
        let before = controller.container(forDevMode: true)
        controller.deactivateDevMode()
        controller.activateDevMode()
        let after = controller.container(forDevMode: true)

        #expect(before !== after, "Container identity must change so .modelContainer(_:) sees a swap")
    }

    @Test("Production container is returned when dev mode is off")
    func productionWhenOff() throws {
        let (controller, tempDir) = try makeController()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let prod = controller.container(forDevMode: false)
        let prodAgain = controller.container(forDevMode: false)
        #expect(prod === prodAgain, "Production container should be cached")
    }
}
