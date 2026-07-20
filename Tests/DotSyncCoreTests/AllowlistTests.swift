import XCTest

@testable import DotSyncCore

final class AllowlistTests: XCTestCase {
    func testDetect() {
        XCTAssertEqual(Tool.detect(path: "/Users/x/.claude"), .claude)
        XCTAssertEqual(Tool.detect(path: "/Users/x/.codex"), .codex)
        XCTAssertEqual(Tool.detect(path: "/Users/x/other"), .generic)
    }

    func testCodexIgnoresSecretAllowsConfig() {
        let gitignore = Allowlist.gitignore(for: .codex)
        XCTAssertTrue(gitignore.contains("auth.json"))
        XCTAssertTrue(gitignore.contains("!/config.toml"))
        XCTAssertTrue(gitignore.contains("!/AGENTS.md"))
    }

    func testClaudeIgnoresCredentials() {
        let gitignore = Allowlist.gitignore(for: .claude)
        XCTAssertTrue(gitignore.contains(".credentials.json"))
        XCTAssertTrue(gitignore.contains("!/CLAUDE.md"))
        XCTAssertTrue(gitignore.contains("!/skills/"))
    }

    func testWriteCreatesFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dotsync-al-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Allowlist.write(for: .codex, to: dir)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dir.appendingPathComponent(".gitignore").path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: dir.appendingPathComponent(".gitattributes").path))
    }
}
