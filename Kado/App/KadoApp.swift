import SwiftData
import SwiftUI

@main
struct KadoApp: App {
    let container: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: KadoSchemaV1.self)
            return try ModelContainer(
                for: schema,
                migrationPlan: KadoMigrationPlan.self,
                configurations: ModelConfiguration(
                    schema: schema,
                    cloudKitDatabase: .private(CloudContainerID.kado)
                )
            )
        } catch {
            fatalError("Failed to construct ModelContainer: \(error)")
        }
    }()

    @State private var cloudAccountStatus = DefaultCloudAccountStatusObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await cloudAccountStatus.refresh() }
        }
        .modelContainer(container)
        .environment(\.cloudAccountStatus, cloudAccountStatus)
    }
}
