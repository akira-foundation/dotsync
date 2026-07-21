import DotSyncCore
import SwiftUI

@main
struct DotSyncApp: App {
    @StateObject private var model = SyncViewModel()
    @StateObject private var updater = Updater()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
                .environmentObject(updater)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
