import SwiftData
import SwiftUI

@main
struct KadoApp: App {
    @AppStorage("kado.devMode") private var isDevMode = false

    @State private var devModeController = DevModeController()
    @State private var cloudAccountStatus = DefaultCloudAccountStatusObserver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await cloudAccountStatus.refresh() }
        }
        .modelContainer(devModeController.container(forDevMode: isDevMode))
        .environment(\.cloudAccountStatus, cloudAccountStatus)
        .onChange(of: isDevMode) { oldValue, newValue in
            if newValue && !oldValue {
                devModeController.activateDevMode()
            } else if !newValue && oldValue {
                devModeController.deactivateDevMode()
            }
        }
    }
}
