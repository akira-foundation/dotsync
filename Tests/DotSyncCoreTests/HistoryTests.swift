import XCTest

@testable import DotSyncCore

final class HistoryTests: XCTestCase {
    func testParsesEntries() {
        let sep = History.separator
        let output = """
            abc123\(sep)2026-07-21T09:00:00Z\(sep)dotsync: sync from macbook
            def456\(sep)2026-07-20T18:30:00Z\(sep)dotsync: onboard
            """
        let entries = History.parse(output)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].hash, "abc123")
        XCTAssertEqual(entries[0].timestamp, "2026-07-21T09:00:00Z")
        XCTAssertEqual(entries[0].subject, "dotsync: sync from macbook")
    }

    func testIgnoresMalformedLines() {
        XCTAssertTrue(History.parse("garbage without separators").isEmpty)
    }

    func testRecentReadsRepoLog() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("a.md", "one\n")
        let git = Git(repo: fx.work)
        _ = try git.run(["add", "-A"])
        _ = try git.run(["commit", "--no-verify", "-m", "first change"])

        let entries = History.recent(repo: fx.work, limit: 3)
        XCTAssertFalse(entries.isEmpty)
        XCTAssertEqual(entries.first?.subject, "first change")
    }

    func testPendingPathsStripStatusPrefix() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("changed.md", "x\n")

        let paths = Git(repo: fx.work).pendingPaths()
        XCTAssertTrue(paths.contains("changed.md"))
    }
}
