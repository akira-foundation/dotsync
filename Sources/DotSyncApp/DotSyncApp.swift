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
    private var logWindow: NSWindow?
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

        PopoverGuard.onSuspend = { [weak self] in self?.popover.behavior = .applicationDefined }
        PopoverGuard.onResume = { [weak self] in self?.popover.behavior = .transient }
        LogWindow.open = { [weak self] in self?.showLogWindow() }

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

    private func showLogWindow() {
        if logWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.title = "dotsync logs"
            window.contentViewController = NSHostingController(rootView: LogViewerView())
            window.isReleasedWhenClosed = false
            window.center()
            logWindow = window
        }
        popover.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        logWindow?.makeKeyAndOrderFront(nil)
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
