import AppKit
import DotSyncCore
import Foundation
import ServiceManagement

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var rows: [RootStatus] = []
    @Published var busy: Set<String> = []
    @Published var blocked: Set<String> = []
    @Published var installingAge = false
    @Published var settings = Settings()
    @Published var ghAccounts: [GhAccount] = []
    @Published var expandedID: String?
    @Published var detail: RootDetail?

    let configURL: URL
    private let binDir: URL
    private let settingsURL: URL
    private var autoSyncTimer: Timer?
    private var watchCooldownUntil = Date(timeIntervalSince1970: 0)
    private lazy var watcher = FileWatcher { [weak self] paths in
        Task { @MainActor in self?.handleWatchEvents(paths) }
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let env = ProcessInfo.processInfo.environment
        configURL =
            env["DOTSYNC_CONFIG"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/config.json")
        binDir =
            env["DOTSYNC_BIN"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/bin")
        settingsURL =
            env["DOTSYNC_SETTINGS"].map(URL.init(fileURLWithPath:))
            ?? home.appendingPathComponent(".dotsync/settings.json")
        settings = (try? Settings.load(settingsURL)) ?? Settings()
        Notifier.requestAuthorization()
        discover()
        applyAutoSync()
        applyWatch()
    }

    func saveSettings() {
        try? settings.save(to: settingsURL)
    }

    func applyAutoSync() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
        guard settings.autosync.enabled else { return }
        let interval = TimeInterval(max(30, settings.autosync.intervalSec))
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.autoTick() }
        }
    }

    private func autoTick() {
        refresh()
        for row in rows where row.setup == .ready && row.auto && !busy.contains(row.id) {
            syncNow(row.id, announce: false)
        }
    }

    func applyWatch() {
        guard settings.autosync.enabled, settings.autosync.watch else {
            watcher.stop()
            return
        }
        watcher.start(paths: rows.filter { $0.setup == .ready }.map(\.path))
    }

    private func handleWatchEvents(_ paths: Set<String>) {
        guard busy.isEmpty, Date() >= watchCooldownUntil else { return }
        let relevant = paths.filter { path in
            !path.contains("/.git/") && !path.contains("/.dotsync-age/") && !path.hasSuffix(".age")
        }
        guard !relevant.isEmpty else { return }

        var triggered = false
        for row in rows where row.setup == .ready && row.auto && !busy.contains(row.id) {
            guard relevant.contains(where: { $0.hasPrefix(row.path) }) else { continue }
            let pending = (try? Git(repo: URL(fileURLWithPath: row.path)).pending()) ?? []
            guard !pending.isEmpty else {
                Log.watch.debug("\(row.id, privacy: .public): change seen, nothing tracked")
                continue
            }
            Log.watch.debug("\(row.id, privacy: .public): \(pending.count) tracked, syncing")
            syncNow(row.id, announce: false)
            triggered = true
        }
        if triggered { watchCooldownUntil = Date().addingTimeInterval(3) }
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
        if !blocked.isEmpty || rows.contains(where: { $0.conflict }) {
            return "exclamationmark.arrow.triangle.2.circlepath"
        }
        if rows.contains(where: { $0.setup != .ready }) {
            return "arrow.triangle.2.circlepath.circle"
        }
        return "arrow.triangle.2.circlepath"
    }

    func toggleDetail(_ id: String) {
        guard expandedID != id else {
            expandedID = nil
            detail = nil
            return
        }
        guard let row = rows.first(where: { $0.id == id }) else { return }
        let repo = URL(fileURLWithPath: row.path)
        detail = RootDetail(
            pending: Git(repo: repo).pendingPaths(),
            history: History.recent(repo: repo, limit: 5))
        expandedID = id
    }

    func refresh() {
        guard let config = try? Config.load(configURL) else {
            rows = []
            return
        }
        rows = Status.readAll(config: config)
    }

    func syncNow(_ id: String, announce: Bool = true) {
        guard !busy.contains(id) else { return }
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else {
            return
        }
        busy.insert(id)
        let cfgURL = configURL
        let bin = binDir
        let guards = settings.guards
        let ignore = Set(settings.guards.allowlistPaths)
        let encryption = settings.encryption
        let host = machineHost
        Task.detached {
            if guards.secretScan {
                let report = SecretScanner.scanRepo(root.expandedPath, ignore: ignore)
                if guards.blockOnTrackedSecrets, !report.isClean {
                    await MainActor.run {
                        self.busy.remove(id)
                        self.blocked.insert(id)
                        if announce {
                            self.presentBlocked(
                                report, id: id, repoPath: root.expandedPath.path)
                        } else {
                            Notifier.post(
                                title: "dotsync blocked",
                                body: "\(id): secrets detected, sync paused.")
                        }
                        self.refresh()
                    }
                    return
                }
            }
            let engine = SyncEngine(
                binDir: bin,
                now: { ISO8601DateFormatter().string(from: Date()) },
                host: {
                    ProcessInfo.processInfo.hostName.split(separator: ".").first.map(String.init)
                        ?? "pc"
                }
            )
            SyncViewModel.encryptBeforeSync(
                repo: root.expandedPath, encryption: encryption, host: host,
                forcePaths: Set(guards.forceEncryptPaths))
            var result: SyncResult?
            if let config = try? Config.load(cfgURL), let root = config.root(id: id) {
                result = try? engine.sync(root: root, config: config)
            }
            SyncViewModel.decryptAfterSync(repo: root.expandedPath, encryption: encryption)
            await MainActor.run {
                self.busy.remove(id)
                self.blocked.remove(id)
                SyncViewModel.notifyOutcome(result, id: id)
                self.refresh()
            }
        }
    }

    static func notifyOutcome(_ result: SyncResult?, id: String) {
        guard let result else { return }
        if result.conflict {
            Notifier.post(
                title: "dotsync conflict",
                body: "\(id): remote kept, your changes saved. Open to resolve.")
            return
        }
        guard !result.pushed, result.message == "push-failed" else { return }
        Notifier.post(title: "dotsync sync failed", body: "\(id): push failed.")
    }

    func syncAll() {
        for row in rows where row.setup == .ready && row.auto { syncNow(row.id) }
    }
}
