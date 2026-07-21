import Foundation

public struct Git {
    public let repo: URL
    private let bin = "/usr/bin/git"

    public init(repo: URL) { self.repo = repo }

    @discardableResult
    public func run(_ args: [String]) throws -> ShellResult {
        try Shell.run(bin, args, cwd: repo)
    }

    public func currentBranch() throws -> String {
        try run(["rev-parse", "--abbrev-ref", "HEAD"])
            .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func isRepo() -> Bool {
        (try? run(["rev-parse", "--is-inside-work-tree"]))?.ok ?? false
    }

    public func remoteURL(_ name: String) -> String? {
        guard let result = try? run(["remote", "get-url", name]) else { return nil }
        let url = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    public func pending() throws -> [String] {
        try run(["status", "--porcelain"])
            .stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }

    public func pendingPaths() -> [String] {
        ((try? pending()) ?? []).compactMap { line in
            guard line.count > 3 else { return nil }
            let path = String(line.dropFirst(3))
            return path.components(separatedBy: " -> ").last
        }
    }

    public func aheadBehind(remote: String, branch: String) throws -> (ahead: Int, behind: Int) {
        let r = try run(["rev-list", "--left-right", "--count", "\(remote)/\(branch)...HEAD"])
        let nums = r.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .flatMap { $0.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }) }
            .compactMap { Int($0) }
        guard nums.count == 2 else { return (0, 0) }
        return (ahead: nums[1], behind: nums[0])
    }
}
