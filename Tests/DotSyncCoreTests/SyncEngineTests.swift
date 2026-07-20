import XCTest

@testable import DotSyncCore

final class SyncEngineTests: XCTestCase {
    private func makeEngine() -> SyncEngine {
        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("enginebin-\(UUID().uuidString)")
        return SyncEngine(binDir: binDir, now: { "2026-07-20T00:00:00Z" }, host: { "testpc" })
    }

    private func root(_ fx: GitFixture) -> Root {
        Root(
            id: "t", path: fx.work.path, remote: "origin", branch: "main",
            trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
    }

    private func config() -> Config {
        Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])
    }

    func testLocalChangeCommitsAndPushes() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("note.txt", "hello\n")

        let result = try makeEngine().sync(root: root(fx), config: config())

        XCTAssertTrue(result.pushed)
        XCTAssertFalse(result.conflict)
        XCTAssertEqual(result.pendingBefore, 2)

        let g = Git(repo: fx.work)
        let ab = try g.aheadBehind(remote: "origin", branch: "main")
        XCTAssertEqual(ab.ahead, 0, "local must be pushed")
        XCTAssertEqual(ab.behind, 0)
    }

    func testRemoteChangeIsPulled() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }

        // Simulate another machine pushing to the remote via a second clone.
        let clone = fx.work.deletingLastPathComponent().appendingPathComponent("clone")
        _ = try Shell.run("/usr/bin/git", ["clone", fx.remote.path, clone.path])
        let cg = Git(repo: clone)
        _ = try cg.run(["config", "user.email", "b@dotsync.local"])
        _ = try cg.run(["config", "user.name", "b"])
        try Data("remote\n".utf8).write(to: clone.appendingPathComponent("remote.txt"))
        _ = try cg.run(["add", "-A"])
        _ = try cg.run(["commit", "--no-verify", "-m", "remote change"])
        _ = try cg.run(["push", "--no-verify", "origin", "main"])

        let result = try makeEngine().sync(root: root(fx), config: config())
        XCTAssertFalse(result.conflict)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fx.work.appendingPathComponent("remote.txt").path))
    }

    func testConcurrentSyncSkipsViaLock() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let lockPath = fx.work.appendingPathComponent(".git/dotsync.lock").path
        let held = try XCTUnwrap(FileLock(path: lockPath))
        XCTAssertTrue(held.tryLock())
        defer { held.unlock() }

        try fx.writeFile("note.txt", "hello\n")
        let result = try makeEngine().sync(root: root(fx), config: config())
        XCTAssertEqual(result.message, "locked")
        XCTAssertFalse(result.pushed)
    }

    func testResidualConflictBacksUpLocalAndTakesRemote() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }

        let clone = fx.work.deletingLastPathComponent().appendingPathComponent("clone2")
        _ = try Shell.run("/usr/bin/git", ["clone", fx.remote.path, clone.path])
        let cg = Git(repo: clone)
        _ = try cg.run(["config", "user.email", "b@dotsync.local"])
        _ = try cg.run(["config", "user.name", "b"])
        try Data("remote-line\n".utf8).write(to: clone.appendingPathComponent("README.md"))
        _ = try cg.run(["add", "-A"])
        _ = try cg.run(["commit", "--no-verify", "-m", "remote README"])
        _ = try cg.run(["push", "--no-verify", "origin", "main"])

        try fx.writeFile("README.md", "local-line\n")

        let engine = SyncEngine(
            binDir: FileManager.default.temporaryDirectory
                .appendingPathComponent("cbin-\(UUID().uuidString)"),
            now: { "2026-07-20T11:22:33Z" }, host: { "testpc" })
        let root = Root(
            id: "t", path: fx.work.path, remote: "origin", branch: "main",
            trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let cfg = Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [])

        let result = try engine.sync(root: root, config: cfg)

        XCTAssertTrue(result.conflict)
        let backupName = try XCTUnwrap(result.backupBranch)
        XCTAssertEqual(backupName, "sync-conflict-testpc-2026-07-20T11-22-33Z")

        let readme = try String(
            contentsOf: fx.work.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertEqual(readme, "remote-line\n", "working tree must take remote after fallback")

        let g = Git(repo: fx.work)
        let backupContent = try g.run(["show", "\(backupName):README.md"]).stdout
        XCTAssertEqual(backupContent, "local-line\n", "backup branch must preserve local work")
    }
}
