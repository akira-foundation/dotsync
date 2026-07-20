import AppKit
import Foundation
import ServiceManagement
import DotSyncCore

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var rows: [RootStatus] = []
    @Published var busy: Set<String> = []
    @Published var settings = Settings()
    @Published var ghAccounts: [GhAccount] = []

    private let configURL: URL
    private let binDir: URL
    private let settingsURL: URL
    private var autoSyncTimer: Timer?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let env = ProcessInfo.processInfo.environment
        configURL = env["DOTSYNC_CONFIG"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/config.json")
        binDir = env["DOTSYNC_BIN"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/bin")
        settingsURL = env["DOTSYNC_SETTINGS"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/settings.json")
        settings = (try? Settings.load(settingsURL)) ?? Settings()
        discover()
        applyAutoSync()
    }

    func saveSettings() {
        try? settings.save(to: settingsURL)
    }

    func applyAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
        guard settings.autosync.enabled else { return }
        let interval = TimeInterval(max(30, settings.autosync.intervalSec))
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.autoTick() }
        }
    }

    private func autoTick() {
        refresh()
        for row in rows where row.setup == .ready && !busy.contains(row.id) {
            syncNow(row.id)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        saveSettings()
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            settings.launchAtLogin = SMAppService.mainApp.status == .enabled
            saveSettings()
        }
    }

    func loadAccounts() {
        Task.detached {
            let accounts = (try? GhBridge().accounts()) ?? []
            await MainActor.run { self.ghAccounts = accounts }
        }
    }

    var menuBarSymbol: String {
        if rows.contains(where: { $0.conflict }) { return "exclamationmark.arrow.triangle.2.circlepath" }
        return "arrow.triangle.2.circlepath"
    }

    func refresh() {
        guard let config = try? Config.load(configURL) else {
            rows = []
            return
        }
        rows = Status.readAll(config: config)
    }

    func syncNow(_ id: String) {
        guard !busy.contains(id) else { return }
        busy.insert(id)
        let cfgURL = configURL
        let bin = binDir
        Task.detached {
            let engine = SyncEngine(
                binDir: bin,
                now: { ISO8601DateFormatter().string(from: Date()) },
                host: { ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init) ?? "pc" }
            )
            if let config = try? Config.load(cfgURL), let root = config.root(id: id) {
                _ = try? engine.sync(root: root, config: config)
            }
            await MainActor.run {
                self.busy.remove(id)
                self.refresh()
            }
        }
    }

    func syncAll() {
        for row in rows where row.setup == .ready { syncNow(row.id) }
    }

    func discover() {
        guard settings.discovery.enabled, settings.discovery.autoAdd else { return }
        var config = (try? Config.load(configURL))
            ?? Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])
        var changed = false
        for raw in settings.discovery.paths {
            let expanded = (raw as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expanded) else { continue }
            guard !config.roots.contains(where: { $0.expandedPath.path == expanded }) else { continue }
            var name = (expanded as NSString).lastPathComponent
            if name.hasPrefix(".") { name.removeFirst() }
            let git = Git(repo: URL(fileURLWithPath: expanded))
            config.roots.append(Root(
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

    func onboard(_ id: String) {
        guard !busy.contains(id) else { return }
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else { return }
        busy.insert(id)
        let branch = config.branch(for: root)
        let currentSettings = settings
        Task.detached {
            let onboarder = Onboarder(
                settings: currentSettings,
                gh: GhBridge(host: currentSettings.github.host),
                confirm: { step in SyncViewModel.confirm(step) }
            )
            let outcome = onboarder.run(root: root, branch: branch)
            await MainActor.run {
                self.busy.remove(id)
                SyncViewModel.present(outcome)
                self.refresh()
            }
        }
    }

    nonisolated static func confirm(_ step: OnboardStep) -> Bool {
        DispatchQueue.main.sync {
            let alert = NSAlert()
            switch step {
            case .initGit:
                alert.messageText = "Initialize git repository?"
                alert.informativeText = "dotsync will run git init and write a secret-safe .gitignore before adding any files."
            case let .createRemote(owner, name):
                alert.messageText = "Create private GitHub repo?"
                alert.informativeText = "Create \(owner)/\(name) (private) on GitHub."
            case .commitAndPush:
                alert.messageText = "Commit and push?"
                alert.informativeText = "Commit the allowlisted files and push to origin."
            }
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            return alert.runModal() == .alertFirstButtonReturn
        }
    }

    @MainActor static func present(_ outcome: OnboardOutcome) {
        let alert = NSAlert()
        switch outcome {
        case .done:
            alert.messageText = "Folder synced"
            alert.informativeText = "Repository created and pushed."
        case .cancelled:
            return
        case let .blocked(report):
            alert.alertStyle = .critical
            alert.messageText = "Blocked: secrets detected"
            let forbidden = report.forbidden.map { "• \($0) (must not be tracked)" }
            let findings = report.findings.map { "• \($0.file): \($0.rule)" }
            alert.informativeText = (forbidden + findings).joined(separator: "\n")
        case .needsAccount:
            alert.messageText = "Pick a GitHub account"
            alert.informativeText = "Open Settings and choose a GitHub account first."
        case let .failed(reason):
            alert.alertStyle = .warning
            alert.messageText = "Onboarding failed"
            alert.informativeText = reason
        }
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func addFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose a git folder to sync"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addRoot(at: url)
    }

    private func addRoot(at url: URL) {
        var config = (try? Config.load(configURL))
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
