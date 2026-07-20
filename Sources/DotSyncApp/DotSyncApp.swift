import SwiftUI
import DotSyncCore

@main
struct DotSyncApp: App {
    @StateObject private var model = SyncViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
