import Foundation

public struct SyncEngine {
    public var binDir: URL
    public var now: () -> String
    public var host: () -> String

    public init(binDir: URL, now: @escaping () -> String, host: @escaping () -> String) {
        self.binDir = binDir
        self.now = now
        self.host = host
    }

    public func sync(root: Root, config: Config) throws -> SyncResult {
        let ts = now()
        let git = Git(repo: root.expandedPath)
        let remote = config.remote(for: root)
        let branch = config.branch(for: root)

        let lockPath = root.expandedPath.appendingPathComponent(".git/dotsync.lock").path
        guard let lock = FileLock(path: lockPath), lock.tryLock() else {
            return SyncResult(
                rootID: root.id, timestamp: ts, pushed: false, conflict: false,
                backupBranch: nil, pendingBefore: 0, message: "locked")
        }
        defer { lock.unlock() }

        let script = try MergeDrivers.install(binDir: binDir)
        try MergeDrivers.register(in: git, scriptPath: script.path)

        let pending = try git.pending().count
        _ = try git.run(["add", "-A"])
        let staged = try git.run(["diff", "--cached", "--quiet"])
        if !staged.ok {
            _ = try git.run([
                "commit", "--no-verify", "-m",
                "chore(auto-sync): \(pending) file(s) [\(ts)] \(host())",
            ])
        }

        let localTip = try git.run(["rev-parse", "HEAD"]).stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pull = try git.run(["pull", "--rebase", "--autostash", remote, branch])
        var conflict = false
        var backup: String? = nil
        if !pull.ok {
            conflict = true
            let safeTs = ts.replacingOccurrences(of: ":", with: "-")
            let name = "sync-conflict-\(host())-\(safeTs)"
            _ = try git.run(["rebase", "--abort"])
            let branchResult = try git.run(["branch", "-f", name, localTip])
            if !branchResult.ok {
                let res = SyncResult(
                    rootID: root.id, timestamp: ts, pushed: false, conflict: true,
                    backupBranch: nil, pendingBefore: pending, message: "conflict-backup-failed")
                try State.write(res, for: root)
                return res
            }
            backup = name
            _ = try git.run(["fetch", remote, branch])
            let reset = try git.run(["reset", "--hard", "\(remote)/\(branch)"])
            if !reset.ok {
                let res = SyncResult(
                    rootID: root.id, timestamp: ts, pushed: false, conflict: true,
                    backupBranch: name, pendingBefore: pending, message: "conflict-recovery-failed")
                try State.write(res, for: root)
                return res
            }
        }

        let push = try git.run(["push", "--no-verify", remote, branch])
        let result = SyncResult(
            rootID: root.id, timestamp: ts, pushed: push.ok, conflict: conflict,
            backupBranch: backup, pendingBefore: pending,
            message: conflict ? "conflict-resolved" : (push.ok ? "pushed" : "push-failed"))
        try State.write(result, for: root)
        return result
    }
}
