import Foundation

public enum SetupState: String, Equatable, Sendable {
    case ready
    case needsGit
    case needsRemote
}

public struct RootStatus: Identifiable, Equatable, Sendable {
    public var id: String
    public var path: String
    public var remote: String?
    public var branch: String
    public var setup: SetupState
    public var pending: Int
    public var ahead: Int
    public var behind: Int
    public var lastMessage: String?
    public var lastTimestamp: String?
    public var conflict: Bool
    public var backupBranch: String?

    public init(id: String, path: String, remote: String?, branch: String,
                setup: SetupState, pending: Int, ahead: Int, behind: Int,
                lastMessage: String?, lastTimestamp: String?, conflict: Bool,
                backupBranch: String?) {
        self.id = id
        self.path = path
        self.remote = remote
        self.branch = branch
        self.setup = setup
        self.pending = pending
        self.ahead = ahead
        self.behind = behind
        self.lastMessage = lastMessage
        self.lastTimestamp = lastTimestamp
        self.conflict = conflict
        self.backupBranch = backupBranch
    }
}

public enum Status {
    public static func read(root: Root, config: Config) -> RootStatus {
        let git = Git(repo: root.expandedPath)
        let pending = (try? git.pending().count) ?? 0
        let ab = (try? git.aheadBehind(remote: config.remote(for: root),
                                       branch: config.branch(for: root))) ?? (ahead: 0, behind: 0)
        let state = try? State.read(for: root)
        let isRepo = git.isRepo()
        let remoteURL = isRepo ? git.remoteURL(config.remote(for: root)) : nil
        let setup: SetupState = !isRepo ? .needsGit : (remoteURL == nil ? .needsRemote : .ready)
        return RootStatus(
            id: root.id,
            path: root.expandedPath.path,
            remote: remoteURL,
            branch: config.branch(for: root),
            setup: setup,
            pending: pending,
            ahead: ab.ahead,
            behind: ab.behind,
            lastMessage: state?.message,
            lastTimestamp: state?.timestamp,
            conflict: state?.conflict ?? false,
            backupBranch: state?.backupBranch
        )
    }

    public static func readAll(config: Config) -> [RootStatus] {
        config.roots.map { read(root: $0, config: config) }
    }
}
