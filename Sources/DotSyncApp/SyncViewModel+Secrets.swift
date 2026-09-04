import AppKit
import DotSyncCore

extension SyncViewModel {
    func presentBlocked(_ report: SecretScanReport, id: String, repoPath: String) {
        let forbidden = Set(report.forbidden)
        let files = Array(Set(report.findings.map(\.file)).union(forbidden)).sorted()
        let canEncrypt =
            settings.encryption.enabled && AgeCrypto.available
            && settings.encryption.recipient != nil

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Blocked: secrets detected"
        let forbiddenLines = report.forbidden.map { "\u{2022} \($0) (must not be tracked)" }
        let findingLines = report.findings.map { "\u{2022} \($0.file): \($0.rule)" }
        alert.informativeText = (forbiddenLines + findingLines).joined(separator: "\n")
        alert.addButton(withTitle: "OK")

        var actions: [() -> Void] = []
        if !files.isEmpty {
            alert.addButton(withTitle: files.count > 1 ? "Ignore Files" : "Ignore File")
            actions.append { [self] in
                resolveBlocked(
                    .ignore, files: files, forbidden: forbidden, id: id, repoPath: repoPath)
            }
            if canEncrypt {
                alert.addButton(withTitle: "Sync Encrypted")
                actions.append { [self] in
                    resolveBlocked(
                        .syncEncrypted, files: files, forbidden: forbidden, id: id,
                        repoPath: repoPath)
                }
            }
            alert.addButton(withTitle: "Reveal in Finder")
            actions.append { [self] in reveal(files, repoPath: repoPath) }
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = PopoverGuard.duringModal { alert.runModal() }
        let index =
            response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue - 1
        guard index >= 0, index < actions.count else { return }
        actions[index]()
    }

    private func resolveBlocked(
        _ action: BlockedFileAction, files: [String], forbidden: Set<String>, id: String,
        repoPath: String
    ) {
        let git = Git(repo: URL(fileURLWithPath: repoPath))
        let applied = BlockedFileResolver.apply(
            action, files: files, forbidden: forbidden, git: git, guards: &settings.guards)
        guard applied else { return }
        saveSettings()
        blocked.remove(id)
        syncNow(id)
    }

    private func reveal(_ files: [String], repoPath: String) {
        let root = URL(fileURLWithPath: repoPath)
        let target =
            files
            .map { root.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        guard let target else {
            NSWorkspace.shared.open(root)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
}
