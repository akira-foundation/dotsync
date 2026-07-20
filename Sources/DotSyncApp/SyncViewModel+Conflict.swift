import AppKit
import DotSyncCore

extension SyncViewModel {
    func resolveConflict(_ id: String) {
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else {
            return
        }
        let resolver = ConflictResolver(repo: root.expandedPath)
        guard let backup = resolver.backups().first else {
            syncNow(id)
            return
        }
        let files = resolver.changedFiles(backup: backup)

        let alert = NSAlert()
        alert.messageText = "Resolve conflict"
        let list = files.prefix(10).map { "\u{2022} \($0)" }.joined(separator: "\n")
        alert.informativeText =
            "Remote was kept. Your local changes are saved in \(backup):\n\(list)"
        alert.addButton(withTitle: "Keep Mine")
        alert.addButton(withTitle: "Discard Mine")
        alert.addButton(withTitle: "Reveal in Finder")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            try? resolver.keepMine(backup: backup)
            syncNow(id)
        case .alertSecondButtonReturn:
            try? resolver.discard(backup: backup)
            syncNow(id)
        case .alertThirdButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([root.expandedPath])
        default:
            break
        }
    }
}
