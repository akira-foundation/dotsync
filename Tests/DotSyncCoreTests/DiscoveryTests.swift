import XCTest

@testable import DotSyncCore

final class DiscoveryTests: XCTestCase {
    func testUnionsKnownAndUserPathsWithoutDuplicates() {
        let paths = Discovery.candidatePaths(["~/.claude", "~/work/dotfiles"])
        XCTAssertEqual(paths.filter { $0 == "~/.claude" }.count, 1)
        XCTAssertTrue(paths.contains("~/.codex"))
        XCTAssertTrue(paths.contains("~/work/dotfiles"))
        XCTAssertEqual(paths.first, "~/.claude")
    }
}
