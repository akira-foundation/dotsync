import AppKit
import DotSyncCore

extension SyncViewModel {
    func presentBlocked(_ report: SecretScanReport, id: String, repoPath: String) {
        let files = Array(Set(report.findings.map(\.file))).sorted()

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Blocked: secrets detected"
        let forbidden = report.forbidden.map { "\u{2022} \($0) (must not be tracked)" }
        let findings = report.findings.map { "\u{2022} \($0.file): \($0.rule)" }
        alert.informativeText = (forbidden + findings).joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        if !files.isEmpty {
            alert.addButton(withTitle: files.count > 1 ? "Ignore Files" : "Ignore File")
            alert.addButton(withTitle: "Reveal in Finder")
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if !files.isEmpty, response == .alertSecondButtonReturn {
            settings.guards.allowlistPaths = Array(Set(settings.guards.allowlistPaths + files))
                .sorted()
            saveSettings()
            blocked.remove(id)
            syncNow(id)
        } else if !files.isEmpty, response == .alertThirdButtonReturn, let first = files.first {
            let url = URL(fileURLWithPath: repoPath).appendingPathComponent(first)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}
