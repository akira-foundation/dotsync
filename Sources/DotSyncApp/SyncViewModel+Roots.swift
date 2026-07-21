import AppKit
import DotSyncCore
import Foundation

extension SyncViewModel {
    func removeRoot(_ id: String) {
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Remove \(id)?"
        alert.informativeText =
            "dotsync stops syncing this folder. The folder and its git repo stay on disk."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard PopoverGuard.duringModal({ alert.runModal() }) == .alertFirstButtonReturn else {
            return
        }

        if !settings.discovery.ignored.contains(root.expandedPath.path) {
            settings.discovery.ignored.append(root.expandedPath.path)
            saveSettings()
        }
        try? config.removingRoot(id: id).save(to: configURL)
        blocked.remove(id)
        refresh()
        applyWatch()
    }

    func toggleAuto(_ id: String) {
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else {
            return
        }
        try? config.settingAuto(id: id, !(root.auto ?? true)).save(to: configURL)
        refresh()
    }

    func discover() {
        guard settings.discovery.enabled, settings.discovery.autoAdd else { return }
        var config =
            (try? Config.load(configURL))
            ?? Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])
        var changed = false
        let ignored = Set(settings.discovery.ignored)
        for raw in Discovery.candidatePaths(settings.discovery.paths) {
            let expanded = (raw as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            guard !ignored.contains(expanded) else { continue }
            guard !config.roots.contains(where: { $0.expandedPath.path == expanded }) else {
                continue
            }
            var name = (expanded as NSString).lastPathComponent
            if name.hasPrefix(".") { name.removeFirst() }
            let git = Git(repo: URL(fileURLWithPath: expanded))
            config.roots.append(
                Root(
                    id: uniqueID(from: name, in: config),
                    path: expanded,
                    remote: git.remoteURL("origin") != nil ? "origin" : nil,
                    branch: try? git.currentBranch(),
                    trigger: .scheduler, auto: true, intervalSec: nil, watch: nil
                ))
            changed = true
        }
        if changed { try? config.save(to: configURL) }
        refresh()
    }

    func addFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a git folder to sync"
        guard PopoverGuard.duringModal({ panel.runModal() }) == .OK, let url = panel.url else {
            return
        }
        addRoot(at: url)
    }

    private func addRoot(at url: URL) {
        var config =
            (try? Config.load(configURL))
            ?? Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])
        guard !config.roots.contains(where: { $0.expandedPath.path == url.path }) else {
            refresh()
            return
        }
        let git = Git(repo: url)
        let branch = try? git.currentBranch()
        let hasRemote = git.remoteURL("origin") != nil
        let root = Root(
            id: uniqueID(from: url.lastPathComponent, in: config),
            path: url.path,
            remote: hasRemote ? "origin" : nil,
            branch: branch,
            trigger: .scheduler,
            auto: true,
            intervalSec: nil,
            watch: nil
        )
        config.roots.append(root)
        try? config.save(to: configURL)
        refresh()
    }

    private func uniqueID(from name: String, in config: Config) -> String {
        let base = name.isEmpty ? "root" : name
        guard config.root(id: base) != nil else { return base }
        var index = 2
        while config.root(id: "\(base)-\(index)") != nil { index += 1 }
        return "\(base)-\(index)"
    }
}
