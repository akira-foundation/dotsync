import XCTest
@testable import DotSyncCore

final class GitTests: XCTestCase {
    func testPendingAndAheadBehind() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        XCTAssertEqual(try g.currentBranch(), "main")
        XCTAssertTrue(try g.pending().isEmpty)

        try fx.writeFile("a.txt", "one\n")
        XCTAssertEqual(try g.pending().count, 1)

        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "local commit"])
        let ab = try g.aheadBehind(remote: "origin", branch: "main")
        XCTAssertEqual(ab.ahead, 1)
        XCTAssertEqual(ab.behind, 0)
    }
}
