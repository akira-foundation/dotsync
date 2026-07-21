import AppKit
import Combine
import SwiftUI

@main
struct DotSyncMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = SyncViewModel()
    private let updater = Updater()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingController(
            rootView: MenuContent(model: model).environmentObject(updater))
        hosting.sizingOptions = [.preferredContentSize]
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = hosting

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item
        updateIcon()

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        let image = NSImage(
            systemSymbolName: model.menuBarSymbol, accessibilityDescription: "dotsync")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
