import XCTest
@testable import DotSyncCore

final class ConfigTests: XCTestCase {
    func testDecodesRootsAndAppliesDefaults() throws {
        let json = """
        {
          "defaults": { "branch": "main", "intervalSec": 300 },
          "roots": [
            { "id": "claude", "path": "~/.claude", "trigger": "hook", "auto": true },
            { "id": "codex", "path": "~/.codex", "trigger": "scheduler",
              "branch": "master", "remote": "upstream", "intervalSec": 600, "watch": true }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cfg-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let cfg = try Config.load(url)

        XCTAssertEqual(cfg.roots.count, 2)
        let claude = try XCTUnwrap(cfg.root(id: "claude"))
        XCTAssertEqual(cfg.branch(for: claude), "main")
        XCTAssertEqual(cfg.remote(for: claude), "origin")
        XCTAssertEqual(claude.trigger, .hook)

        let codex = try XCTUnwrap(cfg.root(id: "codex"))
        XCTAssertEqual(cfg.branch(for: codex), "master")
        XCTAssertEqual(cfg.remote(for: codex), "upstream")
        XCTAssertEqual(codex.trigger, .scheduler)
        XCTAssertTrue(codex.expandedPath.path.hasSuffix("/.codex"))
        XCTAssertFalse(codex.expandedPath.path.contains("~"))
    }

    func testSaveRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-\(UUID().uuidString)/config.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cfg = Config(
            defaults: Defaults(branch: "main", intervalSec: 300),
            roots: [Root(id: "a", path: "~/a", remote: "origin", branch: nil,
                         trigger: .scheduler, auto: true, intervalSec: nil, watch: nil)]
        )
        try cfg.save(to: url)

        XCTAssertEqual(try Config.load(url), cfg)
    }
}
