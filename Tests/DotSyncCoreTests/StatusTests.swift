import XCTest

@testable import DotSyncCore

final class StatusTests: XCTestCase {
    func testReadsPendingAheadAndState() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let root = Root(
            id: "t", path: fx.work.path, remote: "origin", branch: "main",
            trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let cfg = Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [root])

        try fx.writeFile("a.txt", "one\n")
        let g = Git(repo: fx.work)
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "local"])

        let result = SyncResult(
            rootID: "t", timestamp: "2026-07-20T00:00:00Z",
            pushed: true, conflict: false, backupBranch: nil,
            pendingBefore: 1, message: "pushed")
        try State.write(result, for: root)

        let status = Status.read(root: root, config: cfg)
        XCTAssertEqual(status.id, "t")
        XCTAssertEqual(status.ahead, 1)
        XCTAssertEqual(status.behind, 0)
        XCTAssertEqual(status.lastMessage, "pushed")
        XCTAssertEqual(status.lastTimestamp, "2026-07-20T00:00:00Z")
        XCTAssertFalse(status.conflict)
    }

    func testIncludesRemoteAndBranch() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let root = Root(
            id: "t", path: fx.work.path, remote: "origin", branch: nil,
            trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let cfg = Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [root])

        let status = Status.read(root: root, config: cfg)
        XCTAssertNotNil(status.remote)
        XCTAssertEqual(status.branch, "main")
    }

    func testReadAllCoversEveryRoot() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let root = Root(
            id: "solo", path: fx.work.path, remote: nil, branch: nil,
            trigger: .hook, auto: true, intervalSec: nil, watch: nil)
        let cfg = Config(defaults: Defaults(branch: "main", intervalSec: 300), roots: [root])

        let all = Status.readAll(config: cfg)
        XCTAssertEqual(all.map(\.id), ["solo"])
    }
}
