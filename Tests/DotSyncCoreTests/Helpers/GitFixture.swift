import Foundation
@testable import DotSyncCore

struct GitFixture {
    let work: URL
    let remote: URL

    static func make() throws -> GitFixture {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString)")
        let work = base.appendingPathComponent("work")
        let remote = base.appendingPathComponent("remote.git")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)

        _ = try Shell.run("/usr/bin/git", ["init", "--bare", "-b", "main"], cwd: remote)

        let g = Git(repo: work)
        _ = try g.run(["init", "-b", "main"])
        _ = try g.run(["config", "user.email", "test@dotsync.local"])
        _ = try g.run(["config", "user.name", "dotsync test"])
        _ = try g.run(["remote", "add", "origin", remote.path])

        let f = GitFixture(work: work, remote: remote)
        try f.writeFile("README.md", "seed\n")
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "seed"])
        let pushResult = try g.run(["push", "--no-verify", "-u", "origin", "main"])
        guard pushResult.ok else { throw NSError(domain: "git", code: 1, userInfo: [NSLocalizedDescriptionKey: "git push failed: \(pushResult.stderr)"]) }
        return f
    }

    func writeFile(_ name: String, _ contents: String) throws {
        let url = work.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: work.deletingLastPathComponent())
    }
}
