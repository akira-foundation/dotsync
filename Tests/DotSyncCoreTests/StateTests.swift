import XCTest
@testable import DotSyncCore

final class StateTests: XCTestCase {
    func testWriteThenReadRoundTrips() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        let root = Root(id: "t", path: fx.work.path, remote: nil, branch: nil,
                        trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)

        let result = SyncResult(rootID: "t", timestamp: "2026-07-20T00:00:00Z",
                                pushed: true, conflict: false, backupBranch: nil,
                                pendingBefore: 2, message: "ok")
        try State.write(result, for: root)

        let back = try XCTUnwrap(State.read(for: root))
        XCTAssertEqual(back, result)
        XCTAssertTrue(State.path(for: root).path.hasSuffix("/.git/dotsync-state.json"))
    }
}
