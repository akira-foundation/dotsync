import Foundation

public enum OnboardStep: Equatable, Sendable {
    case initGit
    case createRemote(owner: String, name: String)
    case commitAndPush
}

public enum OnboardOutcome: Equatable, Sendable {
    case done
    case cancelled
    case blocked(SecretScanReport)
    case needsAccount
    case failed(String)
}

public struct Onboarder: Sendable {
    public let settings: Settings
    private let gh: GhBridge
    private let confirm: @Sendable (OnboardStep) -> Bool
    private let remoteURLBuilder: @Sendable (_ host: String, _ owner: String, _ name: String) -> String

    public init(
        settings: Settings,
        gh: GhBridge,
        confirm: @escaping @Sendable (OnboardStep) -> Bool,
        remoteURLBuilder: @escaping @Sendable (String, String, String) -> String = { host, owner, name in
            "git@\(host):\(owner)/\(name).git"
        }
    ) {
        self.settings = settings
        self.gh = gh
        self.confirm = confirm
        self.remoteURLBuilder = remoteURLBuilder
    }

    public static func plan(isRepo: Bool, hasRemote: Bool) -> [OnboardStep] {
        var steps: [OnboardStep] = []
        if !isRepo { steps.append(.initGit) }
        if !hasRemote { steps.append(.createRemote(owner: "", name: "")) }
        steps.append(.commitAndPush)
        return steps
    }

    public func run(root: Root, branch: String) -> OnboardOutcome {
        let repo = root.expandedPath
        let git = Git(repo: repo)
        let tool = Tool.detect(path: root.path)

        if !git.isRepo() {
            guard confirm(.initGit) else { return .cancelled }
            guard (try? git.run(["init", "-b", branch]))?.ok == true else {
                return .failed("git init failed")
            }
        }

        do {
            try Allowlist.write(for: tool, to: repo)
        } catch {
            return .failed("could not write allowlist")
        }
        _ = try? git.run(["add", "-A"])

        if settings.guards.secretScan {
            let report = SecretScanner.scanRepo(repo)
            if settings.guards.blockOnTrackedSecrets, !report.isClean {
                return .blocked(report)
            }
        }

        if git.remoteURL("origin") == nil {
            guard let owner = settings.github.account, !owner.isEmpty else { return .needsAccount }
            let name = settings.repoName(for: root.id)
            let exists: Bool
            do {
                exists = try gh.repoExists(owner: owner, name: name)
            } catch {
                return .failed("gh: \(error)")
            }
            if !exists {
                guard confirm(.createRemote(owner: owner, name: name)) else { return .cancelled }
                do {
                    try gh.createRepo(owner: owner, name: name, isPrivate: true)
                } catch {
                    return .failed("gh repo create: \(error)")
                }
            }
            let url = remoteURLBuilder(settings.github.host, owner, name)
            guard (try? git.run(["remote", "add", "origin", url]))?.ok == true else {
                return .failed("git remote add failed")
            }
        }

        guard confirm(.commitAndPush) else { return .cancelled }

        if (try? git.run(["diff", "--cached", "--quiet"]))?.ok == false {
            _ = try? git.run(["commit", "--no-verify", "-m", "dotsync: onboard"])
        }
        guard (try? git.run(["push", "--no-verify", "-u", "origin", branch]))?.ok == true else {
            return .failed("git push failed")
        }
        return .done
    }
}
