import SwiftUI

@main
struct MountGuardApp: App {
    @StateObject private var model = DiskDashboardModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: model)
                .task {
                    model.startIfNeeded()
                }
        }
        .defaultSize(width: 1120, height: 760)

        MenuBarExtra {
            MenuBarContentView(model: model)
                .task {
                    model.startIfNeeded()
                }
        } label: {
            Label("MountGuard", systemImage: model.menuBarSymbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
