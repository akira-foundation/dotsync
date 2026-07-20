import Foundation

public struct ConflictResolver {
    private let git: Git

    public init(repo: URL) {
        self.git = Git(repo: repo)
    }

    public func backups() -> [String] {
        let out =
            (try? git.run([
                "for-each-ref", "--format=%(refname:short)", "refs/heads/sync-conflict-*",
            ]).stdout) ?? ""
        return out.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    public func changedFiles(backup: String) -> [String] {
        let out = (try? git.run(["diff", "--name-only", "HEAD..\(backup)"]).stdout) ?? ""
        return out.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    public func discard(backup: String) throws {
        _ = try git.run(["branch", "-D", backup])
    }

    public func keepMine(backup: String) throws {
        _ = try git.run(["checkout", backup, "--", "."])
        _ = try git.run(["branch", "-D", backup])
    }
}
