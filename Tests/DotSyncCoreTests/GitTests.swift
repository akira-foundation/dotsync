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

    func testUntrackRemovesFromIndexKeepsWorkingCopy() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        try fx.writeFile("secret.json", "{}\n")
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "add secret"])
        XCTAssertTrue(try g.run(["ls-files"]).stdout.contains("secret.json"))

        try g.untrack("secret.json")

        XCTAssertFalse(try g.run(["ls-files"]).stdout.contains("secret.json"))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: fx.work.appendingPathComponent("secret.json").path))
    }

    func testUntrackIgnoresMissingFile() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        XCTAssertNoThrow(try g.untrack("does-not-exist.json"))
    }

    func testUntrackHandlesPathStartingWithDash() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let g = Git(repo: fx.work)

        try fx.writeFile("-weird.json", "{}\n")
        _ = try g.run(["add", "-A"])
        _ = try g.run(["commit", "--no-verify", "-m", "add dash-prefixed file"])

        XCTAssertNoThrow(try g.untrack("-weird.json"))
        XCTAssertFalse(try g.run(["ls-files"]).stdout.contains("-weird.json"))
    }
}
