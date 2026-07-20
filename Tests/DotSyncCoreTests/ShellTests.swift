import XCTest

@testable import DotSyncCore

final class ShellTests: XCTestCase {
    func testCapturesStdoutAndExitCode() throws {
        let r = try Shell.run("/bin/echo", ["hello"], cwd: nil, env: nil)
        XCTAssertEqual(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertTrue(r.ok)
    }

    func testNonZeroExitIsReported() throws {
        let r = try Shell.run("/bin/sh", ["-c", "exit 3"], cwd: nil, env: nil)
        XCTAssertEqual(r.exitCode, 3)
        XCTAssertFalse(r.ok)
    }

    func testConcurrentLargeStdoutAndStderrDoNotDeadlock() throws {
        let script = "for i in $(seq 1 4000); do echo out-$i; echo err-$i 1>&2; done"
        let r = try Shell.run("/bin/sh", ["-c", script], cwd: nil, env: nil)
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertTrue(r.stdout.contains("out-4000"))
        XCTAssertTrue(r.stderr.contains("err-4000"))
        XCTAssertGreaterThan(r.stdout.count, 20000)
        XCTAssertGreaterThan(r.stderr.count, 20000)
    }
}
