import XCTest

@testable import DotSyncCore

final class LogTests: XCTestCase {
    func testSummarizeIncludesExitCodeAndStderr() {
        let line = Log.summarize("push", exitCode: 1, stderr: "  fatal: no upstream\n")
        XCTAssertEqual(line, "push failed (exit 1): fatal: no upstream")
    }

    func testSummarizeWithoutStderr() {
        XCTAssertEqual(
            Log.summarize("push", exitCode: 128, stderr: "   "), "push failed (exit 128)")
    }

    func testRedactsCredentialsInRemoteURL() {
        let line = Log.summarize(
            "push", exitCode: 1,
            stderr: "remote: https://kid:ghp_secrettoken@github.com/org/repo.git denied")
        XCTAssertFalse(line.contains("ghp_secrettoken"))
        XCTAssertTrue(line.contains("//<redacted>@github.com"))
    }

    func testClipsLongStderr() {
        let long = String(repeating: "x", count: 900)
        let line = Log.summarize("push", exitCode: 1, stderr: long)
        XCTAssertTrue(line.count < 500)
        XCTAssertTrue(line.hasSuffix("\u{2026}"))
    }
}
