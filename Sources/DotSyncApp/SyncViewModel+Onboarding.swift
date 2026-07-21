import AppKit
import DotSyncCore

extension SyncViewModel {
    func onboard(_ id: String) {
        guard !busy.contains(id) else { return }
        guard let config = try? Config.load(configURL), let root = config.root(id: id) else {
            return
        }
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
                alert.informativeText =
                    "dotsync will run git init and write a secret-safe .gitignore before adding any files."
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
            return MainActor.assumeIsolated {
                PopoverGuard.duringModal { alert.runModal() } == .alertFirstButtonReturn
            }
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
            let forbidden = report.forbidden.map { "\u{2022} \($0) (must not be tracked)" }
            let findings = report.findings.map { "\u{2022} \($0.file): \($0.rule)" }
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
        PopoverGuard.duringModal { alert.runModal() }
    }
}
