import XCTest
@testable import DotSyncCore

final class CLITests: XCTestCase {
    func testSyncAllReturnsZeroAndWritesState() throws {
        let fx = try GitFixture.make()
        defer { fx.cleanup() }
        try fx.writeFile("x.txt", "hi\n")

        let cfgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cli-\(UUID().uuidString).json")
        let json = """
        { "defaults": { "branch": "main", "intervalSec": 300 },
          "roots": [ { "id": "t", "path": "\(fx.work.path)", "trigger": "scheduler", "auto": true } ] }
        """
        try Data(json.utf8).write(to: cfgURL)
        defer { try? FileManager.default.removeItem(at: cfgURL) }

        let binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clibin-\(UUID().uuidString)")

        let code = CLI.run(
            ["sync", "--all"], configURL: cfgURL, binDir: binDir,
            now: { "2026-07-20T00:00:00Z" }, host: { "testpc" })
        XCTAssertEqual(code, 0)

        let root = Root(id: "t", path: fx.work.path, remote: nil, branch: nil,
                        trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)
        let state = try XCTUnwrap(State.read(for: root))
        XCTAssertTrue(state.pushed)
    }

    func testUnknownCommandReturnsNonZero() {
        let code = CLI.run(
            ["frobnicate"], configURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("nope.json"),
            binDir: FileManager.default.temporaryDirectory,
            now: { "" }, host: { "" })
        XCTAssertNotEqual(code, 0)
    }
}
